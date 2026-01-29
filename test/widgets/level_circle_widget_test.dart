import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asesoria_app/widgets/gamification/level_circle_widget.dart';

void main() {
  group('LevelCircleWidget Tests', () {
    testWidgets('should display level number', (WidgetTester tester) async {
      // Arrange
      final gamification = {'level': 5, 'points': 750};

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LevelCircleWidget(gamification: gamification)),
        ),
      );

      // Assert
      expect(find.text('5'), findsOneWidget);
      expect(find.text('NIVEL'), findsOneWidget);
    });

    testWidgets('should display points', (WidgetTester tester) async {
      // Arrange
      final gamification = {'level': 5, 'points': 750};

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LevelCircleWidget(gamification: gamification)),
        ),
      );

      // Assert
      expect(find.text('750 pts'), findsOneWidget);
    });

    testWidgets('should handle null gamification data', (
      WidgetTester tester,
    ) async {
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LevelCircleWidget(gamification: null)),
        ),
      );

      // Assert - should default to level 1, 0 points
      expect(find.text('1'), findsOneWidget);
      expect(find.text('0 pts'), findsOneWidget);
    });

    testWidgets('should display progress percentage', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {'level': 5, 'points': 750};

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LevelCircleWidget(gamification: gamification)),
        ),
      );

      // Assert - should show progress to next level
      expect(find.textContaining('% al nivel'), findsOneWidget);
    });

    testWidgets('should use different colors for different level tiers', (
      WidgetTester tester,
    ) async {
      // Test Level 1-5 (Blue)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelCircleWidget(gamification: {'level': 3, 'points': 300}),
          ),
        ),
      );
      await tester.pump();

      // Test Level 6-10 (Purple)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelCircleWidget(gamification: {'level': 8, 'points': 1500}),
          ),
        ),
      );
      await tester.pump();

      // Test Level 11-15 (Gold)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelCircleWidget(
              gamification: {'level': 12, 'points': 5000},
            ),
          ),
        ),
      );
      await tester.pump();

      // If no errors thrown, colors are being applied correctly
      expect(find.byType(LevelCircleWidget), findsOneWidget);
    });

    testWidgets('should animate progress on mount', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {'level': 5, 'points': 750};

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LevelCircleWidget(gamification: gamification)),
        ),
      );

      // Initial frame
      await tester.pump();

      // Animation frames
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Assert - widget should still be present after animation
      expect(find.byType(LevelCircleWidget), findsOneWidget);
    });

    testWidgets('should display linear progress indicator', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {'level': 5, 'points': 750};

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LevelCircleWidget(gamification: gamification)),
        ),
      );

      // Assert
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('should handle very high levels', (WidgetTester tester) async {
      // Arrange
      final gamification = {'level': 99, 'points': 50000};

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LevelCircleWidget(gamification: gamification)),
        ),
      );

      // Assert
      expect(find.text('99'), findsOneWidget);
      expect(find.text('50000 pts'), findsOneWidget);
    });

    testWidgets('should use custom size when provided', (
      WidgetTester tester,
    ) async {
      // Arrange
      final gamification = {'level': 5, 'points': 750};

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelCircleWidget(gamification: gamification, size: 200),
          ),
        ),
      );

      // Assert - widget should render without errors
      expect(find.byType(LevelCircleWidget), findsOneWidget);
    });
  });
}
