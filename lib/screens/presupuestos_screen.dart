import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PresupuestosScreen extends StatefulWidget {
  const PresupuestosScreen({super.key});

  @override
  State<PresupuestosScreen> createState() => _PresupuestosScreenState();
}

class _PresupuestosScreenState extends State<PresupuestosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isGrouped = true;

  List<dynamic> _presupuestos = [];
  List<dynamic> _tarifas = [];
  List<dynamic> _extras = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      setState(() => _isLoading = true);

      final responses = await Future.wait([
        api.get('/presupuestos?asesorId=${auth.userId}'),
        api.get('/tarifas'),
        api.get('/extras'),
      ]);

      if (mounted) {
        setState(() {
          _presupuestos = jsonDecode(responses[0].body);
          _tarifas = jsonDecode(responses[1].body);
          _extras = jsonDecode(responses[2].body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching budgets: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getGroupedPresupuestos() {
    final isBorradores = _tabController.index == 1;
    final filtered = _presupuestos.where((p) {
      final hasClient = p['clienteId'] != null;
      return isBorradores ? !hasClient : hasClient;
    }).toList();

    if (!_isGrouped) {
      return {'ungrouped': filtered};
    }

    final Map<String, dynamic> grouped = {};
    for (var p in filtered) {
      final clientKey =
          p['clienteId']?['_id'] ?? p['emailCliente'] ?? 'sin-cliente';
      final clientName =
          p['clienteId']?['nombre'] ?? p['nombreCliente'] ?? "Desconocido";
      final clientEmail = p['clienteId']?['email'] ?? p['emailCliente'] ?? "";

      if (!grouped.containsKey(clientKey)) {
        grouped[clientKey] = {
          'clientName': clientName,
          'clientEmail': clientEmail,
          'presupuestos': [],
        };
      }
      grouped[clientKey]['presupuestos'].add(p);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Gestión de Presupuestos'),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _isGrouped = !_isGrouped),
            icon: Icon(
              _isGrouped ? Icons.grid_view_rounded : Icons.list_alt_rounded,
            ),
            label: Text(_isGrouped ? 'Vista Agrupada' : 'Vista Lista'),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primary,
          labelColor: primary,
          unselectedLabelColor: theme.hintColor,
          onTap: (index) => setState(() {}),
          tabs: const [
            Tab(text: 'Clientes Registrados'),
            Tab(text: 'Borradores'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _fetchData, child: _buildBody()),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _showCreateBorradorDialog,
              label: const Text('Nuevo Borrador'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody() {
    final grouped = _getGroupedPresupuestos();
    if (grouped.isEmpty ||
        (grouped.containsKey('ungrouped') &&
            (grouped['ungrouped'] as List).isEmpty)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: Theme.of(context).hintColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay presupuestos registrados.',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ],
        ),
      );
    }

    if (!_isGrouped) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: (grouped['ungrouped'] as List).length,
        itemBuilder: (context, index) =>
            _buildPresupuestoItem(grouped['ungrouped'][index]),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((e) => _buildGroupItem(e.value)).toList(),
    );
  }

  Widget _buildGroupItem(Map<String, dynamic> group) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.grey[100],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  child: Text(
                    group['clientName'][0].toUpperCase(),
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group['clientName'],
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      group['clientEmail'],
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ...(group['presupuestos'] as List).map(
            (p) => _buildPresupuestoItem(p, showClient: false),
          ),
        ],
      ),
    );
  }

  Widget _buildPresupuestoItem(dynamic p, {bool showClient = true}) {
    final theme = Theme.of(context);
    final status = p['estado'] as String;

    Color statusColor;
    switch (status) {
      case 'pagado':
      case 'aceptado':
        statusColor = Colors.green;
        break;
      case 'rechazado':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showClient) ...[
            Text(
              p['clienteId']?['nombre'] ?? p['nombreCliente'] ?? "Desconocido",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              Text(
                p['tarifaId']?['nombre'] ?? 'Sin tarifa',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${p['total']} €',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.2)),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd/MM/yyyy').format(DateTime.parse(p['createdAt'])),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => _handleAction(value, p),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'detail',
            child: ListTile(
              leading: Icon(Icons.visibility),
              title: Text('Ver Detalle'),
            ),
          ),
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(leading: Icon(Icons.edit), title: Text('Editar')),
          ),
          const PopupMenuItem(
            value: 'pdf',
            child: ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Colors.blue),
              title: Text('Descargar PDF'),
            ),
          ),
          const PopupMenuItem(
            value: 'email',
            child: ListTile(
              leading: Icon(Icons.email, color: Colors.purple),
              title: Text('Enviar Email'),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(String action, dynamic p) {
    switch (action) {
      case 'detail':
        _showDetail(p);
        break;
      case 'edit':
        _showEditDialog(p);
        break;
      case 'delete':
        _handleDelete(p);
        break;
      case 'pdf':
        _handleDownloadPdf(p);
        break;
      case 'email':
        _handleSendEmail(p);
        break;
    }
  }

  Future<void> _handleDownloadPdf(dynamic p) async {
    try {
      final doc = await _generatePdf(p);
      final name = p['clienteId']?['nombre'] ?? p['nombreCliente'] ?? "Cliente";
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'Presupuesto_${name.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e')));
      }
    }
  }

  Future<void> _handleSendEmail(dynamic p) async {
    final email = p['clienteId']?['email'] ?? p['emailCliente'];
    final name = p['clienteId']?['nombre'] ?? p['nombreCliente'] ?? "Cliente";

    if (email == null || email.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El presupuesto no tiene email asociado.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar Email'),
        content: Text('¿Enviar presupuesto por email a $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final doc = await _generatePdf(p);
      final pdfBytes = await doc.save();
      final base64Pdf = base64Encode(pdfBytes);

      final htmlContent =
          '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #333;">Hola $name,</h2>
          <p>Te dejamos por aquí el presupuesto de tu asesoría. Esperamos pronta respuesta.</p>
          <p>Un saludo.</p>
        </div>
      ''';

      await api.post('/correo/enviar', {
        'to': email,
        'subject': 'Tu Presupuesto - Asesoría',
        'html': htmlContent,
        'attachments': [
          {
            'filename': 'Presupuesto_${name.replaceAll(' ', '_')}.pdf',
            'content': base64Pdf,
            'encoding': 'base64',
          },
        ],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email enviado correctamente.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al enviar email: $e')));
      }
    }
  }

  Future<pw.Document> _generatePdf(dynamic p) async {
    final doc = pw.Document();
    final primaryColor = PdfColor.fromHex('#2980b9');
    final name = p['clienteId']?['nombre'] ?? p['nombreCliente'] ?? "N/A";
    final email = p['clienteId']?['email'] ?? p['emailCliente'] ?? "";

    doc.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PRESUPUESTO',
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.Text(
                        'ID: ${p['_id']}',
                        style: const pw.TextStyle(
                          color: PdfColors.grey,
                          fontSize: 10,
                        ),
                      ),
                      pw.Text(
                        'Fecha: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(p['createdAt']))}',
                        style: const pw.TextStyle(
                          color: PdfColors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Cliente Box
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border(
                    left: pw.BorderSide(color: PdfColors.grey, width: 2),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Datos del Cliente:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    pw.Text(name, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(email, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: primaryColor),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'CONCEPTO',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'PRECIO',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          p['tarifaId']?['nombre'] ?? 'Tarifa Base',
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '${p['tarifaId']?['precio'] ?? 0} €',
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  ...(p['extras'] as List).map(
                    (e) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Extra: ${e['extraId']?['nombre'] ?? 'Extra'}',
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '${e['precioTotal']} €',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if ((p['descuento'] ?? 0) > 0)
                        pw.Text(
                          'Descuento (${p['descuento']}%): - ${((p['total'] * 100 / (100 - p['descuento'])) - p['total']).toStringAsFixed(2)} €',
                          style: const pw.TextStyle(color: PdfColors.red),
                        ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'TOTAL: ${p['total']} €',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ASESORIA ENTERPRISE',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey,
                        ),
                      ),
                      pw.Text(
                        'asesoriaenterprise@gmail.com',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Gracias por confiar en nuestros servicios.',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    return doc;
  }

  Future<void> _handleDelete(dynamic p) async {
    final name =
        p['clienteId']?['nombre'] ?? p['nombreCliente'] ?? "este presupuesto";
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Presupuesto'),
        content: Text('¿Estás seguro de eliminar el presupuesto de $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final api = Provider.of<ApiService>(context, listen: false);
      try {
        await api.delete('/presupuestos/${p['_id']}');
        _fetchData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _showEditDialog(dynamic p) {
    final discountController = TextEditingController(
      text: (p['descuento'] ?? 0).toString(),
    );
    String status = p['estado'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Editar Presupuesto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: discountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Descuento (%)',
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: ['pendiente', 'aceptado', 'rechazado', 'pagado']
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setS(() => status = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final api = Provider.of<ApiService>(context, listen: false);
                try {
                  await api.put('/presupuestos/${p['_id']}', {
                    'descuento': double.tryParse(discountController.text) ?? 0,
                    'estado': status,
                  });
                  Navigator.pop(ctx);
                  _fetchData();
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(dynamic p) {
    // Professional detail view
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Detalle del Presupuesto',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  _buildDetailSection(
                    'CLIENTE',
                    p['clienteId']?['nombre'] ?? p['nombreCliente'] ?? 'N/A',
                  ),
                  _buildDetailSection(
                    'EMAIL',
                    p['clienteId']?['email'] ?? p['emailCliente'] ?? 'N/A',
                  ),
                  _buildDetailSection(
                    'FECHA',
                    DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format(DateTime.parse(p['createdAt'])),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'CONCEPTOS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  _buildConceptRow(
                    p['tarifaId']?['nombre'] ?? 'Tarifa Base',
                    '${p['tarifaId']?['precio'] ?? 0} €',
                  ),
                  ...(p['extras'] as List).map((e) {
                    // Logic matches JSX: price * months
                    return _buildConceptRow(
                      'Extra: ${e['extraId']?['nombre'] ?? 'Extra'}',
                      '${e['precioTotal']} €',
                    );
                  }),
                  const Divider(),
                  if ((p['descuento'] ?? 0) > 0)
                    _buildConceptRow(
                      'Descuento (${p['descuento']}%)',
                      '- ${((p['total'] * 100 / (100 - p['descuento'])) - p['total']).toStringAsFixed(2)} €',
                      color: Colors.green,
                    ),
                  _buildConceptRow('TOTAL', '${p['total']} €', isTotal: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildConceptRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 14,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: isTotal ? 20 : 14,
              color: isTotal ? Theme.of(context).primaryColor : color,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateBorradorDialog() {
    final nameTitleController = TextEditingController();
    final emailController = TextEditingController();
    String? selectedTarifa;
    List<String> selectedExtras = [];
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Nuevo Borrador'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Interesado',
                  ),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedTarifa,
                  decoration: const InputDecoration(labelText: 'Tarifa'),
                  items: _tarifas
                      .map(
                        (t) => DropdownMenuItem(
                          value: t['_id'] as String,
                          child: Text('${t['nombre']} (${t['precio']}€)'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setS(() => selectedTarifa = val),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Extras',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 8,
                  children: _extras.map((e) {
                    final isSelected = selectedExtras.contains(e['_id']);
                    return FilterChip(
                      label: Text(e['nombre']),
                      selected: isSelected,
                      onSelected: (val) {
                        setS(() {
                          if (val)
                            selectedExtras.add(e['_id']);
                          else
                            selectedExtras.remove(e['_id']);
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setS(() => selectedDate = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha Inicio Prevista',
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameTitleController.text.isEmpty || selectedTarifa == null)
                  return;

                final api = Provider.of<ApiService>(context, listen: false);
                final auth = Provider.of<AuthService>(context, listen: false);
                try {
                  await api.post('/presupuestos', {
                    'nombreCliente': nameTitleController.text,
                    'emailCliente': emailController.text,
                    'tarifaId': selectedTarifa,
                    'extras': selectedExtras,
                    'fechaInicio': selectedDate.toIsoFormatString().split(
                      'T',
                    )[0],
                    'usuarioId': auth.userId,
                  });
                  Navigator.pop(ctx);
                  _fetchData();
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Crear Borrador'),
            ),
          ],
        ),
      ),
    );
  }
}

extension DateTimeIso on DateTime {
  String toIsoFormatString() => toIso8601String();
}
