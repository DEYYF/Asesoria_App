import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../utils/notification_helper.dart';

class RevisionsDialog extends StatefulWidget {
  final String dietaId;
  final Function(String newId) onRestored;

  const RevisionsDialog({
    super.key,
    required this.dietaId,
    required this.onRestored,
  });

  @override
  State<RevisionsDialog> createState() => _RevisionsDialogState();
}

class _RevisionsDialogState extends State<RevisionsDialog> {
  bool _isLoading = true;
  List<dynamic> _revisions = [];

  @override
  void initState() {
    super.initState();
    _loadRevisions();
  }

  Future<void> _loadRevisions() async {
    final api = Provider.of<ApiService>(context, listen: false);
    setState(() => _isLoading = true);
    try {
      final res = await api.get('/dietas/${widget.dietaId}/revisions');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _revisions = data['revisions'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Error fetching revisions');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        NotificationHelper.showError(context, 'Error al cargar historial: $e');
      }
    }
  }

  Future<void> _restoreRevision(String rev) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.post('/dietas/${widget.dietaId}/restore/$rev', {
        'note': 'Restaurado desde historial',
      });

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final newDieta = data['dieta'];
        if (newDieta != null && newDieta['_id'] != null) {
          if (mounted) {
            Navigator.pop(context);
            widget.onRestored(newDieta['_id']);
            NotificationHelper.showSuccess(
              context,
              'Revisión restaurada con éxito',
            );
          }
        }
      } else {
        throw Exception(res.body);
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(context, 'Error al restaurar: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        // Limit width but allow it to shrink
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Historial de Versiones',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Restaura versiones anteriores.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: theme.hintColor,
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_revisions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: Text("No hay revisiones disponibles")),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _revisions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final rev = _revisions[i];
                    final isCurrent = rev['isCurrent'] == true;
                    final date = rev['createdAt'] != null
                        ? DateFormat(
                            'dd MMM yyyy, HH:mm',
                          ).format(DateTime.parse(rev['createdAt']))
                        : '-';
                    final note = rev['note'] ?? 'Sin nota';
                    final revNum = rev['rev'] ?? 0;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? theme.primaryColor.withOpacity(
                                isDark ? 0.2 : 0.05,
                              )
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrent
                              ? theme.primaryColor.withOpacity(0.5)
                              : theme.dividerColor.withOpacity(0.05),
                          width: isCurrent ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? theme.primaryColor
                                  : theme.dividerColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$revNum',
                                style: TextStyle(
                                  color: isCurrent
                                      ? Colors.white
                                      : theme.textTheme.bodyMedium?.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        date,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isCurrent) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.primaryColor.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          "ACTUAL",
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: theme.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  note,
                                  style: TextStyle(
                                    color: theme.hintColor,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!isCurrent)
                            OutlinedButton(
                              onPressed: () =>
                                  _restoreRevision(revNum.toString()),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 0,
                                ),
                                minimumSize: const Size(0, 32),
                                side: BorderSide(color: theme.dividerColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                "Restaurar",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
