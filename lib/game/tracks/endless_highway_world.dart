import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../models/car_spec.dart';
import '../../services/storage_service.dart';
import '../../services/tilt_control_service.dart';
import '../game_hud_state.dart';
import '../components/player_car.dart';

/// 3-lane endless dodge highway with procedural traffic, nitro boost pads,
/// 3-hit shield integrity, and distance/score persistence.
class EndlessHighwayWorld extends World with HasCollisionDetection {
  static const double roadWidth = 330.0;
  static const double laneWidth = roadWidth / 3.0;
  static const List<double> laneCentersX = [-laneWidth, 0.0, laneWidth];

  final CarSpec carSpec;
  final GameHudController hud;
  final bool Function()? isGasPressed;
  final bool Function()? isBrakePressed;
  final void Function(PlayerCar player)? onPlayerReady;
  final math.Random _rng = math.Random();

  late final PlayerCar player;
  final List<_TrafficCar> _traffic = <_TrafficCar>[];
  final List<_BoostPad> _boostPads = <_BoostPad>[];

  double _nextSpawnY = -420.0;
  double _startY = 0.0;
  int _shields = 3;
  int _bonusScore = 0;
  int _bestScore = 0;
  bool _gameOver = false;
  bool _newRecord = false;
  String? _banner;
  double _bannerTimer = 0.0;

  bool _lastGasActive = false;
  bool _lastBrakeActive = false;

  EndlessHighwayWorld({
    required this.carSpec,
    required this.hud,
    this.isGasPressed,
    this.isBrakePressed,
    this.onPlayerReady,
  }) {
    _bestScore = StorageService.instance.highwayBestScore;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    player = PlayerCar(
      spec: carSpec,
      position: Vector2(0, 0),
      onCarCollision: _handleCollision,
    );
    await add(player);
    onPlayerReady?.call(player);

    _spawnInitialWave();
    _syncHud();
  }

  void resetRun() {
    for (final t in _traffic) {
      t.removeFromParent();
    }
    for (final b in _boostPads) {
      b.removeFromParent();
    }
    _traffic.clear();
    _boostPads.clear();

    player.resetPhysics(position: Vector2.zero(), angle: 0.0);
    _startY = 0.0;
    _nextSpawnY = -420.0;
    _shields = 3;
    _bonusScore = 0;
    _gameOver = false;
    _newRecord = false;
    _banner = 'DODGE & BOOST!';
    _bannerTimer = 1.4;

    _spawnInitialWave();
    _syncHud();
  }

  void _spawnInitialWave() {
    for (var i = 0; i < 6; i++) {
      _spawnRow(_nextSpawnY);
      _nextSpawnY -= 310.0;
    }
  }

  void _spawnRow(double yPos) {
    final distanceFactor =
        ((_startY - player.position.y) / 1000.0).clamp(0.0, 1.0);
    final blockedCount = _rng.nextDouble() < (0.35 + distanceFactor * 0.4) ? 2 : 1;
    final lanes = [0, 1, 2]..shuffle(_rng);

    for (var i = 0; i < blockedCount; i++) {
      final lane = lanes[i];
      final isOncoming = lane == 0 && _rng.nextBool();
      final speed = isOncoming
          ? (130.0 + _rng.nextDouble() * 90.0)
          : -(95.0 + _rng.nextDouble() * 85.0);

      final trafficCar = _TrafficCar(
        position: Vector2(laneCentersX[lane], yPos - _rng.nextDouble() * 60),
        verticalVelocity: speed,
        isOncoming: isOncoming,
      );
      _traffic.add(trafficCar);
      add(trafficCar);
    }

    // Spawn a boost pad in the guaranteed open lane occasionally
    if (_rng.nextDouble() < 0.28) {
      final openLane = lanes.last;
      final pad = _BoostPad(
        position: Vector2(laneCentersX[openLane], yPos + 30),
      );
      _boostPads.add(pad);
      add(pad);
    }
  }

