import 'package:shared_preferences/shared_preferences.dart';

/// Persists global input preferences, WebSocket endpoint, and racing records.
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  static const _keySensitivity = 'tilt_sensitivity';
  static const _keyDeadzone = 'tilt_deadzone';
  static const _keyInvertSteering = 'invert_steering';
  static const _keyInvertThrottle = 'invert_throttle';
  static const _keyWsUrl = 'rc_ws_url';
  static const _keyJsonFormat = 'rc_json_format';
  static const _keyBestLapMs = 'neon_best_lap_ms';
  static const _keyBestRaceMs = 'neon_best_race_ms';
  static const _keyHighwayBestScore = 'highway_best_score';
  static const _keyHighwayBestDistance = 'highway_best_distance';
  static const _keySelectedCarId = 'selected_car_id';
  static const _keyCalibratedZeroRoll = 'calibrated_zero_roll';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  double get sensitivity => _prefs?.getDouble(_keySensitivity) ?? 1.0;
  Future<void> setSensitivity(double value) async =>
      await _prefs?.setDouble(_keySensitivity, value);

  double get deadzone => _prefs?.getDouble(_keyDeadzone) ?? 0.06;
  Future<void> setDeadzone(double value) async =>
      await _prefs?.setDouble(_keyDeadzone, value);

  bool get invertSteering => _prefs?.getBool(_keyInvertSteering) ?? false;
  Future<void> setInvertSteering(bool value) async =>
      await _prefs?.setBool(_keyInvertSteering, value);

  bool get invertThrottle => _prefs?.getBool(_keyInvertThrottle) ?? false;
  Future<void> setInvertThrottle(bool value) async =>
      await _prefs?.setBool(_keyInvertThrottle, value);

  String get wsUrl => _prefs?.getString(_keyWsUrl) ?? 'ws://192.168.4.1:81';
  Future<void> setWsUrl(String url) async =>
      await _prefs?.setString(_keyWsUrl, url);

  bool get jsonFormat => _prefs?.getBool(_keyJsonFormat) ?? false;
  Future<void> setJsonFormat(bool value) async =>
      await _prefs?.setBool(_keyJsonFormat, value);

  String get selectedCarId => _prefs?.getString(_keySelectedCarId) ?? 'balanced';
  Future<void> setSelectedCarId(String id) async =>
      await _prefs?.setString(_keySelectedCarId, id);

  double? get calibratedZeroRoll => _prefs?.getDouble(_keyCalibratedZeroRoll);
  Future<void> setCalibratedZeroRoll(double value) async =>
      await _prefs?.setDouble(_keyCalibratedZeroRoll, value);

  int? get bestLapMs => _prefs?.getInt(_keyBestLapMs);
  Future<bool> recordBestLapMs(int lapMs) async {
    final current = bestLapMs;
    if (current == null || lapMs < current) {
      await _prefs?.setInt(_keyBestLapMs, lapMs);
      return true;
    }
    return false;
  }

  int? get bestRaceMs => _prefs?.getInt(_keyBestRaceMs);
  Future<bool> recordBestRaceMs(int raceMs) async {
    final current = bestRaceMs;
    if (current == null || raceMs < current) {
      await _prefs?.setInt(_keyBestRaceMs, raceMs);
      return true;
    }
    return false;
  }

  int get highwayBestScore => _prefs?.getInt(_keyHighwayBestScore) ?? 0;
  Future<bool> recordHighwayBestScore(int score) async {
    if (score > highwayBestScore) {
      await _prefs?.setInt(_keyHighwayBestScore, score);
      return true;
    }
    return false;
  }

  int get highwayBestDistance => _prefs?.getInt(_keyHighwayBestDistance) ?? 0;
  Future<bool> recordHighwayBestDistance(int meters) async {
    if (meters > highwayBestDistance) {
      await _prefs?.setInt(_keyHighwayBestDistance, meters);
      return true;
    }
    return false;
  }

  static String formatDurationMs(int? ms) {
    if (ms == null || ms <= 0) return '--:--.--';
    final minutes = ms ~/ 60000;
    final seconds = (ms % 60000) ~/ 1000;
    final hundredths = (ms % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${hundredths.toString().padLeft(2, '0')}';
  }
}
