import 'package:material_ui/material_ui.dart';

import '../services/tilt_control_service.dart';
import '../theme/app_theme.dart';

/// Persistent top telemetry settings bar with global Tilt Sensitivity slider,
/// Deadzone slider, and Control Inversion toggles.
class TopSettingsBar extends StatelessWidget {
  const TopSettingsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tilt = TiltControlService.instance;

    return ListenableBuilder(
      listenable: tilt,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.95),
            border: const Border(
              bottom: BorderSide(color: AppTheme.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Brand / System Title
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.cyan,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.cyan.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'APEX TILT',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'RC & ARCADE TELEMETRY',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: AppTheme.cyan,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Sensitivity Slider (0.5x to 2.0x)
              Expanded(
                flex: 3,
                child: _CompactSlider(
                  label: 'SENSITIVITY',
                  valueLabel: '${tilt.sensitivity.toStringAsFixed(2)}x',
                  value: tilt.sensitivity,
                  min: 0.5,
                  max: 2.0,
                  divisions: 30,
                  accentColor: AppTheme.cyan,
                  onChanged: tilt.setSensitivity,
                ),
              ),
              const SizedBox(width: 12),

              // Deadzone Slider (0% to 20%)
              Expanded(
                flex: 3,
                child: _CompactSlider(
                  label: 'DEADZONE',
                  valueLabel: '${(tilt.deadzone * 100).round()}%',
                  value: tilt.deadzone,
                  min: 0.0,
                  max: 0.20,
                  divisions: 20,
                  accentColor: AppTheme.amber,
                  onChanged: tilt.setDeadzone,
                ),
              ),
              const SizedBox(width: 12),

              // Control Inversion Toggles
              _InvertToggleChip(
                label: 'INV STEER',
                active: tilt.invertSteering,
                onTap: () => tilt.setInvertSteering(!tilt.invertSteering),
              ),
              const SizedBox(width: 6),
              _InvertToggleChip(
                label: 'INV THROT',
                active: tilt.invertThrottle,
                onTap: () => tilt.setInvertThrottle(!tilt.invertThrottle),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactSlider extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color accentColor;
  final ValueChanged<double> onChanged;

  const _CompactSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                valueLabel,
                style: AppTheme.monoTelemetry.copyWith(
                  fontSize: 11,
                  color: accentColor,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 20,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: accentColor,
                thumbColor: accentColor,
                overlayColor: accentColor.withValues(alpha: 0.16),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvertToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _InvertToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? AppTheme.purple.withValues(alpha: 0.22)
          : AppTheme.surfaceElevated,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppTheme.purple : AppTheme.border,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 14,
                color: active ? AppTheme.purple : AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