  void _handleCollision(PositionComponent other) {
    if (_gameOver) return;

    if (other is _BoostPad) {
      player.activateBoost(2.2);
      _bonusScore += 150;
      _banner = 'NITRO BOOST +150';
      _bannerTimer = 1.2;
      other.removeFromParent();
      _boostPads.remove(other);
      return;
    }

    if (other is _TrafficCar && !player.isInvulnerable) {
      _shields--;
      player.velocity.y *= 0.45;
      player.triggerInvulnerability(1.4);

      if (_shields <= 0) {
        _shields = 0;
        _gameOver = true;
        final finalScore = _computeScore();
        final dist = _computeDistanceMeters();
        StorageService.instance.recordHighwayBestDistance(dist);
        StorageService.instance
            .recordHighwayBestScore(finalScore)
            .then((isBest) {
          if (isBest) {
            _bestScore = finalScore;
            _newRecord = true;
            _syncHud();
          }
        });
        _banner = 'CRASHED!';
        _bannerTimer = 3.0;
      } else {
        _banner = 'SHIELD HIT! $_shields LEFT';
        _bannerTimer = 1.3;
      }
      _syncHud();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    if (_bannerTimer > 0) {
      _bannerTimer = math.max(0.0, _bannerTimer - dt);
      if (_bannerTimer == 0) _banner = null;
    }

    final tilt = TiltControlService.instance;
    _lastGasActive = isGasPressed?.call() ?? tilt.isGasKeyPressed;
    _lastBrakeActive = isBrakePressed?.call() ?? tilt.isBrakeKeyPressed;
    player.setArcadeControls(
      steering: tilt.arcadeSteering,
      gasPressed: _lastGasActive,
      brakePressed: _lastBrakeActive,
    );
    player.updateHighwayPhysics(
      dt,
      minX: -roadWidth / 2 + 22,
      maxX: roadWidth / 2 - 22,
    );

    // Spawn ahead of player & cull passed obstacles
    while (_nextSpawnY > player.position.y - 1150) {
      final spacing =
          (290.0 - ((_startY - player.position.y) / 140.0)).clamp(195.0, 290.0);
      _spawnRow(_nextSpawnY);
      _nextSpawnY -= spacing;
    }

    final cullY = player.position.y + 420;
    _traffic.removeWhere((t) {
      if (t.position.y > cullY) {
        t.removeFromParent();
        return true;
      }
      return false;
    });
    _boostPads.removeWhere((b) {
      if (b.position.y > cullY) {
        b.removeFromParent();
        return true;
      }
      return false;
    });

    _syncHud();
  }

  int _computeDistanceMeters() =>
      ((_startY - player.position.y) / 16.0).round().clamp(0, 9999999);

  int _computeScore() => _computeDistanceMeters() * 2 + _bonusScore;

  void _syncHud() {
    final score = _computeScore();
    if (score > _bestScore) {
      _bestScore = score;
    }
    hud.update(
      GameTelemetry(
        trackType: TrackType.endlessHighway,
        speedKmh: player.velocity.length * 0.48,
        distanceMeters: _computeDistanceMeters(),
        score: score,
        bestScore: _bestScore,
        shields: _shields,
        boostActive: player.isBoosting,
        steeringInput: player.steeringOutput,
        throttleInput: player.throttleOutput,
        gasActive: _lastGasActive,
        brakeActive: _lastBrakeActive,
        isGameOver: _gameOver,
        isNewRecord: _newRecord,
        bannerMessage: _banner,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final camY = player.position.y;
    final topY = camY - 900;
    final bottomY = camY + 600;

    // Dark outer void
    canvas.drawRect(
      Rect.fromLTRB(-1000, topY, 1000, bottomY),
      Paint()..color = const Color(0xFF070B12),
    );

    // Highway asphalt slab
    canvas.drawRect(
      Rect.fromLTRB(-roadWidth / 2, topY, roadWidth / 2, bottomY),
      Paint()..color = const Color(0xFF1A2233),
    );

    // Neon road edge guardrails
    final railPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(-roadWidth / 2, topY),
      Offset(-roadWidth / 2, bottomY),
      railPaint,
    );
    canvas.drawLine(
      Offset(roadWidth / 2, topY),
      Offset(roadWidth / 2, bottomY),
      railPaint,
    );

    // Dashed lane dividers
    final dashPaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 3;
    final firstDash = (topY / 80).floor() * 80.0;
    for (var y = firstDash; y < bottomY; y += 80) {
      canvas.drawLine(
        Offset(-roadWidth / 6, y),
        Offset(-roadWidth / 6, y + 36),
        dashPaint,
      );
      canvas.drawLine(
        Offset(roadWidth / 6, y),
        Offset(roadWidth / 6, y + 36),
        dashPaint,
      );
    }

    super.render(canvas);
  }
}

class _TrafficCar extends PositionComponent with CollisionCallbacks {
  final double verticalVelocity;
  final bool isOncoming;
  late final Color _bodyColor;

  _TrafficCar({
    required Vector2 position,
    required this.verticalVelocity,
    required this.isOncoming,
  }) : super(
          position: position,
          size: Vector2(28, 52),
          anchor: Anchor.center,
          priority: 15,
        ) {
    _bodyColor = isOncoming
        ? const Color(0xFFFF3D71)
        : const Color(0xFFFFB300);
    if (isOncoming) {
      angle = math.pi;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(size: Vector2(22, 44), position: Vector2(3, 4)));
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += verticalVelocity * dt;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, w - 4, h - 4),
        const Radius.circular(7),
      ),
      Paint()..color = _bodyColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, 13, w - 12, 12),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF0F172A),
    );
    // Headlights
    canvas.drawCircle(
      const Offset(7, 4),
      2.2,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawCircle(
      Offset(w - 7, 4),
      2.2,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }
}

class _BoostPad extends PositionComponent with CollisionCallbacks {
  double _pulse = 0.0;

  _BoostPad({required Vector2 position})
      : super(
          position: position,
          size: Vector2(46, 36),
          anchor: Anchor.center,
          priority: 10,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 6;
  }

  @override
  void render(Canvas canvas) {
    final alpha = 0.55 + 0.35 * math.sin(_pulse);
    final paint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    for (final yOff in [12.0, 24.0]) {
      final chevron = Path()
        ..moveTo(8, yOff + 8)
        ..lineTo(size.x / 2, yOff - 2)
        ..lineTo(size.x - 8, yOff + 8);
      canvas.drawPath(chevron, paint);
    }
  }
}
