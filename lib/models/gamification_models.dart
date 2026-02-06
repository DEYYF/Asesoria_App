class GamificationStats {
  final int currentStreak;
  final int longestStreak;
  final int level;
  final int currentXP;
  final int xpToNextLevel;
  final int xpInCurrentLevel;
  final int xpNeededForLevel;
  final int totalHabitsCompleted;
  final TrendAnalysis trend;

  GamificationStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.level,
    required this.currentXP,
    required this.xpToNextLevel,
    required this.xpInCurrentLevel,
    required this.xpNeededForLevel,
    required this.totalHabitsCompleted,
    required this.trend,
  });

  factory GamificationStats.fromJson(Map<String, dynamic> json) {
    return GamificationStats(
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      level: json['level'] ?? 1,
      currentXP: json['currentXP'] ?? 0,
      xpToNextLevel: json['xpToNextLevel'] ?? 0,
      xpInCurrentLevel: json['xpInCurrentLevel'] ?? 0,
      xpNeededForLevel: json['xpNeededForLevel'] ?? 100,
      totalHabitsCompleted: json['totalHabitsCompleted'] ?? 0,
      trend: TrendAnalysis.fromJson(json['trend'] ?? {}),
    );
  }
}

class TrendAnalysis {
  final int percentageChange;
  final String message;
  final int currentMonthCompleted;
  final int previousMonthCompleted;

  TrendAnalysis({
    required this.percentageChange,
    required this.message,
    required this.currentMonthCompleted,
    required this.previousMonthCompleted,
  });

  factory TrendAnalysis.fromJson(Map<String, dynamic> json) {
    return TrendAnalysis(
      percentageChange: json['percentageChange'] ?? 0,
      message: json['message'] ?? '',
      currentMonthCompleted: json['currentMonthCompleted'] ?? 0,
      previousMonthCompleted: json['previousMonthCompleted'] ?? 0,
    );
  }
}

class BadgeModel {
  final String badgeType;
  final String title;
  final String description;
  final String icon;
  final String category;
  final bool isLocked;
  final DateTime? unlockedAt;
  final double progress;
  final double progressMax;

  BadgeModel({
    required this.badgeType,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.isLocked,
    this.unlockedAt,
    required this.progress,
    required this.progressMax,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      badgeType: json['badgeType'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      category: json['category'] ?? '',
      isLocked: json['isLocked'] ?? true,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'])
          : null,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      progressMax: (json['progressMax'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class ChallengeModel {
  final String id;
  final String title;
  final String? description;
  final String? targetHabitId;
  final String targetType;
  final int targetValue;
  final DateTime startDate;
  final DateTime endDate;
  final int xpReward;
  final bool completed;
  final DateTime? completedAt;
  final double progress;
  final int progressPercentage;
  final Map<String, dynamic>? targetHabit;

  ChallengeModel({
    required this.id,
    required this.title,
    this.description,
    this.targetHabitId,
    required this.targetType,
    required this.targetValue,
    required this.startDate,
    required this.endDate,
    required this.xpReward,
    required this.completed,
    this.completedAt,
    required this.progress,
    required this.progressPercentage,
    this.targetHabit,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    return ChallengeModel(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      targetHabitId: json['targetHabitId'] is Map
          ? json['targetHabitId']['_id']
          : json['targetHabitId'],
      targetType: json['targetType'] ?? 'days_completed',
      targetValue: json['targetValue'] ?? 0,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'])
          : DateTime.now(),
      xpReward: json['xpReward'] ?? 0,
      completed: json['completed'] ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      progressPercentage: json['progressPercentage'] ?? 0,
      targetHabit: json['targetHabitId'] is Map ? json['targetHabitId'] : null,
    );
  }
}
