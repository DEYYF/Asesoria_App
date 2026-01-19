import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../widgets/budget_detail_dialog.dart';
import '../widgets/add_draft_dialog.dart';
import '../widgets/add_client_dialog.dart';

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
        title: const Text(
          'Presupuestos',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            onPressed: () => setState(() => _isGrouped = !_isGrouped),
            icon: Icon(
              _isGrouped ? Icons.grid_view_rounded : Icons.list_alt_rounded,
              color: primary,
            ),
            tooltip: _isGrouped ? 'Vista Lista' : 'Vista Agrupada',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? theme.primaryColor
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (theme.brightness != Brightness.dark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: theme.brightness == Brightness.dark
                  ? Colors.white
                  : theme.primaryColor,
              unselectedLabelColor: theme.hintColor,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              onTap: (index) => setState(() {}),
              tabs: const [
                Tab(text: 'Registrados'),
                Tab(text: 'Borradores'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _fetchData, child: _buildBody()),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _showCreateBorradorDialog,
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              label: const Text(
                'Nuevo Borrador',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.add_rounded),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.white.withOpacity(0.03)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor,
                        theme.primaryColor.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      group['clientName'][0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group['clientName'],
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.alternate_email_rounded,
                            size: 14,
                            color: theme.hintColor.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${(group['presupuestos'] as List).length} PPTOS',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...(group['presupuestos'] as List).map(
            (p) => _buildPresupuestoItem(p, showClient: false),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPresupuestoItem(dynamic p, {bool showClient = true}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = p['estado'] as String;
    final isPaid = status == 'pagado';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'pagado':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'aceptado':
        statusColor = Colors.blue;
        statusIcon = Icons.thumb_up_rounded;
        break;
      case 'rechazado':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        break;
      case 'pendiente':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
          width: 1.5,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showDetail(p),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showClient) ...[
                        Text(
                          p['clienteId']?['nombre'] ??
                              p['nombreCliente'] ??
                              "Desconocido",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        p['tarifaId']?['nombre'] ?? 'Sin tarifa',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat(
                              'dd/MM/yyyy',
                            ).format(DateTime.parse(p['createdAt'])),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${p['total']} €',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleAction(value, p),
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: theme.hintColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      itemBuilder: (context) {
                        final isBorrador =
                            (p['estado'] == 'borrador' ||
                            p['clienteId'] == null);

                        if (isBorrador) {
                          return [
                            const PopupMenuItem(
                              value: 'accept_create',
                              child: ListTile(
                                leading: Icon(
                                  Icons.person_add,
                                  color: Colors.green,
                                ),
                                title: Text('Aceptar y Crear Cliente'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'add_discount',
                              child: ListTile(
                                leading: Icon(
                                  Icons.discount,
                                  color: Colors.orange,
                                ),
                                title: Text('Añadir Descuento'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete, color: Colors.red),
                                title: Text(
                                  'Eliminar',
                                  style: TextStyle(color: Colors.red),
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ];
                        }

                        return [
                          const PopupMenuItem(
                            value: 'detail',
                            child: ListTile(
                              leading: Icon(Icons.visibility),
                              title: Text('Ver Detalle'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit_status',
                            child: ListTile(
                              leading: Icon(
                                Icons.swap_horiz,
                                color: Colors.teal,
                              ),
                              title: Text('Cambiar Estado'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          if (!isPaid) // Logic restriction: hide discount if paid
                            const PopupMenuItem(
                              value: 'add_discount',
                              child: ListTile(
                                leading: Icon(
                                  Icons.discount,
                                  color: Colors.orange,
                                ),
                                title: Text('Añadir Descuento'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'pdf',
                            child: ListTile(
                              leading: Icon(
                                Icons.picture_as_pdf,
                                color: Colors.blue,
                              ),
                              title: Text('Descargar PDF'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'email',
                            child: ListTile(
                              leading: Icon(Icons.email, color: Colors.purple),
                              title: Text('Enviar Email'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete, color: Colors.red),
                              title: Text(
                                'Eliminar',
                                style: TextStyle(color: Colors.red),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleAction(String action, dynamic p) {
    switch (action) {
      case 'accept_create':
        _handleAcceptAndCreate(p);
        break;
      case 'add_discount':
        _showDiscountDialog(p);
        break;
      case 'edit_status':
        _showStatusDialog(p);
        break;
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
                            '${e['precioTotal'] ?? 0} €',
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
                enabled: status != 'pagado',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Descuento (%)',
                  suffixText: '%',
                  helperText: status == 'pagado'
                      ? 'No se puede editar descuento en un presupuesto pagado'
                      : null,
                  helperStyle: status == 'pagado'
                      ? const TextStyle(color: Colors.red)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Estado'),
                items:
                    ['borrador', 'pendiente', 'aceptado', 'rechazado', 'pagado']
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

                  if (status == 'aceptado') {
                    // Check if it already has a client linked
                    final hasClient = p['clienteId'] != null;
                    if (hasClient)
                      return; // Don't show create dialog if already linked

                    // Extract IDs for pre-filling
                    final tarifaId = p['tarifaId'] is Map
                        ? p['tarifaId']['_id']
                        : p['tarifaId'];
                    final extrasList = (p['extras'] as List).map((e) {
                      return e['extraId'] is Map
                          ? e['extraId']['_id'] as String
                          : e['extraId'] as String;
                    }).toList();

                    if (mounted) {
                      _showCreateClientFromBudget(
                        name:
                            p['clienteId']?['nombre'] ??
                            p['nombreCliente'] ??
                            '',
                        email:
                            p['clienteId']?['email'] ?? p['emailCliente'] ?? '',
                        tarifaId: tarifaId,
                        extras: extrasList,
                        budgetId: p['_id'],
                      );
                    }
                  }
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BudgetDetailDialog(budget: p),
    );
  }

  void _showCreateBorradorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddDraftDialog(
        tarifas: _tarifas,
        extras: _extras,
        onSuccess: _fetchData,
      ),
    );
  }

  void _handleAcceptAndCreate(dynamic p) async {
    // 1. Update status to 'pendiente' (User request: put as PENDING in registered clients)
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.put('/presupuestos/${p['_id']}', {'estado': 'pendiente'});
      // Don't call _fetchData here instantly to avoid potential UI jump, wait for client creation logic
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al aceptar: $e")));
      return;
    }

    // 2. Open Create Client Dialog
    if (!mounted) return;

    // Extract IDs
    final tarifaId = p['tarifaId'] is Map
        ? p['tarifaId']['_id']
        : p['tarifaId'];
    final extrasList = (p['extras'] as List).map((e) {
      return e['extraId'] is Map
          ? e['extraId']['_id'] as String
          : e['extraId'] as String;
    }).toList();

    _showCreateClientFromBudget(
      name: p['clienteId']?['nombre'] ?? p['nombreCliente'] ?? '',
      email: p['clienteId']?['email'] ?? p['emailCliente'] ?? '',
      tarifaId: tarifaId,
      extras: extrasList,
      budgetId: p['_id'],
    );
  }

  void _showDiscountDialog(dynamic p) {
    final discountController = TextEditingController(
      text: (p['descuento'] ?? 0).toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Añadir Descuento'),
        content: p['estado'] == 'pagado'
            ? const Text(
                'No se puede añadir un descuento a un presupuesto que ya ha sido pagado.',
                style: TextStyle(color: Colors.red),
              )
            : TextField(
                controller: discountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Descuento (%)',
                  suffixText: '%',
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          if (p['estado'] != 'pagado')
            ElevatedButton(
              onPressed: () async {
                final api = Provider.of<ApiService>(context, listen: false);
                try {
                  await api.put('/presupuestos/${p['_id']}', {
                    'descuento': double.tryParse(discountController.text) ?? 0,
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
    );
  }

  void _showStatusDialog(dynamic p) {
    String currentStatus = p['estado'] ?? 'pendiente';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar Estado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['pendiente', 'aceptado', 'pagado', 'rechazado'].map((
            status,
          ) {
            return RadioListTile<String>(
              title: Text(status.toUpperCase()),
              value: status,
              groupValue: currentStatus,
              onChanged: (val) {
                Navigator.pop(ctx);
                _updateStatus(p['_id'], val!);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.put('/presupuestos/$id', {'estado': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado actualizado a $newStatus')),
        );
      }
      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showCreateClientFromBudget({
    required String name,
    required String email,
    required String? tarifaId,
    required List<String> extras,
    required String budgetId,
  }) async {
    // Use await to wait for dialog result
    final newClientId = await showDialog<String>(
      context: context,
      builder: (ctx) => AddClientDialog(
        initialName: name,
        initialEmail: email,
        initialTarifaId: tarifaId,
        initialExtras: extras,
        onSuccess: (id) => Navigator.pop(ctx, id), // Return ID when closing
      ),
    );

    if (newClientId != null && mounted) {
      final api = Provider.of<ApiService>(context, listen: false);
      try {
        // Update budget with client ID
        await api.put('/presupuestos/$budgetId', {
          'clienteId': newClientId,
          'nombreCliente': null,
          'emailCliente': null,
          'estado': 'pendiente', // Reinforce status as PENDING
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cliente creado y presupuesto vinculado (Pendiente)',
              ),
            ),
          );
          // Refresh data safely
          _fetchData();
        }
      } catch (e) {
        debugPrint("Error linking budget: $e");
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error vinculando: $e')));
        }
      }
    } else {
      // If cancelled or failed, refresh to ensure UI is consistent
      if (mounted) _fetchData();
    }
  }
}

extension DateTimeIso on DateTime {
  String toIsoFormatString() => toIso8601String();
}
