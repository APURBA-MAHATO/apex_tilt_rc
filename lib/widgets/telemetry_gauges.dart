import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Futuristic visual steering wheel + tilt artificial horizon indicator.
class TiltHorizonIndicator extends StatelessWidget {
  final double steering; // -1.0 .. 1.0
  final double throttle; // -1.0 .. 1.0
  final bool emergencyStopped;
  final double size;

  const TiltHorizonIndicator({
    super.key,
    required this.steering,
    required this.throttle,
    this.emergencyStopped = false,
    this.size = 156,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HorizonPainter(
          steering: steering,
          throttle: throttle,
          emergencyStopped: emergencyStopped,
        ),
      ),
    );
  }
}

class _HorizonPainter extends CustomPainter {
  final double steering;
  final double throttle;
  final bool emergencyStopped;

  _HorizonPainter({
    required this.steering,
    required this.throttle,
    required this.emergencyStopped,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.44;
    final activeColor = emergencyStopped ? AppTheme.red : AppTheme.cyan;

    // Outer subtle glow ring
    final ringBg = Paint()
      ..color = AppTheme.surfaceElevated
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, ringBg);

    final ringBorder = Paint()
      ..color = activeColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, ringBorder);

    // Degree ticks around bezel
    final tickPaint = Paint()
      ..color = AppTheme.textSecondary.withValues(alpha: 0.45)
      ..strokeWidth = 1.4;
    for (var i = 0; i < 12; i++) {
      final angle = (i * math.pi / 6);
      final inner = radius - 6;
      final outer = radius;
      canvas.drawLine(
        Offset(center.dx + math.cos(angle) * inner,
            center.dy + math.sin(angle) * inner),
        Offset(center.dx + math.cos(angle) * outer,
            center.dy + math.sin(angle) * outer),
        tickPaint,
      );
    }

    // Crosshair axes
    final axisPaint = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx - radius + 8, center.dy),
      Offset(center.dx + radius - 8, center.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius + 8),
      Offset(center.dx, center.dy + radius - 8),
      axisPaint,
    );

    // Steering rotation angle (-55° .. +55°)
    final steerAngle = steering * (math.pi * 0.32);

    // Tilting horizon / steering bar
    canvas.save();
    canvas.translate(center.dx, center.dy - throttle * radius * 0.35);
    canvas.rotate(steerAngle);

    final horizonPaint = Paint()
      ..color = activeColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final barHalf = radius * 0.68;
    canvas.drawLine(
      Offset(-barHalf, 0),
      const Offset(-12, 0),
      horizonPaint,
    );
    canvas.drawLine(
      const Offset(12, 0),
      Offset(barHalf, 0),
      horizonPaint,
    );
    // Center wing chevron
    canvas.drawLine(const Offset(-12, 0), const Offset(0, -8), horizonPaint);
    canvas.drawLine(const Offset(0, -8), const Offset(12, 0), horizonPaint);
    canvas.restore();

    // Steering arc along top bezel
    if (steering.abs() > 0.02) {
      final arcPaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 3),
        -math.pi / 2,
        steering * (math.pi * 0.45),
        false,
        arcPaint,
      );
    }

    // Live vector dot
    final dotOffset = Offset(
      center.dx + steering * radius * 0.65,
      center.dy - throttle * radius * 0.65,
    );
    canvas.drawCircle(
      dotOffset,
      7,
      Paint()..color = activeColor.withValues(alpha: 0.3),
    );
    canvas.drawCircle(
      dotOffset,
      4,
      Paint()..color = activeColor,
    );
  }

  @override
  bool shouldRepaint(covariant _HorizonPainter oldDelegate) {
    return oldDelegate.steering != steering ||
        oldDelegate.throttle != throttle ||
        oldDelegate.emergencyStopped != emergencyStopped;
  }
}

/// Live bidirectional vertical throttle gauge (-100% reverse to +100% forward).
class ThrottleBar extends StatelessWidget {
  final double throttle;
  final bool emergencyStopped;
  final double height;
  final double width;

  const ThrottleBar({
    super.key,
    required this.throttle,
    this.emergencyStopped = false,
    this.height = 148,
    this.width = 34,
  });

  @override
  Widget build(BuildContext context) {
    final color = emergencyStopped
        ? AppTheme.red
        : (throttle >= 0 ? AppTheme.green : AppTheme.amber);
    final pct = (throttle * 100).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${pct >= 0 ? '+' : ''}$pct%',
          style: AppTheme.monoTelemetry.copyWith(fontSize: 11, color: color),
        ),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final halfH = constraints.maxHeight / 2;
              final fillH = (throttle.abs().clamp(0.0, 1.0)) * halfH;
              final isPositive = throttle >= 0;

              return Stack(
                children: [
                  // Center zero line
                  Positioned(
                    top: halfH - 1,
                    left: 0,
                    right: 0,
                    child: Container(height: 2, color: AppTheme.border),
                  ),
                  // Active fill bar
                  Positioned(
                    left: 2,
                    right: 2,
                    top: isPositive ? (halfH - fillH) : halfH,
                    height: fillH,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.45),
                            blurRadius: 8,
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
        const SizedBox(height: 4),
        const Text(
          'THROT',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
