import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apex_tilt_rc/game/components/player_car.dart';
import 'package:apex_tilt_rc/main.dart';
import 'package:apex_tilt_rc/models/car_spec.dart';
import 'package:apex_tilt_rc/services/rc_connection_service.dart';
import 'package:apex_tilt_rc/services/storage_service.dart';
import 'package:apex_tilt_rc/services/tilt_control_service.dart';

void main() {
  group('TiltControlService.processAxis', () {
    test('zeroes out inputs within deadzone', () {
      expect(
        TiltControlService.processAxis(
          rawValue: 0.05,
          deadzone: 0.10,
          sensitivity: 1.5,
          invert: false,
        ),
        0.0,
      );
      expect(
        TiltControlService.processAxis(
          rawValue: -0.09,
          deadzone: 0.10,
          sensitivity: 2.0,
          invert: true,
        ),
        0.0,
      );
    });

    test('remaps outside deadzone, applies sensitivity, and clamps to [-1, 1]',
        () {
      final mid = TiltControlService.processAxis(
        rawValue: 0.55,
        deadzone: 0.10,
        sensitivity: 1.0,
        invert: false,
      );
      expect(mid, closeTo(0.5, 1e-6));

      final boosted = TiltControlService.processAxis(
        rawValue: 0.80,
        deadzone: 0.10,
        sensitivity: 2.0,
        invert: false,
      );
      expect(boosted, 1.0);

      final inverted = TiltControlService.processAxis(
        rawValue: 0.55,
        deadzone: 0.10,
        sensitivity: 1.0,
        invert: true,
      );
      expect(inverted, closeTo(-0.5, 1e-6));
    });
  });

  group('TiltControlService.processRollRadians & PlayerCar pedals', () {
    test('enforces ±0.08 rad deadzone and scales by sensitivity', () {
      expect(
        TiltControlService.processRollRadians(
          deltaRollRad: 0.075,
          sensitivity: 1.5,
          invert: false,
        ),
        0.0,
      );
      expect(
        TiltControlService.processRollRadians(
          deltaRollRad: -0.08,
          sensitivity: 2.0,
          invert: false,
        ),
        0.0,
      );
      expect(
        TiltControlService.processRollRadians(
          deltaRollRad: 0.32,
          sensitivity: 1.0,
          invert: false,
        ),
        closeTo(0.5, 1e-6),
      );
      expect(
        TiltControlService.processRollRadians(
          deltaRollRad: 0.32,
          sensitivity: 2.0,
          invert: false,
        ),
        1.0,
      );
    });

    test('ramps acceleration on GAS, brakes/reverses on BRAKE, and coasts', () {
      final car = PlayerCar(spec: CarSpec.roster.first);

      // Hold GAS: smooth ramp-up
      car.setArcadeControls(steering: 0.0, gasPressed: true, brakePressed: false);
      car.updateCircuitPhysics(0.1);
      final afterShortGas = car.forwardSpeed;
      expect(afterShortGas, greaterThan(0.0));
      car.updateCircuitPhysics(0.3);
      expect(car.forwardSpeed, greaterThan(afterShortGas));

      // Release both pedals: natural coasting drag
      final speedBeforeCoast = car.forwardSpeed;
      car.setArcadeControls(steering: 0.0, gasPressed: false, brakePressed: false);
      car.updateCircuitPhysics(0.3);
      expect(car.forwardSpeed, lessThan(speedBeforeCoast));
      expect(car.forwardSpeed, greaterThan(0.0));

      // Hold BRAKE: brakes down and reverses
      car.setArcadeControls(steering: 0.0, gasPressed: false, brakePressed: true);
      for (var i = 0; i < 20; i++) {
        car.updateCircuitPhysics(0.1);
      }
      expect(car.forwardSpeed, lessThan(0.0));
    });
  });

  group('RcConnectionService packet formatting', () {
    test('formats compact S/T packet with clamping', () {
      expect(
        RcConnectionService.formatPacket(
          steeringInt: -45,
          throttleInt: 80,
          jsonFormat: false,
        ),
        'S:-45,T:80\n',
      );
      expect(
        RcConnectionService.formatPacket(
          steeringInt: 150,
          throttleInt: -140,
          jsonFormat: false,
        ),
        'S:100,T:-100\n',
      );
    });

    test('formats JSON packet cleanly', () {
      expect(
        RcConnectionService.formatPacket(
          steeringInt: 25,
          throttleInt: -60,
          jsonFormat: true,
        ),
        '{"s":25,"t":-60}',
      );
    });

    test('converts normalized floats to -100..100 integers', () {
      expect(RcConnectionService.toControlInt(0.0), 0);
      expect(RcConnectionService.toControlInt(1.0), 100);
      expect(RcConnectionService.toControlInt(-0.754), -75);
    });
  });

  group('Storage & CarSpec helpers', () {
    test('formats lap durations accurately', () {
      expect(StorageService.formatDurationMs(null), '--:--.--');
      expect(StorageService.formatDurationMs(65430), '01:05.43');
    });

    test('provides 3 distinct vehicles', () {
      expect(CarSpec.roster.length, 3);
      expect(CarSpec.byId('speed').name, 'VIPER GT');
    });
  });

  testWidgets('Home screen renders landscape mode cards and settings bar',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
    await TiltControlService.instance.init();
    addTearDown(TiltControlService.instance.stop);

    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ApexTiltApp());
    await tester.pump();

    expect(find.text('RC CAR CONTROLLER'), findsOneWidget);
    expect(find.text('ARCADE RACE MODE'), findsOneWidget);
    expect(find.text('CALIBRATE ZERO'), findsOneWidget);
    expect(find.text('SENSITIVITY'), findsOneWidget);
    expect(find.text('DEADZONE'), findsOneWidget);
  });
}
