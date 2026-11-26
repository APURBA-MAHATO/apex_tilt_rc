import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../models/car_spec.dart';
import '../services/storage_service.dart';
import '../services/tilt_control_service.dart';
import 'game_hud_state.dart';
import 'tracks/endless_highway_world.dart';
import 'tracks/neon_circuit_world.dart';

/// Main Flame 2D game orchestrating Neon Circuit and Endless Highway worlds.
class ArcadeRaceGame extends FlameGame {
  final TrackType trackType;
  final CarSpec carSpec;
  final GameHudController hud;

  NeonCircuitWorld? _circuitWorld;
  EndlessHighwayWorld? _highwayWorld;
  bool _touchGasPressed = false;
  bool _touchBrakePressed = false;

  bool get isGasInputActive =>
      !paused &&
      (_touchGasPressed || TiltControlService.instance.isGasKeyPressed);

  bool get isBrakeInputActive =>
      !paused &&
      (_touchBrakePressed || TiltControlService.instance.isBrakeKeyPressed);

  void setGasPressed(bool pressed) {
    _touchGasPressed = pressed;
  }

  void setBrakePressed(bool pressed) {
    _touchBrakePressed = pressed;
  }

  void clearPedalInputs() {
    _touchGasPressed = false;
    _touchBrakePressed = false;
  }

  ArcadeRaceGame({
    required this.trackType,
    required this.carSpec,
  })  : hud = GameHudController(
          trackType,
          bestLapMs: StorageService.instance.bestLapMs,
          bestScore: StorageService.instance.highwayBestScore,
        ),
        super(
          camera: CameraComponent.withFixedResolution(
            width: 960,
            height: 540,
          ),
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    if (trackType == TrackType.neonCircuit) {
      camera.viewfinder.anchor = Anchor.center;
      final circuit = NeonCircuitWorld(
        carSpec: carSpec,
        hud: hud,
        isGasPressed: () => isGasInputActive,
        isBrakePressed: () => isBrakeInputActive,
        onPlayerReady: (player) {
          camera.follow(player, maxSpeed: 1200);
        },
      );
      _circuitWorld = circuit;
      world = circuit;
    } else {
      // Place car lower in viewport so oncoming traffic is visible far ahead
      camera.viewfinder.anchor = const Anchor(0.5, 0.72);
      final highway = EndlessHighwayWorld(
        carSpec: carSpec,
        hud: hud,
        isGasPressed: () => isGasInputActive,
        isBrakePressed: () => isBrakeInputActive,
        onPlayerReady: (player) {
          camera.follow(player, maxSpeed: 1600);
        },
      );
      _highwayWorld = highway;
      world = highway;
    }
  }

  void pauseRace() {
    if (paused) return;
    paused = true;
    clearPedalInputs();
    hud.update(hud.value.copyWith(
      isPaused: true,
      gasActive: false,
      brakeActive: false,
    ));
  }

  void resumeRace() {
    if (!paused) return;
    paused = false;
    hud.update(hud.value.copyWith(isPaused: false));
  }

  void restartRace() {
    paused = false;
    clearPedalInputs();
    _circuitWorld?.resetRace();
    _highwayWorld?.resetRun();
    hud.update(
      hud.value.copyWith(
        isPaused: false,
        isFinished: false,
        isGameOver: false,
        isNewRecord: false,
        gasActive: false,
        brakeActive: false,
      ),
    );
  }

  @override
  void onRemove() {
    clearPedalInputs();
    hud.dispose();
    super.onRemove();
  }
}
