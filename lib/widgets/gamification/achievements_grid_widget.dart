import 'package:flutter/material.dart';
import 'lottie_celebration_widget.dart';

class AchievementsGridWidget extends StatelessWidget {
  final Map<String, dynamic>? gamification;

  const AchievementsGridWidget({super.key, this.gamification});

  int get level => gamification?['level'] ?? 1;
  int get currentStreak => gamification?['currentStreak'] ?? 0;
  int get points => gamification?['points'] ?? 0;

  List<dynamic> get history => gamification?['history'] ?? [];

  List<Achievement> get achievements {
    return [
      Achievement(
        id: 'first_workout',
        title: 'Primer Entrenamiento',
        description: 'Completa tu primer entrenamiento',
        icon: Icons.fitness_center,
        color: const Color(0xFF4CAF50),
        isUnlocked: history.any((h) => h['action'] == 'WORKOUT'),
      ),
      Achievement(
        id: 'streak_7',
        title: 'Racha de 7 Días',
        description: 'Mantén una racha de 7 días consecutivos',
        icon: Icons.local_fire_department,
        color: const Color(0xFFFF9800),
        isUnlocked: currentStreak >= 7,
        progress: currentStreak / 7,
      ),
      Achievement(
        id: 'streak_30',
        title: 'Racha de 30 Días',
        description: 'Mantén una racha de 30 días consecutivos',
        icon: Icons.whatshot,
        color: const Color(0xFFF44336),
        isUnlocked: currentStreak >= 30,
        progress: currentStreak / 30,
      ),
      Achievement(
        id: 'level_5',
        title: 'Nivel 5',
        description: 'Alcanza el nivel 5',
        icon: Icons.star,
        color: const Color(0xFF2196F3),
        isUnlocked: level >= 5,
        progress: level / 5,
      ),
      Achievement(
        id: 'level_10',
        title: 'Nivel 10',
        description: 'Alcanza el nivel 10',
        icon: Icons.stars,
        color: const Color(0xFF9C27B0),
        isUnlocked: level >= 10,
        progress: level / 10,
      ),
      Achievement(
        id: 'points_1000',
        title: '1000 Puntos',
        description: 'Acumula 1000 puntos totales',
        icon: Icons.emoji_events,
        color: const Color(0xFFFFC107),
        isUnlocked: points >= 1000,
        progress: points / 1000,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LOGROS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$unlockedCount/${achievements.length}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      size: 16,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${((unlockedCount / achievements.length) * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              return _AchievementTile(achievement: achievements[index]);
            },
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;

  const _AchievementTile({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  achievement.icon,
                  color: achievement.isUnlocked
                      ? achievement.color
                      : theme.hintColor.withOpacity(0.3),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    achievement.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(achievement.description),
                if (!achievement.isUnlocked &&
                    achievement.progress != null) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: achievement.progress!.clamp(0.0, 1.0),
                    backgroundColor: theme.hintColor.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(achievement.color),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(achievement.progress! * 100).clamp(0, 100).toStringAsFixed(0)}% completado',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (achievement.isUnlocked)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showCelebration(
                      context,
                      type: 'achievement',
                      title: achievement.title,
                      subtitle: '¡Logro Desbloqueado!',
                    );
                  },
                  icon: const Icon(Icons.celebration, color: Colors.orange),
                  label: const Text(
                    'Celebrar',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: achievement.isUnlocked
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    achievement.color.withOpacity(0.2),
                    achievement.color.withOpacity(0.1),
                  ],
                )
              : null,
          color: achievement.isUnlocked
              ? null
              : theme.hintColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: achievement.isUnlocked
                ? achievement.color.withOpacity(0.3)
                : theme.hintColor.withOpacity(0.1),
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                achievement.icon,
                size: 40,
                color: achievement.isUnlocked
                    ? achievement.color
                    : theme.hintColor.withOpacity(0.3),
              ),
            ),
            if (!achievement.isUnlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        theme.cardTheme.color?.withOpacity(0.7) ??
                        Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock_outline,
                      size: 24,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            if (!achievement.isUnlocked && achievement.progress != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    color: theme.hintColor.withOpacity(0.1),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: achievement.progress!.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                        color: achievement.color,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;
  final double? progress;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isUnlocked,
    this.progress,
  });
}
