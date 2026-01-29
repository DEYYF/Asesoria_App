import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asesoria_app/widgets/gamification/streak_indicator_widget.dart';

void main() {
  group('StreakIndicatorWidget Tests', () {
    testWidgets('should display current streak days', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {
        'currentStreak': 15,
        'lastActivityDate': DateTime.now().toIso8601String(),
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicatorWidget(gamification: gamification),
          ),
        ),
      );

      // Assert
      expect(find.text('15'), findsOneWidget);
      expect(find.text('días'), findsOneWidget);
      expect(find.text('RACHA'), findsOneWidget);
    });

    testWidgets('should show fire emoji for active streak', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {
        'currentStreak': 5,
        'lastActivityDate': DateTime.now().toIso8601String(),
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicatorWidget(gamification: gamification),
          ),
        ),
      );

      // Assert
      expect(find.text('🔥'), findsOneWidget);
    });

    testWidgets('should show sleep emoji for inactive streak', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {
        'currentStreak': 0,
        'lastActivityDate': DateTime.now()
            .subtract(const Duration(days: 10))
            .toIso8601String(),
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicatorWidget(gamification: gamification),
          ),
        ),
      );

      // Assert
      expect(find.text('💤'), findsOneWidget);
      expect(find.text('Sin racha activa'), findsOneWidget);
    });

    testWidgets('should show multiple fire emojis for long streaks', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {
        'currentStreak': 20,
        'lastActivityDate': DateTime.now().toIso8601String(),
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicatorWidget(gamification: gamification),
          ),
        ),
      );

      // Assert
      expect(find.text('🔥🔥🔥'), findsOneWidget);
      expect(find.text('¡EN LLAMAS!'), findsOneWidget);
    });

    testWidgets('should handle null gamification data', (
      WidgetTester tester,
    ) async {
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StreakIndicatorWidget(gamification: null)),
        ),
      );

      // Assert - should default to 0 streak
      expect(find.text('0'), findsOneWidget);
      expect(find.text('💤'), findsOneWidget);
    });

    testWidgets('should display singular "día" for 1-day streak', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {
        'currentStreak': 1,
        'lastActivityDate': DateTime.now().toIso8601String(),
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicatorWidget(gamification: gamification),
          ),
        ),
      );

      // Assert
      expect(find.text('día'), findsOneWidget);
    });

    testWidgets('should show motivational message for inactive users', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {'currentStreak': 0, 'lastActivityDate': null};

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicatorWidget(gamification: gamification),
          ),
        ),
      );

      // Assert
      expect(find.textContaining('Completa una actividad'), findsOneWidget);
    });

    testWidgets('should animate pulse for active streaks', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {
        'currentStreak': 10,
        'lastActivityDate': DateTime.now().toIso8601String(),
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicatorWidget(gamification: gamification),
          ),
        ),
      );

      // Initial frame
      await tester.pump();

      // Animation frames
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pump(const Duration(milliseconds: 750));

      // Assert - widget should still be present after animation
      expect(find.byType(StreakIndicatorWidget), findsOneWidget);
    });

    testWidgets('should treat yesterday as active', (
      WidgetTester tester,
    ) async {
      // Arrange - activity from yesterday
      final gamification = {
        'currentStreak': 5,
        'lastActivityDate': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicatorWidget(gamification: gamification),
          ),
        ),
      );

      // Assert - should show as active
      expect(find.text('🔥'), findsOneWidget);
    });

    testWidgets('should treat 2+ days ago as inactive', (
      WidgetTester tester,
    ) async {
      // Arrange - activity from 3 days ago
      final gamification = {
        'currentStreak': 5,
        'lastActivityDate': DateTime.now()
            .subtract(const Duration(days: 3))
            .toIso8601String(),
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicatorWidget(gamification: gamification),
          ),
        ),
      );

      // Assert - should show as inactive
      expect(find.text('💤'), findsOneWidget);
    });
  });
}
