import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../models/car_spec.dart';

/// Procedural vector top-down arcade racing vehicle with drift friction,
/// speed-dependent steering response, and visual steering/brake indicators.
class PlayerCar extends PositionComponent with CollisionCallbacks {
  final CarSpec spec;
  final void Function(PositionComponent other)? onCarCollision;

  Vector2 velocity = Vector2.zero();
  double _steeringInput = 0.0;
  double _throttleInput = 0.0;
  bool _gasPressed = false;
  bool _brakePressed = false;
  double _gasLevel = 0.0;
  double _brakeLevel = 0.0;
  double _boostTimer = 0.0;
  double _invulnTimer = 0.0;

  /// Surface grip multiplier (1.0 on asphalt, < 1.0 off-track).
  double surfaceGrip = 1.0;

  /// Latest lateral drift speed for skidmark emission.
  double currentDriftSpeed = 0.0;

  PlayerCar({
    required this.spec,
    this.onCarCollision,
    Vector2? position,
  }) : super(
          position: position ?? Vector2.zero(),
          size: Vector2(28, 52),
          anchor: Anchor.center,
          priority: 20,
        );

  bool get isBoosting => _boostTimer > 0;
  bool get isInvulnerable => _invulnTimer > 0;
  double get forwardSpeed => velocity.dot(_forwardVector);
  double get steeringOutput => _steeringInput;
  double get throttleOutput => _throttleInput;

