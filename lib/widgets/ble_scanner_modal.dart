import 'package:material_ui/material_ui.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/rc_connection_service.dart';
import '../theme/app_theme.dart';

class BleScannerModal extends StatefulWidget {
  const BleScannerModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const BleScannerModal(),
    );
  }

  @override
  State<BleScannerModal> createState() => _BleScannerModalState();
}

class _BleScannerModalState extends State<BleScannerModal> {
  final _rc = RcConnectionService.instance;

  @override
  void initState() {
    super.initState();
    _rc.startBleScan();
  }

  @override
  void dispose() {
    _rc.stopBleScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.border, width: 1.4),
      ),
      child: SizedBox(
        width: 480,
        height: 300,
        child: ListenableBuilder(
          listenable: _rc,
          builder: (context, _) {
            final List<ScanResult> results = _rc.scanResults;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bluetooth_searching_rounded,
                          color: AppTheme.cyan),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'BLE DEVICE SCANNER',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      if (_rc.isScanning)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.cyan,
                          ),
                        ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed:
                            _rc.isScanning ? _rc.stopBleScan : _rc.startBleScan,
                        child: Text(_rc.isScanning ? 'STOP' : 'RESCAN'),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const Divider(color: AppTheme.border),
                  Expanded(
                    child: results.isEmpty
                        ? Center(
                            child: Text(
                              _rc.isScanning
                                  ? 'Scanning for ESP32 / HM-10 / BLE RC receivers...'
                                  : 'No BLE peripherals found.\nEnsure Bluetooth & Location are enabled.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final r = results[index];
                              final name = r.device.platformName.isNotEmpty
                                  ? r.device.platformName
                                  : (r.advertisementData.advName.isNotEmpty
                                      ? r.advertisementData.advName
                                      : 'Unnamed BLE Device');
                              return _BleResultTile(
                                name: name,
                                id: r.device.remoteId.str,
                                rssi: r.rssi,
                                onConnect: () async {
                                  Navigator.of(context).pop();
                                  await _rc.connectBle(r.device);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BleResultTile extends StatelessWidget {
  final String name;
  final String id;
  final int rssi;
  final VoidCallback onConnect;

  const _BleResultTile({
    required this.name,
    required this.id,
    required this.rssi,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.memory_rounded, color: AppTheme.cyan, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '$id  •  $rssi dBm',
                  style: AppTheme.monoTelemetry.copyWith(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cyan,
              foregroundColor: const Color(0xFF061018),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text(
              'CONNECT',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
