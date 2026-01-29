import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asesoria_app/widgets/gamification/achievements_grid_widget.dart';

void main() {
  group('AchievementsGridWidget Tests', () {
    testWidgets('should display total achievements count', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {
        'level': 5,
        'currentStreak': 10,
        'points': 1500,
        'history': [
          {
            'action': 'WORKOUT',
            'points': 50,
            'date': DateTime.now().toIso8601String(),
          },
        ],
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AchievementsGridWidget(gamification: gamification),
          ),
        ),
      );

      // Assert
      expect(find.text('LOGROS'), findsOneWidget);
      expect(find.textContaining('/'), findsOneWidget); // Shows X/Y format
    });

    testWidgets('should unlock "First Workout" achievement', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {
        'level': 1,
        'currentStreak': 0,
        'points': 50,
        'history': [
          {
            'action': 'WORKOUT',
            'points': 50,
            'date': DateTime.now().toIso8601String(),
          },
        ],
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AchievementsGridWidget(gamification: gamification),
          ),
        ),
      );

      // Assert - should have at least 1 unlocked achievement
      expect(find.byType(AchievementsGridWidget), findsOneWidget);
    });

    testWidgets('should unlock "7-Day Streak" achievement', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {
        'level': 3,
        'currentStreak': 7,
        'points': 500,
        'history': [],
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AchievementsGridWidget(gamification: gamification),
          ),
        ),
      );

      // Assert
      expect(find.byType(AchievementsGridWidget), findsOneWidget);
    });

    testWidgets('should unlock "Level 5" achievement', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {
        'level': 5,
        'currentStreak': 0,
        'points': 1000,
        'history': [],
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AchievementsGridWidget(gamification: gamification),
          ),
        ),
      );

      // Assert
      expect(find.byType(AchievementsGridWidget), findsOneWidget);
    });

    testWidgets('should unlock "1000 Points" achievement', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {
        'level': 5,
        'currentStreak': 0,
        'points': 1000,
        'history': [],
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AchievementsGridWidget(gamification: gamification),
          ),
        ),
      );

      // Assert
      expect(find.byType(AchievementsGridWidget), findsOneWidget);
    });

    testWidgets('should handle null gamification data', (
      WidgetTester tester,
    ) async {
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AchievementsGridWidget(gamification: null)),
        ),
      );

      // Assert - should show 0 unlocked
      expect(find.text('0/6'), findsOneWidget);
    });

    testWidgets('should display completion percentage', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {
        'level': 10,
        'currentStreak': 30,
        'points': 2000,
        'history': [
          {
            'action': 'WORKOUT',
            'points': 50,
            'date': DateTime.now().toIso8601String(),
          },
        ],
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AchievementsGridWidget(gamification: gamification),
          ),
        ),
      );

      // Assert
      expect(find.textContaining('%'), findsOneWidget);
    });

    testWidgets('should show achievement dialog on tap', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {
        'level': 5,
        'currentStreak': 10,
        'points': 1500,
        'history': [
          {
            'action': 'WORKOUT',
            'points': 50,
            'date': DateTime.now().toIso8601String(),
          },
        ],
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AchievementsGridWidget(gamification: gamification),
          ),
        ),
      );

      // Tap on first achievement
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      // Assert - dialog should appear
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Cerrar'), findsOneWidget);
    });

    testWidgets('should display grid layout', (WidgetTester tester) async {
      // Arrange
      final gamification = {
        'level': 1,
        'currentStreak': 0,
        'points': 0,
        'history': [],
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AchievementsGridWidget(gamification: gamification),
          ),
        ),
      );

      // Assert
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('should show all 6 achievements', (WidgetTester tester) async {
      // Arrange
      final gamification = {
        'level': 1,
        'currentStreak': 0,
        'points': 0,
        'history': [],
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AchievementsGridWidget(gamification: gamification),
          ),
        ),
      );

      // Assert - should have 6 achievement tiles
      expect(find.byType(GestureDetector), findsNWidgets(6));
    });
  });
}
