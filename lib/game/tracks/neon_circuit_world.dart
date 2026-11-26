import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/car_spec.dart';
import '../../services/storage_service.dart';
import '../../services/tilt_control_service.dart';
import '../game_hud_state.dart';
import '../components/player_car.dart';

/// Closed-loop procedural neon circuit with 3-lap time trial, checkpoint
/// validation, surface grip detection, skidmarks, and soft barrier rebound.
class NeonCircuitWorld extends World {
  static const int totalLaps = 3;
  static const double trackHalfWidth = 108.0;
  static const double wallHalfWidth = 165.0;

  final CarSpec carSpec;
  final GameHudController hud;
  final bool Function()? isGasPressed;
  final bool Function()? isBrakePressed;
  final void Function(PlayerCar player)? onPlayerReady;

  late final PlayerCar player;
  late final List<Vector2> _centerline;
  late final List<Vector2> _tangents;
  late final Path _outerRibbonPath;
  late final Path _centerDashedPath;

  final ListQueue<_SkidSample> _skidMarks = ListQueue<_SkidSample>();

  int _currentLap = 1;
  int _nextSector = 1; // 1 -> 2 -> 3 -> 0 (finish)
  int _lapElapsedMs = 0;
  int _totalElapsedMs = 0;
  int? _bestLapMs;
  bool _finished = false;
  bool _newRecord = false;
  String? _banner;
  double _bannerTimer = 0.0;

  bool _lastGasActive = false;
  bool _lastBrakeActive = false;

  NeonCircuitWorld({
    required this.carSpec,
    required this.hud,
    this.isGasPressed,
    this.isBrakePressed,
    this.onPlayerReady,
  }) {
    _bestLapMs = StorageService.instance.bestLapMs;
    _buildTrackGeometry();
  }

