import 'package:flutter/material.dart';

class NotificationHelper {
  static void showSuccess(BuildContext context, String message) {
    _showFloatingSnackBar(
      context,
      message,
      Colors.green,
      Icons.check_circle_rounded,
    );
  }

  static void showError(BuildContext context, String message) {
    _showFloatingSnackBar(context, message, Colors.red, Icons.error_rounded);
  }

  static void showInfo(BuildContext context, String message) {
    final theme = Theme.of(context);
    _showFloatingSnackBar(
      context,
      message,
      theme.primaryColor,
      Icons.info_rounded,
    );
  }

  static void _showFloatingSnackBar(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color.withOpacity(0.95),
        elevation: 6,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
