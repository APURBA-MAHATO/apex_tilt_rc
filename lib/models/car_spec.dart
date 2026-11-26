import 'package:material_ui/material_ui.dart';

enum TrackType {
  neonCircuit,
  endlessHighway,
}

extension TrackTypeMeta on TrackType {
  String get title {
    switch (this) {
      case TrackType.neonCircuit:
        return 'Neon Circuit';
      case TrackType.endlessHighway:
        return 'Endless Highway';
    }
  }

  String get subtitle {
    switch (this) {
      case TrackType.neonCircuit:
        return '3-Lap Closed Time Trial • Drift & Apex';
      case TrackType.endlessHighway:
        return '3-Lane Endless Dodge • Traffic & Boosts';
    }
  }

  IconData get icon {
    switch (this) {
      case TrackType.neonCircuit:
        return Icons.loop_rounded;
      case TrackType.endlessHighway:
        return Icons.add_road_rounded;
    }
  }
}

class CarSpec {
  final String id;
  final String name;
  final String role;
  final Color primaryColor;
  final Color accentColor;
  final double maxSpeed; // px/sec in game world
  final double acceleration; // px/sec^2
  final double turnRate; // rad/sec
  final double driftGrip; // higher = less lateral slide
  final double speedStat; // 0..1 for UI bars
  final double accelStat; // 0..1 for UI bars
  final double handlingStat; // 0..1 for UI bars

  const CarSpec({
    required this.id,
    required this.name,
    required this.role,
    required this.primaryColor,
    required this.accentColor,
    required this.maxSpeed,
    required this.acceleration,
    required this.turnRate,
    required this.driftGrip,
    required this.speedStat,
    required this.accelStat,
    required this.handlingStat,
  });

  static const List<CarSpec> roster = [
    CarSpec(
      id: 'balanced',
      name: 'APEX MK-IV',
      role: 'Balanced',
      primaryColor: Color(0xFF00E5FF),
      accentColor: Color(0xFF70FFFF),
      maxSpeed: 460,
      acceleration: 340,
      turnRate: 3.1,
      driftGrip: 5.5,
      speedStat: 0.78,
      accelStat: 0.80,
      handlingStat: 0.80,
    ),
    CarSpec(
      id: 'speed',
      name: 'VIPER GT',
      role: 'High Speed',
      primaryColor: Color(0xFFFF3D71),
      accentColor: Color(0xFFFF9E80),
      maxSpeed: 540,
      acceleration: 310,
      turnRate: 2.6,
      driftGrip: 4.3,
      speedStat: 0.98,
      accelStat: 0.72,
      handlingStat: 0.65,
    ),
    CarSpec(
      id: 'handling',
      name: 'DRIFT HORNET',
      role: 'High Handling',
      primaryColor: Color(0xFF00E676),
      accentColor: Color(0xFFB9F6CA),
      maxSpeed: 430,
      acceleration: 400,
      turnRate: 3.7,
      driftGrip: 7.2,
      speedStat: 0.70,
      accelStat: 0.94,
      handlingStat: 0.98,
    ),
  ];

  static CarSpec byId(String id) {
    return roster.firstWhere(
      (car) => car.id == id,
      orElse: () => roster.first,
    );
  }
}
