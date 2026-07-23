import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SemiCircleProgressIndicator extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final String label;
  final String? subLabel;
  final int? speed;

  const SemiCircleProgressIndicator({
    super.key,
    required this.progress,
    this.size = 220,
    required this.label,
    this.subLabel,
    this.speed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size / 2 + 10, // Reduced space
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: size / 2,
                child: CustomPaint(
                  painter: _SemiCirclePainter(
                    progress: progress,
                    color: AppTheme.cyberCyan,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(progress * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: size * 0.16, // Proportional font size
                          fontWeight: FontWeight.w900,
                          color: AppTheme.cyberCyan,
                          height: 1.0,
                        ),
                      ),
                      if (speed != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$speed MB/s',
                          style: TextStyle(
                            fontSize: size * 0.07, // Proportional font size
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.cyberCyan,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
          textAlign: TextAlign.center,
        ),
        if (subLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            subLabel!,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _SemiCirclePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _SemiCirclePainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;
    const strokeWidth = 16.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Background arc (semi-circle from 180 to 360 degrees)
    canvas.drawArc(
      rect,
      math.pi, // Start from 9 o'clock
      math.pi, // Sweep 180 degrees
      false,
      bgPaint,
    );

    // Progress arc
    canvas.drawArc(
      rect,
      math.pi,
      math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawArc(
      rect,
      math.pi,
      math.pi * progress.clamp(0.0, 1.0),
      false,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SemiCirclePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
