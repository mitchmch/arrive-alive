import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../services/location_service.dart';

/// Modern speedometer widget inspired by Waze + Kids360.
/// Features:
/// - Glassmorphic floating card design
/// - Circular gauge with colored zones (green/amber/red)
/// - Large bold speed number
/// - Speed limit badge that pulses red when over limit
/// - Status text ("Stationary", "Safe speed", "OVER LIMIT")
/// - Glow effect on violations
class SpeedometerWidget extends StatelessWidget {
  final double speed;
  final double speedLimit;
  final bool isViolating;
  final double size;
  final bool compact;
  final bool isMoving;

  const SpeedometerWidget({
    super.key,
    required this.speed,
    required this.speedLimit,
    required this.isViolating,
    this.size = 180,
    this.compact = false,
    this.isMoving = false,
  });

  @override
  Widget build(BuildContext context) {
    final speedColor = _getSpeedColor();
    // Motion guard: show 0 when not moving
    final effectiveSpeed =
        (isMoving && speed >= LocationService.motionThresholdKmh) ? speed : 0.0;
    final speedText = effectiveSpeed.toStringAsFixed(0);

    if (compact) {
      // Compact version for bottom sheet
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mini gauge
          SizedBox(
            width: 48,
            height: 48,
            child: CustomPaint(
              size: const Size(48, 48),
              painter: _ModernGaugePainter(
                progress: (effectiveSpeed / (speedLimit * 1.5)).clamp(0.0, 1.0),
                color: speedColor,
                isViolating: isViolating,
                strokeWidth: 4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            speedText,
            style: GoogleFonts.dmSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: speedColor,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            'km/h',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    // Full glassmorphic speedometer card
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0x991C1B19)
            : const Color(0x99FFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isViolating
              ? AppTheme.destructive.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isViolating
                ? AppTheme.destructive.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.16),
            blurRadius: isViolating ? 20 : 12,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Gauge with colored zones
            CustomPaint(
              size: Size(size, size),
              painter: _ModernGaugePainter(
                progress: (effectiveSpeed / (speedLimit * 1.5)).clamp(0.0, 1.0),
                color: speedColor,
                isViolating: isViolating,
                strokeWidth: 10,
                showZones: true,
                speedLimit: speedLimit,
                maxScale: speedLimit * 1.5,
              ),
            ),
            // Center content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  speedText,
                  style: GoogleFonts.dmSans(
                    fontSize: size * 0.27,
                    fontWeight: FontWeight.w800,
                    color: speedColor,
                    letterSpacing: -2,
                    height: 1,
                  ),
                ),
                Text(
                  'km/h',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                // Status text
                Text(
                  _getStatusText(),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText() {
    if (!isMoving || speed < LocationService.motionThresholdKmh) {
      return 'Stationary';
    }
    if (isViolating) return 'OVER LIMIT';
    if (speed > speedLimit * 0.85) return 'Approaching limit';
    return 'Safe speed';
  }

  Color _getStatusColor() {
    if (!isMoving || speed < LocationService.motionThresholdKmh) {
      return AppTheme.textMuted;
    }
    if (isViolating) return AppTheme.destructive;
    if (speed > speedLimit * 0.85) return AppTheme.warning;
    return AppTheme.success;
  }

  Color _getSpeedColor() {
    // Motion guard: if not moving, show muted color
    if (!isMoving || speed < LocationService.motionThresholdKmh) {
      return AppTheme.textMuted;
    }
    if (isViolating) return AppTheme.destructive;
    if (speed > speedLimit * 0.85) return AppTheme.warning;
    return AppTheme.success;
  }
}

/// Modern gauge painter with colored zones, glow effect, and animated needle.
class _ModernGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isViolating;
  final double strokeWidth;
  final bool showZones;
  final double? speedLimit;
  final double? maxScale;

  _ModernGaugePainter({
    required this.progress,
    required this.color,
    required this.isViolating,
    this.strokeWidth = 10,
    this.showZones = false,
    this.speedLimit,
    this.maxScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;
    // 240 degree arc: from -210° to 30° (in radians: from 5π/6 to π/6 going clockwise)
    // In Flutter canvas, angles are measured from positive x-axis, clockwise
    const startAngle = -210 * math.pi / 180; // -210 degrees
    const sweepAngle = 240 * math.pi / 180; // 240 degrees
    final progressSweep = sweepAngle * progress;

    // 1. Background track
    final bgPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // 2. Color zones (only for full gauge)
    if (showZones && speedLimit != null && maxScale != null) {
      final limitFraction = speedLimit! / maxScale!;
      final greenEnd = startAngle + sweepAngle * (limitFraction * 0.85);
      final amberEnd = startAngle + sweepAngle * limitFraction;

      // Green zone
      final greenPaint = Paint()
        ..color = AppTheme.success.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        greenEnd - startAngle,
        false,
        greenPaint,
      );

      // Amber zone
      final amberPaint = Paint()
        ..color = AppTheme.warning.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        greenEnd,
        amberEnd - greenEnd,
        false,
        amberPaint,
      );

      // Red zone
      final redPaint = Paint()
        ..color = AppTheme.destructive.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        amberEnd,
        (startAngle + sweepAngle) - amberEnd,
        false,
        redPaint,
      );
    }

    // 3. Filled progress arc
    if (progress > 0.01) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        progressSweep,
        false,
        progressPaint,
      );

      // Glow effect
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        progressSweep,
        false,
        glowPaint,
      );
    }

    // 4. Needle
    final needleAngle = startAngle + progressSweep;
    final needleEnd = Offset(
      center.dx + (radius - 4) * math.cos(needleAngle),
      center.dy + (radius - 4) * math.sin(needleAngle),
    );
    final needlePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth * 0.35
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);

    // 5. Center hub
    final hubPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, strokeWidth * 0.6, hubPaint);

    final hubInnerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, strokeWidth * 0.35, hubInnerPaint);

    // 6. Violation pulse ring
    if (isViolating) {
      final pulsePaint = Paint()
        ..color = AppTheme.destructive.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius + 4, pulsePaint);
      canvas.drawCircle(
        center,
        radius + 8,
        Paint()
          ..color = AppTheme.destructive.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_ModernGaugePainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.isViolating != isViolating;
}
