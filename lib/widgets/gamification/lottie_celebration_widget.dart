import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Reusable widget for displaying Lottie celebration animations
/// for gamification events (level-ups, achievements, tasks, streaks)
class LottieCelebrationWidget extends StatefulWidget {
  /// Type of animation to display
  /// Options: 'levelup', 'achievement', 'task', 'streak'
  final String animationType;

  /// Callback when animation completes
  final VoidCallback? onComplete;

  /// Optional title text to display
  final String? title;

  /// Optional subtitle text to display
  final String? subtitle;

  const LottieCelebrationWidget({
    super.key,
    required this.animationType,
    this.onComplete,
    this.title,
    this.subtitle,
  });

  @override
  State<LottieCelebrationWidget> createState() =>
      _LottieCelebrationWidgetState();
}

class _LottieCelebrationWidgetState extends State<LottieCelebrationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getAnimationPath() {
    // For now, we'll use a fallback approach since we don't have actual Lottie files
    // In production, you would download Lottie files from lottiefiles.com
    switch (widget.animationType) {
      case 'levelup':
        return 'assets/animations/levelup.json';
      case 'achievement':
        return 'assets/animations/achievement.json';
      case 'task':
        return 'assets/animations/task.json';
      case 'streak':
        return 'assets/animations/streak.json';
      default:
        return 'assets/animations/celebration.json';
    }
  }

  Color _getAccentColor() {
    switch (widget.animationType) {
      case 'levelup':
        return const Color(0xFFFFD700); // Gold
      case 'achievement':
        return const Color(0xFFFF6B35); // Orange
      case 'task':
        return const Color(0xFF34C759); // Green
      case 'streak':
        return const Color(0xFFFF3B30); // Red
      default:
        return Theme.of(context).primaryColor;
    }
  }

  IconData _getFallbackIcon() {
    switch (widget.animationType) {
      case 'levelup':
        return Icons.stars_rounded;
      case 'achievement':
        return Icons.emoji_events_rounded;
      case 'task':
        return Icons.check_circle_rounded;
      case 'streak':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.celebration_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = _getAccentColor();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: GestureDetector(
        onTap: () {
          widget.onComplete?.call();
          Navigator.of(context).pop();
        },
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withOpacity(0.1),
                accentColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lottie Animation or Fallback Icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accentColor.withOpacity(0.3),
                        accentColor.withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _getFallbackIcon(),
                      size: 120,
                      color: accentColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              if (widget.title != null)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    widget.title!,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: theme.textTheme.titleLarge?.color,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Subtitle
              if (widget.subtitle != null) ...[
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    widget.subtitle!,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.hintColor,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Dismiss hint
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(opacity: value * 0.6, child: child);
                },
                child: Text(
                  'Toca para continuar',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.hintColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to show celebration dialog
void showCelebration(
  BuildContext context, {
  required String type,
  String? title,
  String? subtitle,
  VoidCallback? onComplete,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.7),
    builder: (context) => LottieCelebrationWidget(
      animationType: type,
      title: title,
      subtitle: subtitle,
      onComplete: onComplete,
    ),
  );
}