  Vector2 get _forwardVector => Vector2(math.sin(angle), -math.cos(angle));
  Vector2 get _rightVector => Vector2(math.cos(angle), math.sin(angle));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      RectangleHitbox(
        size: Vector2(22, 44),
        position: Vector2(3, 4),
      ),
    );
  }

  void setControls({required double steering, required double throttle}) {
    _steeringInput = steering.clamp(-1.0, 1.0);
    _throttleInput = throttle.clamp(-1.0, 1.0);
    _gasPressed = _throttleInput > 0.05;
    _brakePressed = _throttleInput < -0.05;
  }

  /// Sets decoupled Arcade Race controls: analog roll steering plus digital
  /// GAS / BRAKE pedals that ramp smoothly inside the physics step.
  void setArcadeControls({
    required double steering,
    required bool gasPressed,
    required bool brakePressed,
  }) {
    _steeringInput = steering.clamp(-1.0, 1.0);
    _gasPressed = gasPressed;
    _brakePressed = brakePressed;
  }

  void activateBoost([double seconds = 2.0]) {
    _boostTimer = math.max(_boostTimer, seconds);
  }

  void triggerInvulnerability([double seconds = 1.3]) {
    _invulnTimer = seconds;
  }

  void resetPhysics({required Vector2 position, double angle = 0.0}) {
    this.position.setFrom(position);
    this.angle = angle;
    velocity.setZero();
    _steeringInput = 0.0;
    _throttleInput = 0.0;
    _gasPressed = false;
    _brakePressed = false;
    _gasLevel = 0.0;
    _brakeLevel = 0.0;
    _boostTimer = 0.0;
    _invulnTimer = 0.0;
    currentDriftSpeed = 0.0;
  }

  void _updatePedalRamp(double dt) {
    if (_brakePressed) {
      _gasLevel = math.max(0.0, _gasLevel - dt * 7.5);
      _brakeLevel = (_brakeLevel + dt * 3.6).clamp(0.0, 1.0);
    } else if (_gasPressed) {
      _brakeLevel = math.max(0.0, _brakeLevel - dt * 6.5);
      _gasLevel = _gasLevel + (1.0 - _gasLevel) * math.min(1.0, dt * 4.8);
      if (_gasLevel > 0.995) _gasLevel = 1.0;
    } else {
      _gasLevel = math.max(0.0, _gasLevel - dt * 5.0);
      _brakeLevel = math.max(0.0, _brakeLevel - dt * 5.0);
    }
    _throttleInput = (_gasLevel - _brakeLevel).clamp(-1.0, 1.0);
  }

  /// Updates full 2D top-down arcade car physics (for Neon Circuit).
  void updateCircuitPhysics(double dt) {
    _tickTimers(dt);
    _updatePedalRamp(dt);

    final forward = _forwardVector;
    final right = _rightVector;

    var vForward = velocity.dot(forward);
    var vLateral = velocity.dot(right);

    final effectiveMaxSpeed =
        spec.maxSpeed * (isBoosting ? 1.32 : 1.0) * (0.55 + 0.45 * surfaceGrip);

    // Smooth acceleration ramp-up on GAS, progressive braking/reverse on BRAKE,
    // and natural coasting drag when neither pedal is held.
    if (_brakeLevel > 0.01) {
      if (vForward > 6.0) {
        vForward = math.max(
          0.0,
          vForward - _brakeLevel * spec.acceleration * 1.65 * dt,
        );
      } else {
        vForward -= _brakeLevel * spec.acceleration * 0.78 * dt;
      }
    } else if (_gasLevel > 0.01) {
      final boostFactor = isBoosting ? 1.45 : 1.0;
      final reverseRecovery = vForward < 0 ? 1.4 : 1.0;
      vForward +=
          _gasLevel * spec.acceleration * boostFactor * reverseRecovery * dt;
    } else {
      vForward *= math.exp(-1.45 * dt);
      if (vForward.abs() < 2.5) vForward = 0.0;
    }

    // Clamp forward & reverse speed
    vForward = vForward.clamp(-spec.maxSpeed * 0.42, effectiveMaxSpeed);

    // Speed-dependent steering response (smooth at low speed, stable at high speed)
    final speedNorm = (vForward.abs() / 130.0).clamp(0.0, 1.0);
    final highSpeedStability = 1.0 - 0.25 * (vForward.abs() / spec.maxSpeed).clamp(0.0, 1.0);
    final reverseSign = vForward >= -5.0 ? 1.0 : -1.0;
    angle += _steeringInput *
        spec.turnRate *
        speedNorm *
        highSpeedStability *
        reverseSign *
        dt;

    // Lateral drift friction: decompose and exponentially damp side slip
    final grip = spec.driftGrip * surfaceGrip;
    vLateral *= math.exp(-grip * dt);
    currentDriftSpeed = vLateral.abs();

    // Reconstruct world velocity along updated heading
    final newForward = _forwardVector;
    final newRight = _rightVector;
    velocity = newForward * vForward + newRight * vLateral;
    position += velocity * dt;
  }

  /// Updates 3-lane highway physics (for Endless Highway).
  void updateHighwayPhysics(
    double dt, {
    required double minX,
    required double maxX,
  }) {
    _tickTimers(dt);
    _updatePedalRamp(dt);

    var nextUpSpeed = -velocity.y;
    final maxHighwaySpeed =
        isBoosting ? spec.maxSpeed * 1.42 : spec.maxSpeed;

    if (isBoosting) {
      nextUpSpeed +=
          (maxHighwaySpeed - nextUpSpeed) * math.min(1.0, dt * 5.0);
    } else if (_brakeLevel > 0.01) {
      nextUpSpeed = math.max(
        0.0,
        nextUpSpeed - _brakeLevel * spec.acceleration * 1.65 * dt,
      );
    } else if (_gasLevel > 0.01) {
      nextUpSpeed += _gasLevel * spec.acceleration * 1.15 * dt;
    } else {
      nextUpSpeed *= math.exp(-1.15 * dt);
      if (nextUpSpeed < 2.0) nextUpSpeed = 0.0;
    }

    nextUpSpeed = nextUpSpeed.clamp(0.0, maxHighwaySpeed);

    // Lateral lane-change speed proportional to steering and car handling
    final lateralTarget = _steeringInput * (260.0 + spec.turnRate * 42.0);
    final nextXSpeed =
        velocity.x + (lateralTarget - velocity.x) * math.min(1.0, dt * 9.0);

    velocity.setValues(nextXSpeed, -nextUpSpeed);
    position += velocity * dt;

    // Visual body tilt when changing lanes
    angle = (velocity.x / 520.0).clamp(-0.42, 0.42);
    currentDriftSpeed = velocity.x.abs() > 170 ? velocity.x.abs() * 0.6 : 0.0;

    // Highway guardrail clamp with gentle bounce
    if (position.x < minX) {
      position.x = minX;
      velocity.x = velocity.x.abs() * 0.25;
    } else if (position.x > maxX) {
      position.x = maxX;
      velocity.x = -velocity.x.abs() * 0.25;
    }
  }

  void _tickTimers(double dt) {
    if (_boostTimer > 0) _boostTimer = math.max(0.0, _boostTimer - dt);
    if (_invulnTimer > 0) _invulnTimer = math.max(0.0, _invulnTimer - dt);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    onCarCollision?.call(other);
  }

  @override
  void render(Canvas canvas) {
    // Blink during post-hit invulnerability
    if (isInvulnerable && ((_invulnTimer * 14).floor().isEven)) {
      return;
    }

    final w = size.x;
    final h = size.y;

    // Underbody neon glow
    final glowColor = isBoosting ? const Color(0xFF00E676) : spec.primaryColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-2, 1, w + 4, h - 2),
        const Radius.circular(9),
      ),
      Paint()
        ..color = glowColor.withValues(alpha: isBoosting ? 0.45 : 0.24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Tires (front wheels pivot slightly with steering)
    final wheelPaint = Paint()..color = const Color(0xFF0A0D14);
    final steerWheelAngle = _steeringInput * 0.35;
    _drawWheel(canvas, 1.5, 11, steerWheelAngle, wheelPaint);
    _drawWheel(canvas, w - 1.5, 11, steerWheelAngle, wheelPaint);
    _drawWheel(canvas, 1.5, h - 12, 0, wheelPaint);
    _drawWheel(canvas, w - 1.5, h - 12, 0, wheelPaint);

    // Main aerodynamic body
    final bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(2, 2, w - 4, h - 4),
      topLeft: const Radius.circular(9),
      topRight: const Radius.circular(9),
      bottomLeft: const Radius.circular(5),
      bottomRight: const Radius.circular(5),
    );
    canvas.drawRRect(bodyRect, Paint()..color = spec.primaryColor);

    // Racing center stripe
    canvas.drawRect(
      Rect.fromLTWH(w / 2 - 2.2, 3, 4.4, h - 7),
      Paint()..color = spec.accentColor.withValues(alpha: 0.85),
    );

    // Cockpit windshield
    final windshield = Path()
      ..moveTo(6, 15)
      ..lineTo(w - 6, 15)
      ..lineTo(w - 8, 25)
      ..lineTo(8, 25)
      ..close();
    canvas.drawPath(windshield, Paint()..color = const Color(0xFF0F172A));

    // Rear window + spoiler
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(7, 31, w - 14, 7),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, h - 6, w - 4, 3.5),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFF111827),
    );

    // Headlight cones
    final beamPaint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.fill;
    for (final x in [6.5, w - 6.5]) {
      final cone = Path()
        ..moveTo(x - 2, 3)
        ..lineTo(x + 2, 3)
        ..lineTo(x + 9, -24)
        ..lineTo(x - 9, -24)
        ..close();
      canvas.drawPath(cone, beamPaint);
      canvas.drawCircle(
        Offset(x, 3.5),
        2.2,
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }

    // Brake / tail lights
    final isBraking = _throttleInput < -0.05;
    final tailColor =
        isBraking ? const Color(0xFFFF1744) : const Color(0xFF991B1B);
    canvas.drawRect(
      Rect.fromLTWH(4, h - 4, 6, 2.5),
      Paint()..color = tailColor,
    );
    canvas.drawRect(
      Rect.fromLTWH(w - 10, h - 4, 6, 2.5),
      Paint()..color = tailColor,
    );

    // Nitro flame exhaust when boosting
    if (isBoosting) {
      final flamePaint = Paint()..color = const Color(0xFF00E5FF);
      canvas.drawCircle(Offset(w / 2 - 4, h + 3), 3.2, flamePaint);
      canvas.drawCircle(Offset(w / 2 + 4, h + 3), 3.2, flamePaint);
    }
  }

  void _drawWheel(
    Canvas canvas,
    double cx,
    double cy,
    double wheelAngle,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(wheelAngle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-2.5, -5, 5, 10),
        const Radius.circular(1.5),
      ),
      paint,
    );
    canvas.restore();
  }
}
