import 'package:flutter/material.dart';

class AdvisorStatsTab extends StatelessWidget {
  final Map<String, dynamic>? stats;

  const AdvisorStatsTab({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats == null) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          theme,
          'Clientes',
          stats!['clients']?.toString() ?? '0',
          Icons.people_alt,
          Colors.blue,
        ),
        _buildStatCard(
          theme,
          'Citas',
          stats!['appointments']?.toString() ?? '0',
          Icons.calendar_month,
          Colors.green,
        ),
        _buildStatCard(
          theme,
          'Tareas',
          stats!['tasks']?.toString() ?? '0',
          Icons.check_circle,
          Colors.orange,
        ),
        _buildStatCard(
          theme,
          'Sesiones',
          (stats!['sessions'] ?? 0).toString(),
          Icons.video_camera_front,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: theme.hintColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
