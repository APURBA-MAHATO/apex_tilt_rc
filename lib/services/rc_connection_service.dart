import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'storage_service.dart';
import 'tilt_control_service.dart';

enum RcTransportMode { ble, websocket }

enum RcConnectionStatus { disconnected, connecting, connected, error }

class PacketLogEntry {
  final DateTime timestamp;
  final String payload;
  final bool isSystem;
  final bool isError;

  const PacketLogEntry({
    required this.timestamp,
    required this.payload,
    this.isSystem = false,
    this.isError = false,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = (timestamp.millisecond ~/ 10).toString().padLeft(2, '0');
    return '$h:$m:$s.$ms';
  }
}

/// Manages real-time 20Hz RC control telemetry over BLE or Wi-Fi WebSocket.
class RcConnectionService extends ChangeNotifier {
  RcConnectionService._();

  static final RcConnectionService instance = RcConnectionService._();

  static const Duration transmitInterval = Duration(milliseconds: 50); // 20Hz

  // Well-known UART / serial-over-BLE characteristic UUIDs (ESP32 / HM-10 / Nordic)
  static const String _nordicUartRxUuid =
      '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const String _hm10SerialUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

  RcTransportMode _transportMode = RcTransportMode.websocket;
  RcConnectionStatus _status = RcConnectionStatus.disconnected;
  String _statusMessage = 'Ready to connect';
  bool _useJsonFormat = StorageService.instance.jsonFormat;
  bool _emergencyStopped = false;

  // BLE state
  BluetoothDevice? _bleDevice;
  BluetoothCharacteristic? _bleWriteChar;
  StreamSubscription<BluetoothConnectionState>? _bleConnSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  // WebSocket state
  WebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSub;
  String _wsUrl = StorageService.instance.wsUrl;

  // Telemetry & 20Hz loop
  Timer? _txTimer;
  bool _bleWriteInFlight = false;
  int _packetsInWindow = 0;
  DateTime _rateWindowStart = DateTime.now();
  double _currentHz = 0.0;
  int _totalPacketsSent = 0;
  String _lastPacket = 'S:0,T:0';
  final ListQueue<PacketLogEntry> _logs = ListQueue<PacketLogEntry>();

  RcTransportMode get transportMode => _transportMode;
  RcConnectionStatus get status => _status;
  String get statusMessage => _statusMessage;
  bool get useJsonFormat => _useJsonFormat;
  bool get emergencyStopped => _emergencyStopped;
  bool get isConnected => _status == RcConnectionStatus.connected;

  BluetoothDevice? get connectedBleDevice => _bleDevice;
  BluetoothCharacteristic? get bleWriteCharacteristic => _bleWriteChar;
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);
  bool get isScanning => _isScanning;
  String get wsUrl => _wsUrl;

  double get currentHz => _currentHz;
  int get totalPacketsSent => _totalPacketsSent;
  String get lastPacket => _lastPacket;
  List<PacketLogEntry> get logs => _logs.toList(growable: false);

  void setTransportMode(RcTransportMode mode) {
    if (_transportMode == mode) return;
    disconnect();
    _transportMode = mode;
    _statusMessage = mode == RcTransportMode.ble
        ? 'Select a BLE RC receiver'
        : 'Enter WebSocket endpoint';
    notifyListeners();
  }

  void setJsonFormat(bool value) {
    _useJsonFormat = value;
    StorageService.instance.setJsonFormat(value);
    _addLog(
      'Packet format -> ${value ? "JSON" : "Compact S/T"}',
      isSystem: true,
    );
    notifyListeners();
  }

  void setWsUrl(String url) {
    _wsUrl = url.trim();
    StorageService.instance.setWsUrl(_wsUrl);
  }

  /// Formats a control command packet from integer steering/throttle (-100..100).
  static String formatPacket({
    required int steeringInt,
    required int throttleInt,
    required bool jsonFormat,
  }) {
    final s = steeringInt.clamp(-100, 100);
    final t = throttleInt.clamp(-100, 100);
    if (jsonFormat) {
      return jsonEncode({'s': s, 't': t});
    }
    return 'S:$s,T:$t\n';
  }

  static int toControlInt(double normalized) =>
      (normalized.clamp(-1.0, 1.0) * 100).round();

