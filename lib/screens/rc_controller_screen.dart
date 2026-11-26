import 'package:material_ui/material_ui.dart';

import '../services/rc_connection_service.dart';
import '../services/tilt_control_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ble_scanner_modal.dart';
import '../widgets/telemetry_gauges.dart';

class RcControllerScreen extends StatefulWidget {
  const RcControllerScreen({super.key});

  @override
  State<RcControllerScreen> createState() => _RcControllerScreenState();
}

class _RcControllerScreenState extends State<RcControllerScreen> {
  final _tilt = TiltControlService.instance;
  final _rc = RcConnectionService.instance;
  late final TextEditingController _wsController;

  double _touchSteer = 0.0;
  double _touchThrottle = 0.0;

  @override
  void initState() {
    super.initState();
    _wsController = TextEditingController(text: _rc.wsUrl);
  }

  @override
  void dispose() {
    _tilt.setTouchOverrideEnabled(false);
    _wsController.dispose();
    super.dispose();
  }

  void _updateTouchControls({double? steer, double? throttle}) {
    setState(() {
      if (steer != null) _touchSteer = steer;
      if (throttle != null) _touchThrottle = throttle;
    });
    _tilt.setTouchInputs(steering: _touchSteer, throttle: _touchThrottle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_tilt, _rc]),
          builder: (context, _) {
            final steerInt = RcConnectionService.toControlInt(_tilt.steering);
            final throtInt = RcConnectionService.toControlInt(_tilt.throttle);
            final previewPacket = RcConnectionService.formatPacket(
              steeringInt: _rc.emergencyStopped ? 0 : steerInt,
              throttleInt: _rc.emergencyStopped ? 0 : throtInt,
              jsonFormat: _rc.useJsonFormat,
            ).trim();

            return Column(
              children: [
                _buildHeaderBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Row(
                      children: [
                        // Left Column: Connectivity & Left-Thumb Calibrate Zero
                        SizedBox(
                          width: 245,
                          child: Column(
                            children: [
                              Expanded(child: _buildConnectivityCard()),
                              const SizedBox(height: 10),
                              _buildCalibrateZeroButton(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Center: Horizon / Steering + Throttle or Touch Override
                        Expanded(
                          flex: 5,
                          child: _buildTelemetryCenter(
                            steerInt: steerInt,
                            throtInt: throtInt,
                            previewPacket: previewPacket,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Right Column: Packet Log + Emergency Stop
                        SizedBox(
                          width: 245,
                          child: Column(
                            children: [
                              Expanded(child: _buildPacketLogCard()),
                              const SizedBox(height: 10),
                              _buildEmergencyStopButton(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    final statusColor = switch (_rc.status) {
      RcConnectionStatus.connected =>
        _rc.emergencyStopped ? AppTheme.amber : AppTheme.green,
      RcConnectionStatus.connecting => AppTheme.amber,
      RcConnectionStatus.error => AppTheme.red,
      RcConnectionStatus.disconnected => AppTheme.textSecondary,
    };

    final statusText = switch (_rc.status) {
      RcConnectionStatus.connected =>
        _rc.emergencyStopped ? 'E-STOP PAUSED' : 'CONNECTED',
      RcConnectionStatus.connecting => 'CONNECTING',
      RcConnectionStatus.error => 'ERROR',
      RcConnectionStatus.disconnected => 'OFFLINE',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back to Home',
          ),
          const Text(
            'RC CONTROLLER',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 12),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Packet Rate indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'TX: ${_rc.currentHz.toStringAsFixed(1)} Hz',
              style: AppTheme.monoTelemetry.copyWith(
                fontSize: 11,
                color: _rc.isConnected ? AppTheme.cyan : AppTheme.textSecondary,
              ),
            ),
          ),
          const Spacer(),

          // Packet Format Toggle (S:0,T:0 vs JSON)
          _HeaderPillToggle(
            label: _rc.useJsonFormat ? 'FMT: JSON' : 'FMT: S/T',
            active: _rc.useJsonFormat,
            activeColor: AppTheme.purple,
            onTap: () => _rc.setJsonFormat(!_rc.useJsonFormat),
          ),
          const SizedBox(width: 8),

          // Touch Slider Override Toggle
          _HeaderPillToggle(
            label: _tilt.isTouchOverride ? 'INPUT: TOUCH' : 'INPUT: TILT',
            active: _tilt.isTouchOverride,
            activeColor: AppTheme.amber,
            onTap: () {
              final next = !_tilt.isTouchOverride;
              _tilt.setTouchOverrideEnabled(next);
              _updateTouchControls(steer: 0.0, throttle: 0.0);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConnectivityCard() {
    final isBle = _rc.transportMode == RcTransportMode.ble;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dual Connectivity Segmented Toggle
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ModeTab(
                    label: 'WI-FI WS',
                    icon: Icons.wifi_rounded,
                    selected: !isBle,
                    onTap: () => _rc.setTransportMode(RcTransportMode.websocket),
                  ),
                ),
                Expanded(
                  child: _ModeTab(
                    label: 'BLE GATT',
                    icon: Icons.bluetooth_rounded,
                    selected: isBle,
                    onTap: () => _rc.setTransportMode(RcTransportMode.ble),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (!isBle) ...[
            const Text(
              'ESP32 / ESP8266 WEBSOCKET',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _wsController,
              enabled: !_rc.isConnected,
              style: AppTheme.monoTelemetry.copyWith(fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                filled: true,
                fillColor: AppTheme.surfaceElevated,
                hintText: 'ws://192.168.4.1:81',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _rc.status == RcConnectionStatus.connecting
                  ? null
                  : () {
                      if (_rc.isConnected) {
                        _rc.disconnect();
                      } else {
                        _rc.connectWebSocket(_wsController.text);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _rc.isConnected ? AppTheme.red : AppTheme.cyan,
                foregroundColor: const Color(0xFF061018),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(
                _rc.isConnected ? Icons.link_off_rounded : Icons.link_rounded,
                size: 16,
              ),
              label: Text(
                _rc.isConnected ? 'DISCONNECT WS' : 'CONNECT WS',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ] else ...[
            const Text(
              'BLUETOOTH LOW ENERGY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                _rc.connectedBleDevice != null
                    ? 'Device: ${_rc.connectedBleDevice!.platformName.isNotEmpty ? _rc.connectedBleDevice!.platformName : _rc.connectedBleDevice!.remoteId.str}'
                    : 'No BLE peripheral bound',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.monoTelemetry.copyWith(
                  fontSize: 11,
                  color: _rc.isConnected
                      ? AppTheme.green
                      : AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                if (_rc.isConnected) {
                  _rc.disconnect();
                } else {
                  BleScannerModal.show(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _rc.isConnected ? AppTheme.red : AppTheme.cyan,
                foregroundColor: const Color(0xFF061018),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(
                _rc.isConnected
                    ? Icons.bluetooth_disabled_rounded
                    : Icons.bluetooth_searching_rounded,
                size: 16,
              ),
              label: Text(
                _rc.isConnected ? 'DISCONNECT BLE' : 'SCAN & CONNECT BLE',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ],
          const Spacer(),
          Text(
            _rc.statusMessage,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: _rc.status == RcConnectionStatus.error
                  ? AppTheme.red
                  : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrateZeroButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () {
          _tilt.calibrateCenter();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tilt center zeroed (0, 0)!'),
              duration: Duration(milliseconds: 900),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.surfaceElevated,
          foregroundColor: AppTheme.cyan,
          side: const BorderSide(color: AppTheme.cyan, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.center_focus_strong_rounded, size: 22),
        label: const Text(
          'CALIBRATE ZERO',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryCenter({
    required int steerInt,
    required int throtInt,
    required String previewPacket,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _rc.emergencyStopped ? AppTheme.red : AppTheme.border,
          width: _rc.emergencyStopped ? 1.8 : 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _tilt.isTouchOverride
                    ? 'MANUAL TOUCH OVERRIDE'
                    : 'TILT HORIZON TELEMETRY',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppTheme.textSecondary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  previewPacket,
                  style: AppTheme.monoTelemetry.copyWith(
                    fontSize: 11,
                    color:
                        _rc.emergencyStopped ? AppTheme.red : AppTheme.cyan,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: _tilt.isTouchOverride
                ? _buildTouchOverridePanel()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TiltHorizonIndicator(
                            steering:
                                _rc.emergencyStopped ? 0.0 : _tilt.steering,
                            throttle:
                                _rc.emergencyStopped ? 0.0 : _tilt.throttle,
                            emergencyStopped: _rc.emergencyStopped,
                            size: 160,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'STEER: ${steerInt >= 0 ? '+' : ''}$steerInt',
                            style: AppTheme.monoTelemetry.copyWith(
                              fontSize: 14,
                              color: AppTheme.cyan,
                            ),
                          ),
                        ],
                      ),
                      ThrottleBar(
                        throttle: _rc.emergencyStopped ? 0.0 : _tilt.throttle,
                        emergencyStopped: _rc.emergencyStopped,
                        height: 152,
                        width: 40,
                      ),
                    ],
                  ),
          ),
          Text(
            _tilt.isTouchOverride
                ? 'Drag sliders to drive • Release auto-centers'
                : 'Tilt to drive (or use WASD / Arrow Keys on desktop)',
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTouchOverridePanel() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Horizontal steering slider
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'STEERING: ${(_touchSteer * 100).round()}',
                style: AppTheme.monoTelemetry.copyWith(
                  fontSize: 13,
                  color: AppTheme.cyan,
                ),
              ),
              const SizedBox(height: 8),
              Slider(
                value: _touchSteer,
                min: -1.0,
                max: 1.0,
                onChanged: (v) => _updateTouchControls(steer: v),
                onChangeEnd: (_) => _updateTouchControls(steer: 0.0),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('LEFT',
                      style: TextStyle(
                          fontSize: 9, color: AppTheme.textSecondary)),
                  Text('CENTER',
                      style: TextStyle(
                          fontSize: 9, color: AppTheme.textSecondary)),
                  Text('RIGHT',
                      style: TextStyle(
                          fontSize: 9, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Vertical throttle slider
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'THROT: ${(_touchThrottle * 100).round()}',
              style: AppTheme.monoTelemetry.copyWith(
                fontSize: 13,
                color: AppTheme.green,
              ),
            ),
            SizedBox(
              height: 150,
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  value: _touchThrottle,
                  min: -1.0,
                  max: 1.0,
                  activeColor: AppTheme.green,
                  onChanged: (v) => _updateTouchControls(throttle: v),
                  onChangeEnd: (_) => _updateTouchControls(throttle: 0.0),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPacketLogCard() {
    final logs = _rc.logs;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PACKET LOG (${_rc.totalPacketsSent})',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: AppTheme.textSecondary,
                ),
              ),
              InkWell(
                onTap: _rc.clearLogs,
                child: const Text(
                  'CLEAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.cyan,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: AppTheme.border, height: 10),
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'Connect BLE or WebSocket\nto view 20Hz TX stream',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final entry = logs[index];
                      final color = entry.isError
                          ? AppTheme.red
                          : (entry.isSystem ? AppTheme.amber : AppTheme.green);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '[${entry.formattedTime}] ${entry.payload}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.monoTelemetry.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: color,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyStopButton() {
    final stopped = _rc.emergencyStopped;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () {
          if (stopped) {
            _rc.resumeTransmission();
          } else {
            _rc.triggerEmergencyStop();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: stopped ? AppTheme.amber : AppTheme.red,
          foregroundColor: stopped ? const Color(0xFF140D00) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
        ),
        icon: Icon(
          stopped ? Icons.play_arrow_rounded : Icons.dangerous_rounded,
          size: 24,
        ),
        label: Text(
          stopped ? 'RESUME TX' : 'EMERGENCY STOP',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.cyan : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? const Color(0xFF061018) : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color:
                    selected ? const Color(0xFF061018) : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderPillToggle extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _HeaderPillToggle({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.18)
              : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? activeColor : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: active ? activeColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
