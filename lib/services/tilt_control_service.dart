import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'storage_service.dart';

/// Unified singleton tilt & fallback input service feeding both RC Controller
/// mode and the Flame arcade racing game.
///
/// Combines accelerometer gravity orientation with gyroscope angular velocity
/// via a complementary filter, applies low-pass jitter smoothing, deadzone,
/// sensitivity scaling, axis inversion, and zero-center calibration.
/// On web/desktop (or whenever keyboard keys are held), WASD / Arrow keys
/// provide seamless fallback control.
class TiltControlService extends ChangeNotifier {
  TiltControlService._();

  static final TiltControlService instance = TiltControlService._();

  /// Maximum tilt angle (in radians, ~32 degrees) corresponding to 1.0 output
  /// at 1.0x sensitivity.
  static const double maxTiltRadians = 0.56;

  /// Roll deadzone (in radians) for Arcade Race steering.
  static const double arcadeRollDeadzoneRad = 0.08;

  /// Low-pass smoothing factor (0..1). Lower = smoother, higher = snappier.
  static const double _lowPassAlpha = 0.28;
  static const double _arcadeLowPassAlpha = 0.25;

  /// Complementary filter weight for gyroscope integration vs accelerometer.
  static const double _gyroBlend = 0.90;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _keyboardTickTimer;

  bool _isRunning = false;
  bool _hasHardwareSensors = false;
  bool _keyboardActive = false;
  bool _steeringKeysActive = false;
  bool _touchOverride = false;
  bool _hasSavedZeroRoll = false;

  // Sensor fusion state (radians)
  double _fusedRoll = 0.0;
  double _fusedPitch = 0.0;
  double _accelRoll = 0.0;
  double _accelPitch = 0.0;
  double _zeroRoll = 0.0;
  double _zeroPitch = 0.45; // Comfortable ~25° default holding angle
  bool _hasFirstAccelReading = false;
  DateTime? _lastGyroTimestamp;

  // Smoothed normalized outputs (-1.0 .. 1.0)
  double _steering = 0.0;
  double _throttle = 0.0;
  double _arcadeSteering = 0.0;

  // Manual touch override values
  double _touchSteering = 0.0;
  double _touchThrottle = 0.0;