  void _buildTrackGeometry() {
    // Control points forming a flowing technical arcade circuit (clockwise)
    final controlPoints = <Vector2>[
      Vector2(0, 320),     // Start/Finish straight
      Vector2(0, -120),    // Turn 1 entry
      Vector2(180, -480),  // Turn 1 apex
      Vector2(620, -520),  // Top straight
      Vector2(1040, -340), // Sweeping right
      Vector2(1140, 20),   // Chicane entry
      Vector2(860, 180),   // Chicane apex
      Vector2(1080, 460),  // Hairpin entry
      Vector2(840, 740),   // Hairpin exit
      Vector2(340, 700),   // South straight
      Vector2(60, 620),    // Final corner
    ];

    // Sample Catmull-Rom closed spline into 220 crisp segments
    const samplesPerSpan = 20;
    final pts = <Vector2>[];
    final n = controlPoints.length;
    for (var i = 0; i < n; i++) {
      final p0 = controlPoints[(i - 1 + n) % n];
      final p1 = controlPoints[i];
      final p2 = controlPoints[(i + 1) % n];
      final p3 = controlPoints[(i + 2) % n];

      for (var s = 0; s < samplesPerSpan; s++) {
        final t = s / samplesPerSpan;
        pts.add(_catmullRom(p0, p1, p2, p3, t));
      }
    }

    _centerline = pts;
    _tangents = List<Vector2>.generate(pts.length, (i) {
      final next = pts[(i + 1) % pts.length];
      final prev = pts[(i - 1 + pts.length) % pts.length];
      return (next - prev).normalized();
    });

    _outerRibbonPath = Path()..moveTo(pts.first.x, pts.first.y);
    for (var i = 1; i < pts.length; i++) {
      _outerRibbonPath.lineTo(pts[i].x, pts[i].y);
    }
    _outerRibbonPath.close();

    _centerDashedPath = Path();
    for (var i = 0; i < pts.length; i += 2) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      _centerDashedPath.moveTo(a.x, a.y);
      _centerDashedPath.lineTo(b.x, b.y);
    }
  }

  static Vector2 _catmullRom(
    Vector2 p0,
    Vector2 p1,
    Vector2 p2,
    Vector2 p3,
    double t,
  ) {
    final t2 = t * t;
    final t3 = t2 * t;
    return Vector2(
      0.5 *
          ((2 * p1.x) +
              (-p0.x + p2.x) * t +
              (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
              (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3),
      0.5 *
          ((2 * p1.y) +
              (-p0.y + p2.y) * t +
              (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
              (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final startPos = _centerline[0].clone();
    final startTangent = _tangents[0];
    final startAngle = math.atan2(startTangent.x, -startTangent.y);

    player = PlayerCar(
      spec: carSpec,
      position: startPos,
    )..angle = startAngle;

    await add(player);
    onPlayerReady?.call(player);
    _syncHud();
  }

  void resetRace() {
    final startPos = _centerline[0].clone();
    final startTangent = _tangents[0];
    final startAngle = math.atan2(startTangent.x, -startTangent.y);
    player.resetPhysics(position: startPos, angle: startAngle);

    _skidMarks.clear();
    _currentLap = 1;
    _nextSector = 1;
    _lapElapsedMs = 0;
    _totalElapsedMs = 0;
    _finished = false;
    _newRecord = false;
    _banner = 'GO!';
    _bannerTimer = 1.2;
    _syncHud();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished) return;

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

    // Evaluate surface grip & barrier constraint before/after step
    final nearest = _findNearestPoint(player.position);
    player.surfaceGrip = nearest.distance > trackHalfWidth ? 0.62 : 1.0;

    player.updateCircuitPhysics(dt);

    // Enforce outer track wall rebound
    final after = _findNearestPoint(player.position);
    if (after.distance > wallHalfWidth) {
      final inward = (_centerline[after.index] - player.position).normalized();
      player.position = _centerline[after.index] - inward * wallHalfWidth;
      final outwardSpeed = player.velocity.dot(-inward);
      if (outwardSpeed > 0) {
        player.velocity += inward * (outwardSpeed * 1.35);
        player.velocity *= 0.72;
      }
    }

    // Record drift skidmarks
    if (player.currentDriftSpeed > 95) {
      _skidMarks.addLast(
        _SkidSample(
          pos: player.position.clone(),
          angle: player.angle,
          alpha: (player.currentDriftSpeed / 220).clamp(0.15, 0.55),
        ),
      );
      while (_skidMarks.length > 160) {
        _skidMarks.removeFirst();
      }
    }

    // Update lap & race timers
    final deltaMs = (dt * 1000).round();
    _lapElapsedMs += deltaMs;
    _totalElapsedMs += deltaMs;

    _evaluateCheckpoints(after.index);
    _syncHud();
  }

  void _evaluateCheckpoints(int segIndex) {
    final len = _centerline.length;
    final sector = (segIndex * 4) ~/ len; // 0, 1, 2, 3

    if (_nextSector == 1 && sector == 1) {
      _nextSector = 2;
    } else if (_nextSector == 2 && sector == 2) {
      _nextSector = 3;
    } else if (_nextSector == 3 && sector == 3) {
      _nextSector = 0;
    } else if (_nextSector == 0 && sector == 0 && segIndex < 15) {
      // Valid forward lap completion!
      _completeLap();
    }
  }

  void _completeLap() {
    final completedLapMs = _lapElapsedMs;
    _lapElapsedMs = 0;
    _nextSector = 1;

    if (_bestLapMs == null || completedLapMs < _bestLapMs!) {
      _bestLapMs = completedLapMs;
      _newRecord = true;
      _banner = 'NEW BEST LAP!';
      _bannerTimer = 2.0;
    } else {
      _banner = _currentLap < totalLaps ? 'LAP ${_currentLap + 1}/$totalLaps' : null;
      _bannerTimer = 1.6;
    }
    StorageService.instance.recordBestLapMs(completedLapMs);

    if (_currentLap >= totalLaps) {
      _finished = true;
      StorageService.instance.recordBestRaceMs(_totalElapsedMs).then((isBest) {
        if (isBest) {
          _newRecord = true;
          _syncHud();
        }
      });
      _banner = 'FINISH!';
      _bannerTimer = 3.0;
    } else {
      _currentLap++;
    }
  }

  _NearestTrackPoint _findNearestPoint(Vector2 pos) {
    var bestIdx = 0;
    var bestDistSq = double.infinity;
    for (var i = 0; i < _centerline.length; i++) {
      final d2 = pos.distanceToSquared(_centerline[i]);
      if (d2 < bestDistSq) {
        bestDistSq = d2;
        bestIdx = i;
      }
    }
    return _NearestTrackPoint(index: bestIdx, distance: math.sqrt(bestDistSq));
  }

  void _syncHud() {
    final speedKmh = (player.velocity.length * 0.48);
    hud.update(
      GameTelemetry(
        trackType: TrackType.neonCircuit,
        speedKmh: speedKmh,
        currentLap: _currentLap,
        totalLaps: totalLaps,
        currentLapTimeMs: _lapElapsedMs,
        bestLapTimeMs: _bestLapMs,
        totalRaceTimeMs: _totalElapsedMs,
        isFinished: _finished,
        isNewRecord: _newRecord,
        steeringInput: player.steeringOutput,
        throttleInput: player.throttleOutput,
        gasActive: _lastGasActive,
        brakeActive: _lastBrakeActive,
        bannerMessage: _banner,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    // Deep dark telemetry grid backdrop
    canvas.drawRect(
      const Rect.fromLTWH(-1200, -1400, 3600, 3200),
      Paint()..color = const Color(0xFF070B12),
    );

    final gridPaint = Paint()
      ..color = const Color(0xFF101929)
      ..strokeWidth = 1.5;
    for (var x = -900.0; x <= 1900.0; x += 120.0) {
      canvas.drawLine(Offset(x, -1100), Offset(x, 1400), gridPaint);
    }
    for (var y = -1100.0; y <= 1400.0; y += 120.0) {
      canvas.drawLine(Offset(-900, y), Offset(1900, y), gridPaint);
    }

    // Outer neon safety barrier glow
    canvas.drawPath(
      _outerRibbonPath,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = wallHalfWidth * 2 + 12
        ..strokeJoin = StrokeJoin.round,
    );

    // Off-track apron
    canvas.drawPath(
      _outerRibbonPath,
      Paint()
        ..color = const Color(0xFF0E1624)
        ..style = PaintingStyle.stroke
        ..strokeWidth = wallHalfWidth * 2
        ..strokeJoin = StrokeJoin.round,
    );

    // Neon crimson curb border
    canvas.drawPath(
      _outerRibbonPath,
      Paint()
        ..color = const Color(0xFFFF3D71).withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackHalfWidth * 2 + 14
        ..strokeJoin = StrokeJoin.round,
    );

    // Asphalt surface
    canvas.drawPath(
      _outerRibbonPath,
      Paint()
        ..color = const Color(0xFF1D2638)
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackHalfWidth * 2
        ..strokeJoin = StrokeJoin.round,
    );

    // Center dashed telemetry line
    canvas.drawPath(
      _centerDashedPath,
      Paint()
        ..color = const Color(0xFF3E4E6E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );

    // Checkered Start / Finish line at index 0
    _drawStartFinishLine(canvas);

    // Tire skidmarks
    for (final skid in _skidMarks) {
      canvas.save();
      canvas.translate(skid.pos.x, skid.pos.y);
      canvas.rotate(skid.angle);
      final p = Paint()
        ..color = const Color(0xFF06090F).withValues(alpha: skid.alpha);
      canvas.drawRect(const Rect.fromLTWH(-10, -4, 4, 8), p);
      canvas.drawRect(const Rect.fromLTWH(6, -4, 4, 8), p);
      canvas.restore();
    }

    super.render(canvas);
  }

  void _drawStartFinishLine(Canvas canvas) {
    final pos = _centerline[0];
    final tangent = _tangents[0];
    final lineAngle = math.atan2(tangent.x, -tangent.y);

    canvas.save();
    canvas.translate(pos.x, pos.y);
    canvas.rotate(lineAngle);

    const cols = 12;
    final cellW = (trackHalfWidth * 2) / cols;
    const cellH = 12.0;

    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < cols; col++) {
        final isWhite = (row + col).isEven;
        canvas.drawRect(
          Rect.fromLTWH(
            -trackHalfWidth + col * cellW,
            -cellH + row * cellH,
            cellW,
            cellH,
          ),
          Paint()
            ..color = isWhite
                ? const Color(0xFFF8FAFC)
                : const Color(0xFF090D16),
        );
      }
    }
    canvas.restore();
  }
}

class _NearestTrackPoint {
  final int index;
  final double distance;
  const _NearestTrackPoint({required this.index, required this.distance});
}

class _SkidSample {
  final Vector2 pos;
  final double angle;
  final double alpha;
  const _SkidSample({
    required this.pos,
    required this.angle,
    required this.alpha,
  });
}
