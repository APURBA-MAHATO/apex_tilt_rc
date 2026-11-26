import 'package:material_ui/material_ui.dart';

import '../services/storage_service.dart';
import '../services/tilt_control_service.dart';
import '../theme/app_theme.dart';
import '../widgets/telemetry_gauges.dart';
import '../widgets/top_settings_bar.dart';
import 'arcade_race_screen.dart';
import 'rc_controller_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tilt = TiltControlService.instance;
    final storage = StorageService.instance;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopSettingsBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Row(
                  children: [
                    // Mode 1: RC Car Controller
                    Expanded(
                      flex: 5,
                      child: _ModeCard(
                        title: 'RC CAR CONTROLLER',
                        subtitle:
                            'Real-time 20Hz BLE & Wi-Fi WebSocket telemetry for ESP32 / ESP8266 / Arduino.',
                        badge: 'HARDWARE MODE',
                        accentColor: AppTheme.cyan,
                        icon: Icons.settings_remote_rounded,
                        highlights: const [
                          'BLE GATT Auto-Discovery + WebSocket',
                          'S:<steer>,T:<throttle> & JSON Packets',
                          'Emergency Stop & Touch Override',
                        ],
                        ctaLabel: 'OPEN CONTROLLER',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RcControllerScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Mode 2: Arcade Race Mode
                    Expanded(
                      flex: 5,
                      child: _ModeCard(
                        title: 'ARCADE RACE MODE',
                        subtitle:
                            'Lightweight Flame 2D top-down racing powered by the same tilt engine.',
                        badge: 'FLAME 2D ENGINE',
                        accentColor: AppTheme.green,
                        icon: Icons.sports_motorsports_rounded,
                        highlights: [
                          'Neon Circuit (Best Lap: ${StorageService.formatDurationMs(storage.bestLapMs)})',
                          'Endless Highway (Best: ${storage.highwayBestScore} pts)',
                          '3 Vehicles • Drift Physics • Zero Assets',
                        ],
                        ctaLabel: 'ENTER TRACK',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ArcadeRaceScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Right-side Live Tilt Telemetry Mini-Panel
                    SizedBox(
                      width: 196,
                      child: ListenableBuilder(
                        listenable: tilt,
                        builder: (context, _) {
                          final steerPct = (tilt.steering * 100).round();
                          final throtPct = (tilt.throttle * 100).round();
                          final sourceLabel = tilt.isKeyboardActive
                              ? 'KEYBOARD (WASD)'
                              : (tilt.hasHardwareSensors
                                  ? 'GYRO + ACCEL'
                                  : 'DESKTOP FALLBACK');

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'LIVE INPUT',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.0,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.cyan
                                              .withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          sourceLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.cyan,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                TiltHorizonIndicator(
                                  steering: tilt.steering,
                                  throttle: tilt.throttle,
                                  size: 112,
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _MetricPill(
                                      label: 'STEER',
                                      value:
                                          '${steerPct >= 0 ? '+' : ''}$steerPct%',
                                      color: AppTheme.cyan,
                                    ),
                                    _MetricPill(
                                      label: 'THROT',
                                      value:
                                          '${throtPct >= 0 ? '+' : ''}$throtPct%',
                                      color: AppTheme.green,
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      tilt.calibrateCenter();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Center tilt reference calibrated!'),
                                          duration:
                                              Duration(milliseconds: 1100),
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.cyan,
                                      side: const BorderSide(
                                          color: AppTheme.cyan),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: const Icon(
                                        Icons.center_focus_strong_rounded,
                                        size: 15),
                                    label: const Text(
                                      'CALIBRATE ZERO',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final Color accentColor;
  final IconData icon;
  final List<String> highlights;
  final String ctaLabel;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.accentColor,
    required this.icon,
    required this.highlights,
    required this.ctaLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.45),
              width: 1.4,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withValues(alpha: 0.09),
                AppTheme.surface,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: accentColor,
                      ),
                    ),
                  ),
                  Icon(icon, color: accentColor, size: 28),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  height: 1.3,
                ),
              ),
              const Spacer(),
              ...highlights.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 13, color: accentColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ctaLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: Color(0xFF061018),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Color(0xFF061018),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTheme.monoTelemetry.copyWith(fontSize: 13, color: color),
        ),
      ],
    );
  }
}
