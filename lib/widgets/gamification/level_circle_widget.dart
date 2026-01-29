import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'lottie_celebration_widget.dart';

class LevelCircleWidget extends StatefulWidget {
  final Map<String, dynamic>? gamification;
  final double size;

  const LevelCircleWidget({super.key, this.gamification, this.size = 140});

  @override
  State<LevelCircleWidget> createState() => _LevelCircleWidgetState();
}

class _LevelCircleWidgetState extends State<LevelCircleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get level => widget.gamification?['level'] ?? 1;
  int get points => widget.gamification?['points'] ?? 0;

  // Calculate points needed for next level (exponential growth)
  int get pointsForNextLevel =>
      (level * 200 * math.pow(1.15, level - 1)).round();
  int get pointsForCurrentLevel =>
      level > 1 ? ((level - 1) * 200 * math.pow(1.15, level - 2)).round() : 0;

  double get progress {
    if (level == 1 && points == 0) return 0;
    final currentLevelPoints = points - pointsForCurrentLevel;
    final pointsNeeded = pointsForNextLevel - pointsForCurrentLevel;
    return (currentLevelPoints / pointsNeeded).clamp(0.0, 1.0);
  }

  Color get levelColor {
    if (level <= 5) return const Color(0xFF4A90E2);
    if (level <= 10) return const Color(0xFF9B59B6);
    if (level <= 15) return const Color(0xFFF39C12);
    return const Color(0xFFE91E63);
  }

  Color get levelColorDark {
    if (level <= 5) return const Color(0xFF357ABD);
    if (level <= 10) return const Color(0xFF8E44AD);
    if (level <= 15) return const Color(0xFFE67E22);
    return const Color(0xFFC2185B);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        showCelebration(
          context,
          type: 'levelup',
          title: 'Nivel $level',
          subtitle:
              '${pointsForNextLevel - points} puntos para el nivel ${level + 1}',
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              levelColor.withOpacity(0.1),
              levelColorDark.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: levelColor.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NIVEL',
              style: theme.textTheme.labelSmall?.copyWith(
                color: levelColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background circle
                      CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: _CircleProgressPainter(
                          progress: 1.0,
                          color: levelColor.withOpacity(0.1),
                          strokeWidth: 12,
                        ),
                      ),
                      // Progress circle
                      CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: _CircleProgressPainter(
                          progress: progress * _progressAnimation.value,
                          color: levelColor,
                          strokeWidth: 12,
                        ),
                      ),
                      // Center content
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$level',
                            style: theme.textTheme.displayLarge?.copyWith(
                              color: levelColor,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$points pts',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: levelColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(levelColor),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).toStringAsFixed(0)}% al nivel ${level + 1}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