  Future<void> startBleScan() async {
    if (_isScanning) return;
    if (kIsWeb) {
      _addLog(
        'BLE scanning is supported on Android/iOS builds (use WebSocket in web preview).',
        isSystem: true,
        isError: true,
      );
      notifyListeners();
      return;
    }

    try {
      _scanResults = [];
      _isScanning = true;
      notifyListeners();

      await _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        _scanResults = List<ScanResult>.from(results)
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
        notifyListeners();
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    } catch (e) {
      _addLog('BLE scan failed: $e', isSystem: true, isError: true);
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopBleScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    _isScanning = false;
    notifyListeners();
  }

  Future<void> connectBle(BluetoothDevice device) async {
    await disconnect();
    await stopBleScan();

    _transportMode = RcTransportMode.ble;
    _status = RcConnectionStatus.connecting;
    final name = device.platformName.isNotEmpty
        ? device.platformName
        : device.remoteId.str;
    _statusMessage = 'Connecting to $name...';
    _addLog('BLE connecting to $name', isSystem: true);
    notifyListeners();

    try {
      await device.connect(timeout: const Duration(seconds: 12));
      _bleDevice = device;

      _bleConnSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected &&
            _status != RcConnectionStatus.disconnected) {
          _handleUnexpectedDisconnect('BLE device disconnected');
        }
      });

      final services = await device.discoverServices();
      final writableChar = _pickBestWritableCharacteristic(services);
      if (writableChar == null) {
        throw StateError('No writable GATT characteristic found on device');
      }

