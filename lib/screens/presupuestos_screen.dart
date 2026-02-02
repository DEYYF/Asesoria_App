import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/budget_detail_dialog.dart';
import '../widgets/add_draft_dialog.dart';
import '../widgets/add_client_dialog.dart';
import '../widgets/advisor_selector.dart';
import '../providers/super_admin_provider.dart';
import '../providers/settings_provider.dart';
import '../models/settings_model.dart';
import '../utils/budget_pdf_generator.dart';
import '../utils/pdf_export_helper.dart';
import '../services/settings_service.dart';
import 'facturas/factura_detail_screen.dart';

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

    // Listen for advisor changes if superadmin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saProvider = Provider.of<SuperAdminProvider>(
        context,
        listen: false,
      );
      saProvider.addListener(_onAdvisorChanged);
    });
  }

  void _onAdvisorChanged() {
    if (mounted) _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      setState(() => _isLoading = true);

      final saProvider = Provider.of<SuperAdminProvider>(
        context,
        listen: false,
      );
      String queryParam = '';

      if (!auth.isSuperAdmin) {
        // Normal Advisor: Restricted to own data
        queryParam = 'asesorId=${auth.userId}';
      } else {
        // Super Admin:
        // If selectedAdvisorId is present, filter by it.
        // If null, allow global view (empty param or handled by backend)
        final selectedId = saProvider.selectedAdvisorId;
        if (selectedId != null) {
          queryParam = 'asesorId=$selectedId';
        }
        // If null, we send empty string/no param to get ALL
      }

      final responses = await Future.wait([
        api.get('/presupuestos?$queryParam'),
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
      final isBorrador = p['estado'] == 'borrador';
      return isBorradores ? isBorrador : !isBorrador;
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
      body: Column(
        children: [
          if (Provider.of<AuthService>(context, listen: false).isSuperAdmin)
            const AdvisorSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(onRefresh: _fetchData, child: _buildBody()),
          ),
        ],
      ),
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
                        final isBorrador = p['estado'] == 'borrador';
                        final isPendiente = p['estado'] == 'pendiente';
                        final isAceptado = p['estado'] == 'aceptado';
                        final isPagado = p['estado'] == 'pagado';
                        final isLocked = isAceptado || isPagado;

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

                        // Menu for Pendiente, Aceptado, Pagado, Rechazado
                        return [
                          const PopupMenuItem(
                            value: 'detail',
                            child: ListTile(
                              leading: Icon(Icons.visibility),
                              title: Text('Ver Detalle'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          if (isPendiente)
                            PopupMenuItem(
                              value: p['clienteId'] == null
                                  ? 'accept_create'
                                  : 'edit_status',
                              child: ListTile(
                                leading: Icon(
                                  p['clienteId'] == null
                                      ? Icons.person_add
                                      : Icons.check_circle_outline,
                                  color: Colors.green,
                                ),
                                title: Text(
                                  p['clienteId'] == null
                                      ? 'Aceptar y Crear Cliente'
                                      : 'Cambiar a Aceptado',
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          if (p['facturaId'] != null)
                            const PopupMenuItem(
                              value: 'view_invoice',
                              child: ListTile(
                                leading: Icon(
                                  Icons.receipt_long_rounded,
                                  color: Colors.deepPurple,
                                ),
                                title: Text('Ver Factura'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          const PopupMenuDivider(),
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
                          // Only allow delete if not locked (not accepted/paid) AND NOT pending
                          if (!isLocked && !isPendiente) ...[
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
                          ],
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
      case 'view_invoice':
        if (p['facturaId'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FacturaDetailScreen(facturaId: p['facturaId']),
            ),
          );
        }
        break;
    }
  }

  Future<void> _handleDownloadPdf(dynamic p) async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      PdfSettings pdfSettings;

      final advisorId = p['asesorId'] is Map
          ? p['asesorId']['_id']
          : p['asesorId'];

      if (settingsProvider.settings != null &&
          (advisorId == null ||
              advisorId ==
                  Provider.of<AuthService>(context, listen: false).userId)) {
        pdfSettings = settingsProvider.settings!.pdfSettings;
      } else if (advisorId != null) {
        final settingsService = SettingsService(
          Provider.of<ApiService>(context, listen: false),
        );
        final settings = await settingsService.getSettings(userId: advisorId);
        pdfSettings = settings.pdfSettings;
      } else {
        pdfSettings = PdfSettings();
      }

      final doc = await BudgetPdfGenerator.generateDocument(p, pdfSettings);
      final name = p['clienteId']?['nombre'] ?? p['nombreCliente'] ?? "Cliente";
      final fileName = 'Presupuesto_${name.replaceAll(' ', '_')}.pdf';

      await PdfExportHelper.exportPdf(
        bytes: await doc.save(),
        fileName: fileName,
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
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      PdfSettings pdfSettings;

      final advisorId = p['asesorId'] is Map
          ? p['asesorId']['_id']
          : p['asesorId'];

      if (settingsProvider.settings != null &&
          (advisorId == null ||
              advisorId ==
                  Provider.of<AuthService>(context, listen: false).userId)) {
        pdfSettings = settingsProvider.settings!.pdfSettings;
      } else if (advisorId != null) {
        final settingsService = SettingsService(api);
        final settings = await settingsService.getSettings(userId: advisorId);
        pdfSettings = settings.pdfSettings;
      } else {
        pdfSettings = PdfSettings();
      }

      final doc = await BudgetPdfGenerator.generateDocument(p, pdfSettings);
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
    // 1. Initial cleanup (optional, but keep for consistency)
    // No explicit status update needed here anymore, we'll do once client is created

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

    // If status is 'pendiente', user can ONLY move it to 'aceptado'
    final List<String> availableStatuses = currentStatus == 'pendiente'
        ? ['aceptado']
        : ['pendiente', 'aceptado', 'pagado', 'rechazado'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar Estado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableStatuses.map((status) {
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
        skipBudgetCreation: true, // IMPORTANT: Don't create a new budget
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
          'estado': 'aceptado', // Trigger auto-invoice!
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