  // Keyboard fallback state
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};
  double _keySteering = 0.0;
  double _keyThrottle = 0.0;
  double _arcadeKeySteering = 0.0;

  // Global user settings
  double _sensitivity = 1.0; // 0.5 .. 2.0
  double _deadzone = 0.06; // 0.0 .. 0.20
  bool _invertSteering = false;
  bool _invertThrottle = false;

  double get steering => _steering;
  double get throttle => _throttle;
  double get arcadeSteering => _arcadeSteering;
  double get sensitivity => _sensitivity;
  double get deadzone => _deadzone;
  bool get invertSteering => _invertSteering;
  bool get invertThrottle => _invertThrottle;
  bool get hasHardwareSensors => _hasHardwareSensors;
  bool get isKeyboardActive => _keyboardActive;
  bool get isSteeringKeysActive => _steeringKeysActive;
  bool get isGasKeyPressed =>
      _pressedKeys.contains(LogicalKeyboardKey.keyW) ||
      _pressedKeys.contains(LogicalKeyboardKey.arrowUp);
  bool get isBrakeKeyPressed =>
      _pressedKeys.contains(LogicalKeyboardKey.keyS) ||
      _pressedKeys.contains(LogicalKeyboardKey.arrowDown);
  bool get isTouchOverride => _touchOverride;

  /// Current relative tilt angles in degrees for telemetry displays.
  double get tiltRollDegrees => _wrapAngle(_fusedRoll - _zeroRoll) * 180 / math.pi;
  double get tiltPitchDegrees =>
      _wrapAngle(_fusedPitch - _zeroPitch) * 180 / math.pi;
  double get calibratedZeroRollDegrees => _zeroRoll * 180 / math.pi;

  Future<void> init() async {
    final storage = StorageService.instance;
    _sensitivity = storage.sensitivity.clamp(0.5, 2.0);
    _deadzone = storage.deadzone.clamp(0.0, 0.20);
    _invertSteering = storage.invertSteering;
    _invertThrottle = storage.invertThrottle;
    final savedZeroRoll = storage.calibratedZeroRoll;
    if (savedZeroRoll != null) {
      _zeroRoll = savedZeroRoll;
      _hasSavedZeroRoll = true;
    }

    start();
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    // On web/desktop, sensors_plus may throw or emit nothing; handle cleanly.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      _startMobileSensors();
    }

    // Periodic 60Hz keyboard / smoothing loop for crisp desktop testing
    _keyboardTickTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _tickKeyboardAndOverrides(),
    );
  }

  void _startMobileSensors() {
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 20),
      ).listen(
        _onAccelerometer,
        onError: (_) {
          _hasHardwareSensors = false;
        },
        cancelOnError: false,
      );

      _gyroSub = gyroscopeEventStream(
        samplingPeriod: const Duration(milliseconds: 20),
      ).listen(
        _onGyroscope,
        onError: (_) {
          // Gyroscope optional; accelerometer still functions standalone.
        },
        cancelOnError: false,
      );
    } catch (_) {
      _hasHardwareSensors = false;
    }
  }

  void _onAccelerometer(AccelerometerEvent event) {
    _hasHardwareSensors = true;

    // Landscape orientation mapping:
    // Y axis runs along the long edge (left/right steering tilt).
    // X/Z plane captures forward/backward pitch around the long edge.
    final xzNorm = math.sqrt(event.x * event.x + event.z * event.z);
    _accelRoll = math.atan2(event.y, xzNorm.clamp(0.001, 100.0));
    _accelPitch = math.atan2(event.x, event.z);

    if (!_hasFirstAccelReading) {
      _hasFirstAccelReading = true;
      _fusedRoll = _accelRoll;
      _fusedPitch = _accelPitch;
      if (!_hasSavedZeroRoll) {
        _zeroRoll = _accelRoll;
      }
      _zeroPitch = _accelPitch;
    } else if (_gyroSub == null) {
      _fusedRoll = _accelRoll;
      _fusedPitch = _accelPitch;
    } else {
      // Complementary correction step toward gravity vector
      _fusedRoll = _fusedRoll * _gyroBlend + _accelRoll * (1.0 - _gyroBlend);
      _fusedPitch = _wrapAngle(
        _fusedPitch +
            _wrapAngle(_accelPitch - _fusedPitch) * (1.0 - _gyroBlend),
      );
    }

    if (!_touchOverride) {
      _recomputeFromSensors();
    }
  }

  void _onGyroscope(GyroscopeEvent event) {
    final now = DateTime.now();
    if (_lastGyroTimestamp == null) {
      _lastGyroTimestamp = now;
      return;
    }
    final dt =
        now.difference(_lastGyroTimestamp!).inMicroseconds / 1000000.0;
    _lastGyroTimestamp = now;

    if (dt <= 0 || dt > 0.25 || !_hasFirstAccelReading) return;

    // Integrate angular velocity into fused pitch & roll.
    // Around Y is pitch rate; steering rate projects X & Z based on pitch.
    final pitchRate = -event.y;
    final rollRate =
        event.z * math.cos(_fusedPitch) - event.x * math.sin(_fusedPitch);

    _fusedPitch = _wrapAngle(_fusedPitch + pitchRate * dt);
    _fusedRoll =
        (_fusedRoll + rollRate * dt).clamp(-math.pi / 2, math.pi / 2);

    // Blend with latest accelerometer gravity estimate
    _fusedRoll = _fusedRoll * _gyroBlend + _accelRoll * (1.0 - _gyroBlend);
    _fusedPitch = _wrapAngle(
      _fusedPitch + _wrapAngle(_accelPitch - _fusedPitch) * (1.0 - _gyroBlend),
    );

    if (!_touchOverride) {
      _recomputeFromSensors();
    }
  }

  void _recomputeFromSensors() {
    final deltaRoll = _wrapAngle(_fusedRoll - _zeroRoll);
    final deltaPitch = _wrapAngle(_fusedPitch - _zeroPitch);

    if (!_keyboardActive) {
      // Pitching forward (top edge away from user) decreases pitch angle -> positive throttle
      final rawSteering = (deltaRoll / maxTiltRadians).clamp(-1.5, 1.5);
      final rawThrottle = (-deltaPitch / maxTiltRadians).clamp(-1.5, 1.5);

      final targetSteering = processAxis(
        rawValue: rawSteering,
        deadzone: _deadzone,
        sensitivity: _sensitivity,
        invert: _invertSteering,
      );
      final targetThrottle = processAxis(
        rawValue: rawThrottle,
        deadzone: _deadzone,
        sensitivity: _sensitivity,
        invert: _invertThrottle,
      );

      _steering = _steering + (targetSteering - _steering) * _lowPassAlpha;
      _throttle = _throttle + (targetThrottle - _throttle) * _lowPassAlpha;

      if (_steering.abs() < 0.005) _steering = 0.0;
      if (_throttle.abs() < 0.005) _throttle = 0.0;
    }

    if (!_steeringKeysActive) {
      final targetArcadeSteering = processRollRadians(
        deltaRollRad: deltaRoll,
        sensitivity: _sensitivity,
        invert: _invertSteering,
      );
      _arcadeSteering = _arcadeSteering +
          (targetArcadeSteering - _arcadeSteering) * _arcadeLowPassAlpha;
      if (_arcadeSteering.abs() < 0.005 && targetArcadeSteering == 0.0) {
        _arcadeSteering = 0.0;
      }
    }

    notifyListeners();
  }

  /// Captures the user's current holding pitch and roll as neutral (0.0, 0.0)
  /// and saves the resting roll angle.
  void calibrateCenter() {
    _zeroRoll = _fusedRoll;
    _zeroPitch = _fusedPitch;
    _hasSavedZeroRoll = true;
    StorageService.instance.setCalibratedZeroRoll(_zeroRoll);
    if (!_touchOverride && !_steeringKeysActive) {
      _arcadeSteering = 0.0;
    }
    if (!_touchOverride && !_keyboardActive) {
      _steering = 0.0;
      _throttle = 0.0;
    }
    notifyListeners();
  }

  /// Saves the current resting roll angle as neutral steering (0.0).
  void calibrateRollZero() {
    _zeroRoll = _fusedRoll;
    _hasSavedZeroRoll = true;
    StorageService.instance.setCalibratedZeroRoll(_zeroRoll);
    if (!_touchOverride && !_steeringKeysActive) {
      _arcadeSteering = 0.0;
    }
    if (!_touchOverride && !_keyboardActive) {
      _steering = 0.0;
    }
    notifyListeners();
  }

  /// Enables or disables touch slider override (used in RC Controller mode).
  void setTouchOverrideEnabled(bool enabled) {
    _touchOverride = enabled;
    if (!enabled) {
      _touchSteering = 0.0;
      _touchThrottle = 0.0;
      if (!_hasHardwareSensors && !_keyboardActive) {
        _steering = 0.0;
        _throttle = 0.0;
      }
    }
    notifyListeners();
  }

  /// Updates manual touch override inputs in [-1.0, 1.0].
  void setTouchInputs({required double steering, required double throttle}) {
    _touchSteering = steering.clamp(-1.0, 1.0);
    _touchThrottle = throttle.clamp(-1.0, 1.0);
    if (_touchOverride) {
      _steering = _invertSteering ? -_touchSteering : _touchSteering;
      _throttle = _invertThrottle ? -_touchThrottle : _touchThrottle;
      notifyListeners();
    }
  }

  void setSensitivity(double value) {
    _sensitivity = value.clamp(0.5, 2.0);
    StorageService.instance.setSensitivity(_sensitivity);
    notifyListeners();
  }

  void setDeadzone(double value) {
    _deadzone = value.clamp(0.0, 0.20);
    StorageService.instance.setDeadzone(_deadzone);
    notifyListeners();
  }

  void setInvertSteering(bool value) {
    _invertSteering = value;
    StorageService.instance.setInvertSteering(value);
    notifyListeners();
  }

  void setInvertThrottle(bool value) {
    _invertThrottle = value;
    StorageService.instance.setInvertThrottle(value);
    notifyListeners();
  }

  bool _handleKeyEvent(KeyEvent event) {
    final key = event.logicalKey;
    if (!_isControlKey(key)) return false;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _pressedKeys.add(key);
      if (key == LogicalKeyboardKey.keyC && event is KeyDownEvent) {
        calibrateCenter();
      }
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(key);
    }

    _keyboardActive = _pressedKeys.any(_isMovementKey);
    _steeringKeysActive = _pressedKeys.any(_isSteeringKey);
    if (key == LogicalKeyboardKey.keyW ||
        key == LogicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      notifyListeners();
    }
    return false;
  }

  bool _isControlKey(LogicalKeyboardKey key) =>
      _isMovementKey(key) || key == LogicalKeyboardKey.keyC;

  bool _isSteeringKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.keyD ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;
  }

  bool _isMovementKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.keyW ||
        key == LogicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.keyD ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.space;
  }

  void _tickKeyboardAndOverrides() {
    if (_touchOverride) return;

    double targetS = 0.0;
    double targetT = 0.0;

    if (_pressedKeys.contains(LogicalKeyboardKey.keyA) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowLeft)) {
      targetS -= 1.0;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyD) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowRight)) {
      targetS += 1.0;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyW) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowUp)) {
      targetT += 1.0;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyS) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowDown)) {
      targetT -= 1.0;
    }

    if (_pressedKeys.contains(LogicalKeyboardKey.space)) {
      targetT = 0.0;
      _keyThrottle = 0.0;
    }

    const ramp = 0.22;
    var changed = false;

    if (_steeringKeysActive || (!_hasHardwareSensors && _arcadeKeySteering != 0.0)) {
      _arcadeKeySteering =
          _arcadeKeySteering + (targetS - _arcadeKeySteering) * ramp;
      if (_arcadeKeySteering.abs() < 0.01 && targetS == 0.0) {
        _arcadeKeySteering = 0.0;
      }
      final rawScaled = (_arcadeKeySteering * _sensitivity).clamp(-1.0, 1.0);
      final nextArcadeS = _invertSteering ? -rawScaled : rawScaled;
      if (nextArcadeS != _arcadeSteering) {
        _arcadeSteering = nextArcadeS;
        changed = true;
      }
    } else if (_hasHardwareSensors && _arcadeKeySteering != 0.0) {
      _arcadeKeySteering = 0.0;
    }

    final hasKeys = targetS != 0.0 || targetT != 0.0 || _keyboardActive;
    if (hasKeys || !_hasHardwareSensors) {
      // Smoothly ramp keyboard input so desktop testing mimics analog tilt
      _keySteering = _keySteering + (targetS - _keySteering) * ramp;
      _keyThrottle = _keyThrottle + (targetT - _keyThrottle) * ramp;

      if (_keySteering.abs() < 0.01 && targetS == 0.0) _keySteering = 0.0;
      if (_keyThrottle.abs() < 0.01 && targetT == 0.0) _keyThrottle = 0.0;

      if (_keyboardActive || !_hasHardwareSensors) {
        final nextS = processAxis(
          rawValue: _keySteering,
          deadzone: _deadzone,
          sensitivity: _sensitivity,
          invert: _invertSteering,
        );
        final nextT = processAxis(
          rawValue: _keyThrottle,
          deadzone: _deadzone,
          sensitivity: _sensitivity,
          invert: _invertThrottle,
        );

        if (nextS != _steering || nextT != _throttle) {
          _steering = nextS;
          _throttle = nextT;
          changed = true;
        }
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Processes left/right roll tilt (in radians) with a ±0.08 rad deadzone,
  /// sensitivity scaling (0.5x..2.0x), clamping, and optional inversion.
  static double processRollRadians({
    required double deltaRollRad,
    double deadzoneRad = arcadeRollDeadzoneRad,
    double maxTiltRad = maxTiltRadians,
    required double sensitivity,
    required bool invert,
  }) {
    final absRoll = deltaRollRad.abs();
    if (absRoll <= deadzoneRad) {
      return 0.0;
    }
    final sign = deltaRollRad >= 0 ? 1.0 : -1.0;
    final usableSpan = (maxTiltRad - deadzoneRad).clamp(0.1, 2.0);
    final remapped = ((absRoll - deadzoneRad) / usableSpan) * sensitivity;
    final clamped = (sign * remapped).clamp(-1.0, 1.0);
    return invert ? -clamped : clamped;
  }

  /// Applies deadzone remapping, sensitivity scaling, clamping, and inversion
  /// to a normalized raw axis input.
  static double processAxis({
    required double rawValue,
    required double deadzone,
    required double sensitivity,
    required bool invert,
  }) {
    final absVal = rawValue.abs();
    if (absVal <= deadzone) {
      return 0.0;
    }

    // Remap [deadzone .. 1.0] smoothly to [0.0 .. 1.0] before sensitivity scaling
    final sign = rawValue >= 0 ? 1.0 : -1.0;
    final remapped = ((absVal - deadzone) / (1.0 - deadzone)) * sensitivity;
    final clamped = (sign * remapped).clamp(-1.0, 1.0);
    return invert ? -clamped : clamped;
  }

  static double _wrapAngle(double angle) {
    while (angle > math.pi) {
      angle -= 2 * math.pi;
    }
    while (angle < -math.pi) {
      angle += 2 * math.pi;
    }
    return angle;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  /// Stops active sensor streams, keyboard listener, and smoothing timer.
  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    _keyboardTickTimer?.cancel();
    _keyboardTickTimer = null;
  }
}
