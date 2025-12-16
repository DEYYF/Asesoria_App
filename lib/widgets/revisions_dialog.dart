import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../services/api_service.dart';

class RevisionsDialog extends StatefulWidget {
  final String dietaId;
  final Function(String newId)
  onRestored; // Callback with new ID (restored diet ID)

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
        // Response structure: { lineageId, revisions: [...] }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar historial: $e')),
        );
      }
    }
  }

  Future<void> _restoreRevision(String rev) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      // POST /dietas/:id/restore/:rev
      // Body needs { note: ... } potentially? Controller says `req.body.note` optional.
      final res = await api.post('/dietas/${widget.dietaId}/restore/$rev', {
        'note': 'Restaurado desde historial',
      });

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final newDieta =
            data['dieta']; // Controller returns { ok: true, dieta: ... }
        if (newDieta != null && newDieta['_id'] != null) {
          if (mounted) {
            Navigator.pop(context); // Close dialog
            widget.onRestored(newDieta['_id']);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Revisión restaurada con éxito')),
            );
          }
        }
      } else {
        throw Exception(res.body);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al restaurar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Historial de Versiones'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _revisions.isEmpty
            ? const Center(child: Text('No hay revisiones'))
            : ListView.builder(
                itemCount: _revisions.length,
                itemBuilder: (ctx, i) {
                  final rev = _revisions[i];
                  final isCurrent = rev['isCurrent'] == true;
                  final date = rev['createdAt'] != null
                      ? DateFormat(
                          'dd/MM/yyyy HH:mm',
                        ).format(DateTime.parse(rev['createdAt']))
                      : '-';
                  final note = rev['note'] ?? 'Sin notas';
                  final revNum = rev['rev'] ?? 0;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrent ? Colors.green : Colors.grey,
                      child: Text(
                        '$revNum',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text('Revisión $revNum - $date'),
                    subtitle: Text(note),
                    trailing: isCurrent
                        ? const Chip(
                            label: Text('Actual'),
                            backgroundColor: Colors.greenAccent,
                          )
                        : OutlinedButton(
                            onPressed: () =>
                                _restoreRevision(revNum.toString()),
                            child: const Text('Restaurar'),
                          ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
