import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../services/smart_insights_service.dart';

class SmartInsightsWidget extends StatefulWidget {
  final String clientId;
  const SmartInsightsWidget({super.key, required this.clientId});

  @override
  State<SmartInsightsWidget> createState() => _SmartInsightsWidgetState();
}

class _SmartInsightsWidgetState extends State<SmartInsightsWidget> {
  Map<String, dynamic>? _insights;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    final service = Provider.of<SmartInsightsService>(context, listen: false);
    final data = await service.getInsights(widget.clientId);
    if (mounted) {
      setState(() {
        _insights = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildShimmerLoading(context);
    }

    if (_insights == null || _insights!['insights'] == null) {
      return const SizedBox.shrink();
    }

    final List insightsList = _insights!['insights'] as List;
    if (insightsList.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withOpacity(0.05),
            theme.primaryColor.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.primaryColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: theme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'INSIGHTS INTELIGENTES',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: theme.primaryColor,
                ),
              ),
              const Spacer(),
              _InsightBadge(count: insightsList.length),
            ],
          ),
          const SizedBox(height: 16),
          ...insightsList.map((insight) => _buildInsightCard(insight, theme)),
        ],
      ),
    );
  }

  Widget _buildInsightCard(Map<String, dynamic> insight, ThemeData theme) {
    final type = insight['type'];
    final severity = insight['severity'];
    final title = insight['title'] ?? 'Insight';
    final description = insight['description'] ?? '';
    final recommendation = insight['recommendation'];

    IconData icon;
    Color color;

    switch (type) {
      case 'weight_stagnation':
        icon = Icons.warning_amber_rounded;
        color = severity == 'high' ? Colors.red : Colors.orange;
        break;
      case 'macro_change_alert':
        icon = Icons.restaurant_rounded;
        color = Colors.blue;
        break;
      case 'no_training_data':
      case 'low_training_adherence':
        icon = Icons.fitness_center_rounded;
        color = severity == 'high' ? Colors.redAccent : Colors.purple;
        break;
      case 'task_completion_issues':
        icon = Icons.assignment_late_rounded;
        color = Colors.amber.shade700;
        break;
      case 'low_engagement':
        icon = Icons.battery_alert_rounded;
        color = Colors.deepOrange;
        break;
      default:
        icon = Icons.lightbulb_outline_rounded;
        color = theme.primaryColor;
    }

    // Combine description with specific data if needed
    String fullDesc = description;
    if (recommendation != null) {
      fullDesc += '\n\n💡 $recommendation';
    }

    return _InsightItem(
      icon: icon,
      color: color,
      title: title,
      description: fullDesc,
      actionLabel: insight['actionable'] == true ? 'Ver acciones' : null,
      onAction: insight['actionable'] == true
          ? () {
              // TODO: Show suggested actions dialog
              _showActionsDialog(context, insight);
            }
          : null,
    );
  }

  void _showActionsDialog(BuildContext context, Map<String, dynamic> insight) {
    final actions = insight['suggestedActions'] as List?;
    if (actions == null || actions.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(insight['title'], style: const TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: actions
              .map(
                (action) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          action.toString(),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 150, height: 20, color: Colors.white),
            const SizedBox(height: 16),
            ...List.generate(
              2,
              (index) => Container(
                margin: const EdgeInsets.only(bottom: 16),
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightBadge extends StatelessWidget {
  final int count;
  const _InsightBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InsightItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InsightItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
                if (actionLabel != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      actionLabel!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
