  import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class EmailHistoryScreen extends StatefulWidget {
  final String? clienteId;
  final String? clienteNombre;

  const EmailHistoryScreen({super.key, this.clienteId, this.clienteNombre});

  @override
  State<EmailHistoryScreen> createState() => _EmailHistoryScreenState();
}

class _EmailHistoryScreenState extends State<EmailHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _logs = [];
  int _currentPage = 1;
  int _totalPages = 1;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      final url =
          '/correo/historial/${auth.userId}?page=$_currentPage&limit=$_limit${widget.clienteId != null ? '&clienteId=${widget.clienteId}' : ''}';
      final res = await api.get(url);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        setState(() {
          _logs = decoded['data'] ?? [];
          _totalPages = decoded['pagination']?['pages'] ?? 1;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading email history: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.clienteNombre != null
              ? 'Historial: ${widget.clienteNombre}'
              : 'Historial de Correos',
        ),
        elevation: 0,
      ),
      body: _isLoading && _logs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_logs.isEmpty)
                  const Expanded(
                    child: Center(child: Text('No hay correos enviados aún.')),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _logs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        return _buildLogCard(log, theme, isDark);
                      },
                    ),
                  ),
                if (_totalPages > 1) _buildPagination(theme),
              ],
            ),
    );
  }

  Widget _buildLogCard(dynamic log, ThemeData theme, bool isDark) {
    final date = DateTime.parse(log['fecha']).toLocal();
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);
    final hasHtml = log['html'] != null && log['html'].toString().isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: const Icon(Icons.email_outlined, color: Colors.blue, size: 20),
        ),
        title: Text(
          log['asunto'] ?? '(Sin asunto)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Para: ${log['destinatario']}\n$formattedDate',
          style: TextStyle(fontSize: 12, color: theme.hintColor),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log['clienteId'] != null && widget.clienteId == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Cliente: ${log['clienteId']['nombre']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  log['mensaje'] ??
                      (hasHtml ? '[Contenido HTML]' : '(Sin mensaje)'),
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                ),
                if (hasHtml)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextButton.icon(
                      onPressed: () => _viewHtml(log['html']),
                      icon: const Icon(Icons.code, size: 16),
                      label: const Text('Ver Contenido HTML'),
                    ),
                  ),
                if (log['attachments'] != null &&
                    (log['attachments'] as List).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Adjuntos:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: (log['attachments'] as List)
                              .map(
                                (a) => Chip(
                                  label: Text(
                                    a['filename'] ?? 'Archivo',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  avatar: const Icon(
                                    Icons.attach_file,
                                    size: 14,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _viewHtml(String html) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Contenido HTML'),
        content: SingleChildScrollView(
          child: Text(html, style: const TextStyle(fontSize: 12)),
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

  Widget _buildPagination(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: theme.scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage--);
                    _loadHistory();
                  }
                : null,
          ),
          Text('$_currentPage / $_totalPages'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () {
                    setState(() => _currentPage++);
                    _loadHistory();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
