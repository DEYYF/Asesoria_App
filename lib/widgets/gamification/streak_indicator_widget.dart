import 'package:flutter/material.dart';
import 'lottie_celebration_widget.dart';

class StreakIndicatorWidget extends StatefulWidget {
  final Map<String, dynamic>? gamification;

  const StreakIndicatorWidget({super.key, this.gamification});

  @override
  State<StreakIndicatorWidget> createState() => _StreakIndicatorWidgetState();
}

class _StreakIndicatorWidgetState extends State<StreakIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  int get currentStreak => widget.gamification?['currentStreak'] ?? 0;

  bool get isActive {
    final lastActivity = widget.gamification?['lastActivityDate'];
    if (lastActivity == null) return false;
    final lastDate = DateTime.parse(lastActivity.toString());
    final daysSince = DateTime.now().difference(lastDate).inDays;
    return daysSince <= 1;
  }

  Color get streakColor {
    if (!isActive || currentStreak == 0) return Colors.grey;
    if (currentStreak < 7) return const Color(0xFFFF9800); // Orange
    if (currentStreak < 14) return const Color(0xFFF44336); // Red
    return const Color(0xFF9C27B0); // Purple
  }

  String get streakEmoji {
    if (!isActive || currentStreak == 0) return '💤';
    if (currentStreak < 7) return '🔥';
    if (currentStreak < 14) return '🔥🔥';
    return '🔥🔥🔥';
  }

  String get streakLabel {
    if (!isActive || currentStreak == 0) return 'Sin racha activa';
    if (currentStreak < 7) return 'Racha activa';
    if (currentStreak < 14) return '¡Racha caliente!';
    return '¡EN LLAMAS!';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        if (currentStreak > 0) {
          showCelebration(
            context,
            type: 'streak',
            title: '$currentStreak Días',
            subtitle: '¡Sigue así! Tu racha está ${streakLabel.toLowerCase()}',
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              streakColor.withOpacity(0.1),
              streakColor.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: streakColor.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'RACHA',
              style: theme.textTheme.labelSmall?.copyWith(
                color: streakColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            if (isActive && currentStreak > 0)
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  );
                },
                child: Text(streakEmoji, style: const TextStyle(fontSize: 48)),
              )
            else
              Text(streakEmoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              '$currentStreak',
              style: theme.textTheme.displayMedium?.copyWith(
                color: streakColor,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              currentStreak == 1 ? 'día' : 'días',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: streakColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                streakLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: streakColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!isActive && currentStreak == 0) ...[
              const SizedBox(height: 8),
              Text(
                'Completa una actividad\npara iniciar tu racha',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