      _bleWriteChar = writableChar;
      _status = RcConnectionStatus.connected;
      _emergencyStopped = false;
      _statusMessage = 'BLE: $name';
      _addLog(
        'BLE ready (${writableChar.characteristicUuid.str})',
        isSystem: true,
      );
      _startTransmitLoop();
      notifyListeners();
    } catch (e) {
      await _cleanupBle();
      _status = RcConnectionStatus.error;
      _statusMessage = 'BLE error: $e';
      _addLog('BLE connection error: $e', isSystem: true, isError: true);
      notifyListeners();
    }
  }

  BluetoothCharacteristic? _pickBestWritableCharacteristic(
    List<BluetoothService> services,
  ) {
    BluetoothCharacteristic? fallbackWriteNoResp;
    BluetoothCharacteristic? fallbackWrite;

    for (final service in services) {
      for (final char in service.characteristics) {
        final uuid = char.characteristicUuid.str.toLowerCase();
        final props = char.properties;
        final canWrite = props.write || props.writeWithoutResponse;
        if (!canWrite) continue;

        if (uuid == _nordicUartRxUuid || uuid == _hm10SerialUuid) {
          return char;
        }
        if (props.writeWithoutResponse && fallbackWriteNoResp == null) {
          fallbackWriteNoResp = char;
        } else if (props.write && fallbackWrite == null) {
          fallbackWrite = char;
        }
      }
    }
    return fallbackWriteNoResp ?? fallbackWrite;
  }

  Future<void> connectWebSocket(String url) async {
    await disconnect();
    setWsUrl(url);

    _transportMode = RcTransportMode.websocket;
    _status = RcConnectionStatus.connecting;
    _statusMessage = 'Connecting to $_wsUrl...';
    _addLog('WS connecting -> $_wsUrl', isSystem: true);
    notifyListeners();

    try {
      final uri = Uri.parse(_wsUrl);
      if (!uri.hasScheme || (uri.scheme != 'ws' && uri.scheme != 'wss')) {
        throw ArgumentError('URL must start with ws:// or wss://');
      }

      final channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(const Duration(seconds: 6));

      _wsChannel = channel;
      _wsSub = channel.stream.listen(
        (message) {
          _addLog('RX: $message', isSystem: true);
          notifyListeners();
        },
        onError: (Object error) {
          _handleUnexpectedDisconnect('WebSocket error: $error');
        },
        onDone: () {
          if (_status == RcConnectionStatus.connected) {
            _handleUnexpectedDisconnect('WebSocket closed by remote host');
          }
        },
      );

      _status = RcConnectionStatus.connected;
      _emergencyStopped = false;
      _statusMessage = 'WS: ${uri.host}:${uri.port}';
      _addLog('WebSocket connected', isSystem: true);
      _startTransmitLoop();
      notifyListeners();
    } catch (e) {
      await _cleanupWebSocket();
      _status = RcConnectionStatus.error;
      _statusMessage = 'WS error: $e';
      _addLog('WS connection error: $e', isSystem: true, isError: true);
      notifyListeners();
    }
  }

  /// Immediately transmits zero throttle & steering ("S:0,T:0\n") and pauses
  /// 20Hz transmission until [resumeTransmission] is called.
  Future<void> triggerEmergencyStop() async {
    _emergencyStopped = true;
    _currentHz = 0.0;
    const stopPacket = 'S:0,T:0\n';
    _lastPacket = stopPacket.trim();
    _addLog('E-STOP ENGAGED -> $stopPacket'.trim(), isSystem: true, isError: true);

    if (isConnected) {
      await _sendRawPacket(stopPacket);
      if (_useJsonFormat) {
        await _sendRawPacket(
          formatPacket(steeringInt: 0, throttleInt: 0, jsonFormat: true),
        );
      }
    }
    notifyListeners();
  }

  void resumeTransmission() {
    if (!_emergencyStopped) return;
    _emergencyStopped = false;
    _rateWindowStart = DateTime.now();
    _packetsInWindow = 0;
    _addLog('Transmission resumed', isSystem: true);
    notifyListeners();
  }

  void _startTransmitLoop() {
    _txTimer?.cancel();
    _rateWindowStart = DateTime.now();
    _packetsInWindow = 0;

    _txTimer = Timer.periodic(transmitInterval, (_) {
      if (!isConnected || _emergencyStopped) return;

      final tilt = TiltControlService.instance;
      final sInt = toControlInt(tilt.steering);
      final tInt = toControlInt(tilt.throttle);
      final payload = formatPacket(
        steeringInt: sInt,
        throttleInt: tInt,
        jsonFormat: _useJsonFormat,
      );

      _sendRawPacket(payload);
    });
  }

  Future<void> _sendRawPacket(String payload) async {
    try {
      if (_transportMode == RcTransportMode.websocket) {
        _wsChannel?.sink.add(payload);
      } else if (_transportMode == RcTransportMode.ble) {
        final char = _bleWriteChar;
        if (char == null || _bleWriteInFlight) return;
        _bleWriteInFlight = true;
        try {
          await char.write(
            utf8.encode(payload),
            withoutResponse: char.properties.writeWithoutResponse,
          );
        } finally {
          _bleWriteInFlight = false;
        }
      }

      _totalPacketsSent++;
      _packetsInWindow++;
      _lastPacket = payload.trim();

      final elapsedMs =
          DateTime.now().difference(_rateWindowStart).inMilliseconds;
      if (elapsedMs >= 500) {
        _currentHz = (_packetsInWindow * 1000.0) / elapsedMs;
        _packetsInWindow = 0;
        _rateWindowStart = DateTime.now();
      }

      // Log every packet or keep compact stream log up to date
      _addLog(_lastPacket);
      notifyListeners();
    } catch (e) {
      _addLog('TX failed: $e', isSystem: true, isError: true);
      notifyListeners();
    }
  }

  void _handleUnexpectedDisconnect(String reason) {
    _txTimer?.cancel();
    _txTimer = null;
    _currentHz = 0.0;
    _status = RcConnectionStatus.error;
    _statusMessage = reason;
    _addLog(reason, isSystem: true, isError: true);
    _cleanupBle();
    _cleanupWebSocket();
    notifyListeners();
  }

  Future<void> disconnect() async {
    _txTimer?.cancel();
    _txTimer = null;
    _currentHz = 0.0;

    if (isConnected) {
      await _sendRawPacket('S:0,T:0\n');
    }

    await _cleanupBle();
    await _cleanupWebSocket();

    _status = RcConnectionStatus.disconnected;
    _emergencyStopped = false;
    _statusMessage = 'Disconnected';
    _addLog('Disconnected', isSystem: true);
    notifyListeners();
  }

  Future<void> _cleanupBle() async {
    await _bleConnSub?.cancel();
    _bleConnSub = null;
    try {
      await _bleDevice?.disconnect();
    } catch (_) {}
    _bleDevice = null;
    _bleWriteChar = null;
    _bleWriteInFlight = false;
  }

  Future<void> _cleanupWebSocket() async {
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _wsChannel?.sink.close();
    } catch (_) {}
    _wsChannel = null;
  }

  void _addLog(String payload, {bool isSystem = false, bool isError = false}) {
    _logs.addFirst(
      PacketLogEntry(
        timestamp: DateTime.now(),
        payload: payload,
        isSystem: isSystem,
        isError: isError,
      ),
    );
    while (_logs.length > 35) {
      _logs.removeLast();
    }
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _txTimer?.cancel();
    _cleanupBle();
    _cleanupWebSocket();
    super.dispose();
  }
}
