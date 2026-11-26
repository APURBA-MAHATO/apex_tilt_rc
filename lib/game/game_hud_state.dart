import 'package:flutter/foundation.dart';

import '../models/car_spec.dart';

class GameTelemetry {
  final TrackType trackType;
  final double speedKmh;
  final int currentLap;
  final int totalLaps;
  final int currentLapTimeMs;
  final int? bestLapTimeMs;
  final int totalRaceTimeMs;
  final int distanceMeters;
  final int score;
  final int bestScore;
  final int shields;
  final int maxShields;
  final bool boostActive;
  final double steeringInput;
  final double throttleInput;
  final bool gasActive;
  final bool brakeActive;
  final bool isPaused;
  final bool isFinished;
  final bool isGameOver;
  final bool isNewRecord;
  final String? bannerMessage;

  const GameTelemetry({
    required this.trackType,
    this.speedKmh = 0,
    this.currentLap = 1,
    this.totalLaps = 3,
    this.currentLapTimeMs = 0,
    this.bestLapTimeMs,
    this.totalRaceTimeMs = 0,
    this.distanceMeters = 0,
    this.score = 0,
    this.bestScore = 0,
    this.shields = 3,
    this.maxShields = 3,
    this.boostActive = false,
    this.steeringInput = 0,
    this.throttleInput = 0,
    this.gasActive = false,
    this.brakeActive = false,
    this.isPaused = false,
    this.isFinished = false,
    this.isGameOver = false,
    this.isNewRecord = false,
    this.bannerMessage,
  });

  GameTelemetry copyWith({
    double? speedKmh,
    int? currentLap,
    int? currentLapTimeMs,
    int? bestLapTimeMs,
    bool clearBestLap = false,
    int? totalRaceTimeMs,
    int? distanceMeters,
    int? score,
    int? bestScore,
    int? shields,
    bool? boostActive,
    double? steeringInput,
    double? throttleInput,
    bool? gasActive,
    bool? brakeActive,
    bool? isPaused,
    bool? isFinished,
    bool? isGameOver,
    bool? isNewRecord,
    String? bannerMessage,
    bool clearBanner = false,
  }) {
    return GameTelemetry(
      trackType: trackType,
      speedKmh: speedKmh ?? this.speedKmh,
      currentLap: currentLap ?? this.currentLap,
      totalLaps: totalLaps,
      currentLapTimeMs: currentLapTimeMs ?? this.currentLapTimeMs,
      bestLapTimeMs: clearBestLap ? null : (bestLapTimeMs ?? this.bestLapTimeMs),
      totalRaceTimeMs: totalRaceTimeMs ?? this.totalRaceTimeMs,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      score: score ?? this.score,
      bestScore: bestScore ?? this.bestScore,
      shields: shields ?? this.shields,
      maxShields: maxShields,
      boostActive: boostActive ?? this.boostActive,
      steeringInput: steeringInput ?? this.steeringInput,
      throttleInput: throttleInput ?? this.throttleInput,
      gasActive: gasActive ?? this.gasActive,
      brakeActive: brakeActive ?? this.brakeActive,
      isPaused: isPaused ?? this.isPaused,
      isFinished: isFinished ?? this.isFinished,
      isGameOver: isGameOver ?? this.isGameOver,
      isNewRecord: isNewRecord ?? this.isNewRecord,
      bannerMessage: clearBanner ? null : (bannerMessage ?? this.bannerMessage),
    );
  }
}

class GameHudController extends ValueNotifier<GameTelemetry> {
  GameHudController(TrackType trackType, {int? bestLapMs, int bestScore = 0})
      : super(
          GameTelemetry(
            trackType: trackType,
            bestLapTimeMs: bestLapMs,
            bestScore: bestScore,
          ),
        );

  void update(GameTelemetry next) {
    value = next;
  }
}
