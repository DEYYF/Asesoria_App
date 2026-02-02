import 'package:flutter/material.dart';

class MuscleHeatmapWidget extends StatelessWidget {
  final Map<String, double> muscleIntensity; // 0.0 to 1.0
  final bool showFront;

  const MuscleHeatmapWidget({
    super.key,
    required this.muscleIntensity,
    this.showFront = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 300,
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: CustomPaint(
        painter: _BodyPainter(
          intensity: muscleIntensity,
          showFront: showFront,
          primaryColor: theme.primaryColor,
          isDark: theme.brightness == Brightness.dark,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  final Map<String, double> intensity;
  final bool showFront;
  final Color primaryColor;
  final bool isDark;

  _BodyPainter({
    required this.intensity,
    required this.showFront,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    // Draw Head
    _drawMuscle(
      canvas,
      size,
      'Cabeza',
      _getMusclePath(size, 'head'),
      baseColor,
      paint,
    );

    if (showFront) {
      _drawMuscle(
        canvas,
        size,
        'Pecho',
        _getMusclePath(size, 'chest'),
        baseColor,
        paint,
      );
      _drawMuscle(
        canvas,
        size,
        'Abdominales',
        _getMusclePath(size, 'abs'),
        baseColor,
        paint,
      );
      _drawMuscle(
        canvas,
        size,
        'Cuádriceps',
        _getMusclePath(size, 'quads'),
        baseColor,
        paint,
      );
      _drawMuscle(
        canvas,
        size,
        'Bíceps',
        _getMusclePath(size, 'biceps'),
        baseColor,
        paint,
      );
      _drawMuscle(
        canvas,
        size,
        'Hombros',
        _getMusclePath(size, 'shoulders_front'),
        baseColor,
        paint,
      );
    } else {
      _drawMuscle(
        canvas,
        size,
        'Espalda',
        _getMusclePath(size, 'back'),
        baseColor,
        paint,
      );
      _drawMuscle(
        canvas,
        size,
        'Glúteos',
        _getMusclePath(size, 'glutes'),
        baseColor,
        paint,
      );
      _drawMuscle(
        canvas,
        size,
        'Isquios',
        _getMusclePath(size, 'hamstrings'),
        baseColor,
        paint,
      );
      _drawMuscle(
        canvas,
        size,
        'Tríceps',
        _getMusclePath(size, 'triceps'),
        baseColor,
        paint,
      );
      _drawMuscle(
        canvas,
        size,
        'Hombros',
        _getMusclePath(size, 'shoulders_back'),
        baseColor,
        paint,
      );
      _drawMuscle(
        canvas,
        size,
        'Gemelos',
        _getMusclePath(size, 'calves'),
        baseColor,
        paint,
      );
    }
  }

  void _drawMuscle(
    Canvas canvas,
    Size size,
    String muscleName,
    Path path,
    Color baseColor,
    Paint paint,
  ) {
    double val = intensity[muscleName] ?? 0.0;
    // Glow effect for high intensity
    if (val > 0.1) {
      final glowPaint = Paint()
        ..color = primaryColor.withOpacity(val * 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * val);
      canvas.drawPath(path, glowPaint);
    }

    paint.color = Color.lerp(baseColor, primaryColor, val)!;
    canvas.drawPath(path, paint);

    // Subtle outline
    final outlinePaint = Paint()
      ..color = isDark
          ? Colors.white.withOpacity(0.1)
          : Colors.black.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawPath(path, outlinePaint);
  }

  Path _getMusclePath(Size size, String muscle) {
    final w = size.width;
    final h = size.height;
    final center = w / 2;

    switch (muscle) {
      case 'head':
        return Path()..addOval(
          Rect.fromCenter(
            center: Offset(center, h * 0.1),
            width: w * 0.2,
            height: h * 0.15,
          ),
        );
      case 'chest':
        return Path()
          ..moveTo(center - w * 0.2, h * 0.2)
          ..lineTo(center + w * 0.2, h * 0.2)
          ..lineTo(center + w * 0.18, h * 0.35)
          ..lineTo(center - w * 0.18, h * 0.35)
          ..close();
      case 'abs':
        return Path()
          ..moveTo(center - w * 0.15, h * 0.36)
          ..lineTo(center + w * 0.15, h * 0.36)
          ..lineTo(center + w * 0.12, h * 0.55)
          ..lineTo(center - w * 0.12, h * 0.55)
          ..close();
      case 'quads':
        final left = Path()
          ..moveTo(center - w * 0.12, h * 0.56)
          ..lineTo(center - w * 0.02, h * 0.56)
          ..lineTo(center - w * 0.05, h * 0.75)
          ..lineTo(center - w * 0.2, h * 0.75)
          ..close();
        final right = Path()
          ..moveTo(center + w * 0.02, h * 0.56)
          ..lineTo(center + w * 0.12, h * 0.56)
          ..lineTo(center + w * 0.2, h * 0.75)
          ..lineTo(center + w * 0.05, h * 0.75)
          ..close();
        return Path.combine(PathOperation.union, left, right);
      case 'biceps':
        final left = Path()
          ..addOval(
            Rect.fromLTWH(center - w * 0.35, h * 0.22, w * 0.1, h * 0.12),
          );
        final right = Path()
          ..addOval(
            Rect.fromLTWH(center + w * 0.25, h * 0.22, w * 0.1, h * 0.12),
          );
        return Path.combine(PathOperation.union, left, right);
      case 'shoulders_front':
      case 'shoulders_back':
        final left = Path()
          ..addOval(
            Rect.fromLTWH(center - w * 0.3, h * 0.18, w * 0.12, h * 0.08),
          );
        final right = Path()
          ..addOval(
            Rect.fromLTWH(center + w * 0.18, h * 0.18, w * 0.12, h * 0.08),
          );
        return Path.combine(PathOperation.union, left, right);
      case 'back':
        return Path()
          ..moveTo(center - w * 0.25, h * 0.2)
          ..lineTo(center + w * 0.25, h * 0.2)
          ..lineTo(center + w * 0.15, h * 0.5)
          ..lineTo(center - w * 0.15, h * 0.5)
          ..close();
      case 'glutes':
        return Path()
          ..moveTo(center - w * 0.2, h * 0.51)
          ..lineTo(center + w * 0.2, h * 0.51)
          ..lineTo(center + w * 0.18, h * 0.6)
          ..lineTo(center - w * 0.18, h * 0.6)
          ..close();
      case 'hamstrings':
        final left = Path()
          ..moveTo(center - w * 0.18, h * 0.61)
          ..lineTo(center - w * 0.02, h * 0.61)
          ..lineTo(center - w * 0.05, h * 0.78)
          ..lineTo(center - w * 0.15, h * 0.78)
          ..close();
        final right = Path()
          ..moveTo(center + w * 0.02, h * 0.61)
          ..lineTo(center + w * 0.18, h * 0.61)
          ..lineTo(center + w * 0.15, h * 0.78)
          ..lineTo(center + w * 0.05, h * 0.78)
          ..close();
        return Path.combine(PathOperation.union, left, right);
      case 'triceps':
        final left = Path()
          ..addOval(
            Rect.fromLTWH(center - w * 0.35, h * 0.25, w * 0.08, h * 0.15),
          );
        final right = Path()
          ..addOval(
            Rect.fromLTWH(center + w * 0.27, h * 0.25, w * 0.08, h * 0.15),
          );
        return Path.combine(PathOperation.union, left, right);
      case 'calves':
        final left = Path()
          ..addOval(
            Rect.fromLTWH(center - w * 0.18, h * 0.8, w * 0.1, h * 0.12),
          );
        final right = Path()
          ..addOval(
            Rect.fromLTWH(center + w * 0.08, h * 0.8, w * 0.1, h * 0.12),
          );
        return Path.combine(PathOperation.union, left, right);
      default:
        return Path();
    }
  }

  @override
  bool shouldRepaint(covariant _BodyPainter oldDelegate) {
    return oldDelegate.intensity != intensity ||
        oldDelegate.showFront != showFront;
  }
}
