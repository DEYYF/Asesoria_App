import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cliente_model.dart';
import '../../services/factura_service.dart';
import '../../services/api_service.dart';
import '../../services/client_service.dart';
import '../../services/auth_service.dart';
import '../../providers/super_admin_provider.dart';
import '../../models/factura_model.dart';

class CreateFacturaScreen extends StatefulWidget {
  final String? facturaId; // Null for create mode

  const CreateFacturaScreen({super.key, this.facturaId});

  @override
  State<CreateFacturaScreen> createState() => _CreateFacturaScreenState();
}

class _CreateFacturaScreenState extends State<CreateFacturaScreen> {
  final _formKey = GlobalKey<FormState>();
  late FacturaService _facturaService;
  late ClientService _clientService;

  List<Cliente> _clientes = [];
  Cliente? _selectedCliente;

  final _conceptoController = TextEditingController();
  final _notasController = TextEditingController();
  final _descuentoGlobalController = TextEditingController(text: '0');

  // Receptor controllers
  final _receptorNombreController = TextEditingController();
  final _receptorNifController = TextEditingController();
  final _receptorDireccionController = TextEditingController();
  final _receptorCPController = TextEditingController();
  final _receptorCiudadController = TextEditingController();
  final _receptorProvinciaController = TextEditingController();

  bool get _isEdit => widget.facturaId != null;
  bool get _isAdmin =>
      Provider.of<AuthService>(context, listen: false).isSuperAdmin;

  DateTime _vencimiento = DateTime.now().add(const Duration(days: 30));
  String _metodoPago = 'transferencia';

  List<FacturaItemForm> _items = [FacturaItemForm()];

  bool _isLoading = false;
  bool _loadingClientes = true;
  String? _selectedAsesorId;
  Factura? _editingFactura;

  @override
  void initState() {
    super.initState();
    _facturaService = FacturaService(
      Provider.of<ApiService>(context, listen: false),
    );
    _clientService = ClientService(
      Provider.of<ApiService>(context, listen: false),
    );

    final saProv = Provider.of<SuperAdminProvider>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    _selectedAsesorId = saProv.selectedAdvisorId ?? auth.userId;

    if (_isEdit) {
      _loadFacturaToEdit();
    } else {
      _loadClientes();
    }
  }

  Future<void> _loadFacturaToEdit() async {
    setState(() => _isLoading = true);
    try {
      final factura = await _facturaService.getFacturaById(widget.facturaId!);
      setState(() {
        _editingFactura = factura;
        _conceptoController.text = factura.concepto;
        _notasController.text = factura.notas ?? '';
        _vencimiento = factura.vencimiento;
        _metodoPago = factura.metodoPago;
        _selectedAsesorId = factura.asesorId;
        _descuentoGlobalController.text = factura.descuentoGlobal.toStringAsFixed(0);

        // Load items
        _items = factura.items.map((it) {
          final form = FacturaItemForm();
          form.descripcion = it.descripcion;
          form.cantidad = it.cantidad;
          form.precioUnitario = it.precioUnitario;
          form.iva = it.iva;
          form.descuento = it.descuento;
          return form;
        }).toList();

        // Load receptor
        _receptorNombreController.text = factura.datosReceptor.nombre;
        _receptorNifController.text = factura.datosReceptor.nif;
        _receptorDireccionController.text = factura.datosReceptor.direccion;
        _receptorCPController.text = factura.datosReceptor.codigoPostal;
        _receptorCiudadController.text = factura.datosReceptor.ciudad;
        _receptorProvinciaController.text =
            factura.datosReceptor.provincia ?? '';

        _isLoading = false;
        _loadingClientes =
            false; // No need to load all clients in edit mode usually
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar factura: $e')));
      }
    }
  }

  Future<void> _loadClientes() async {
    try {
      final clientes = await _clientService.getClients();
      setState(() {
        _clientes = clientes;
        _loadingClientes = false;
      });
    } catch (e) {
      setState(() => _loadingClientes = false);
    }
  }

  double get _subtotal {
    return _items.fold(0.0, (sum, item) {
      final base = (item.cantidad ?? 0) * (item.precioUnitario ?? 0);
      return sum + base;
    });
  }

  double get _descuentoGlobal {
    final value = double.tryParse(_descuentoGlobalController.text.replaceAll(',', '.')) ?? 0;
    return value.clamp(0, 100).toDouble();
  }

  double get _subtotalConDescuentos {
    final subtotalLineas = _items.fold(0.0, (sum, item) {
      final base = (item.cantidad ?? 0) * (item.precioUnitario ?? 0);
      final descuentoLinea = base * (((item.descuento ?? 0).clamp(0, 100)) / 100);
      return sum + (base - descuentoLinea);
    });
    return subtotalLineas * (1 - (_descuentoGlobal / 100));
  }

  double get _totalIVA {
    final totalIvaLineas = _items.fold(0.0, (sum, item) {
      final base = (item.cantidad ?? 0) * (item.precioUnitario ?? 0);
      final descuentoLinea = base * (((item.descuento ?? 0).clamp(0, 100)) / 100);
      final baseLinea = base - descuentoLinea;
      final pesoGlobal = 1 - (_descuentoGlobal / 100);
      final iva = (baseLinea * pesoGlobal) * ((item.iva ?? 21) / 100);
      return sum + iva;
    });
    return totalIvaLineas;
  }

  double get _total => _subtotalConDescuentos + _totalIVA;

  Future<void> _saveFactura() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && _selectedCliente == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona un cliente')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final facturaData = {
        if (!_isEdit) 'clienteId': _selectedCliente!.id,
        'concepto': _conceptoController.text,
        'items': _items.map((item) {
          final base = (item.cantidad ?? 0) * (item.precioUnitario ?? 0);
          final ivaVal = item.iva ?? 21;
          final descuentoVal = (item.descuento ?? 0).clamp(0, 100).toDouble();
          final baseConDescuento = base * (1 - descuentoVal / 100);
          final ivaImporte = baseConDescuento * (ivaVal / 100);
          return {
            'descripcion': item.descripcion,
            'cantidad': item.cantidad,
            'precioUnitario': item.precioUnitario,
            'iva': ivaVal,
            'descuento': descuentoVal,
            'total': baseConDescuento + ivaImporte,
          };
        }).toList(),
        'vencimiento': _vencimiento.toIso8601String(),
        'metodoPago': _metodoPago,
        'descuentoGlobal': _descuentoGlobal,
        'notas': _notasController.text.isNotEmpty
            ? _notasController.text
            : null,
        'asesorId': _selectedAsesorId,
        'datosReceptor': {
          'nombre': _receptorNombreController.text,
          'nif': _receptorNifController.text,
          'direccion': _receptorDireccionController.text,
          'codigoPostal': _receptorCPController.text,
          'ciudad': _receptorCiudadController.text,
          'provincia': _receptorProvinciaController.text,
        },
      };

      if (_isEdit) {
        await _facturaService.updateFactura(widget.facturaId!, facturaData);
      } else {
        await _facturaService.createFactura(facturaData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit
                  ? '✓ Factura actualizada correctamente'
                  : '✓ Factura creada correctamente',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF000000)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Editar Factura' : 'Nueva Factura',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading && _isEdit
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildIntroCard(theme, isDark),
                        const SizedBox(height: 16),
                        if (!_isEdit) ...[
                          _buildClienteCard(theme, isDark),
                          const SizedBox(height: 16),
                        ],
                        _buildReceptorCard(theme, isDark),
                        const SizedBox(height: 16),
                        _buildConceptoCard(theme, isDark),
                        const SizedBox(height: 16),
                        _buildDetallesCard(theme, isDark),
                        const SizedBox(height: 16),
                        _buildItemsSection(theme, isDark),
                        const SizedBox(height: 16),
                        _buildTotalsPreviewCard(theme, isDark),
                        const SizedBox(height: 16),
                        if (_isAdmin)
                          _buildAsesorCard(theme, isDark), // Only show if admin
                        const SizedBox(height: 16),
                        _buildNotasCard(theme, isDark),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                  _buildBottomBar(theme, isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildIntroCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.18), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isEdit ? 'Editar factura' : 'Nueva factura', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Rellena cliente, conceptos, descuentos e IVA. El total se calcula en tiempo real.', style: TextStyle(color: Colors.white.withOpacity(.86), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAsesorCard(ThemeData theme, bool isDark) {
    final saProv = Provider.of<SuperAdminProvider>(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Colors.indigo,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Asesor Asignado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: saProv.advisors.any((adv) => adv['_id'] == _selectedAsesorId)
                ? _selectedAsesorId
                : null,
            decoration: InputDecoration(
              hintText: 'Selecciona un asesor',
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            items: saProv.advisors.map((adv) {
              return DropdownMenuItem<String>(
                value: adv['_id'],
                child: Text(adv['nombre'] ?? 'Sin nombre'),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedAsesorId = value),
            validator: (value) => value == null ? 'Requerido' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildClienteCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Cliente',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingClientes)
            const Center(child: CircularProgressIndicator())
          else
            DropdownButtonFormField<Cliente>(
              value: _selectedCliente,
              decoration: InputDecoration(
                hintText: 'Selecciona un cliente',
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              items: _clientes.map((cliente) {
                return DropdownMenuItem<Cliente>(
                  value: cliente,
                  child: Text(cliente.nombre),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCliente = value;
                  if (value != null) {
                    // Autofill receptor data from selected client
                    _receptorNombreController.text = value.nombre;
                    _receptorNifController.text = value.nif ?? '';
                    _receptorDireccionController.text = value.direccion ?? '';
                    _receptorCPController.text = value.codigoPostal ?? '';
                    _receptorCiudadController.text = value.ciudad ?? '';
                    _receptorProvinciaController.text = value.provincia ?? '';
                  }
                });
              },
              validator: (value) => value == null ? 'Requerido' : null,
            ),
        ],
      ),
    );
  }

  Widget _buildReceptorCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business_outlined,
                  color: Colors.teal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Datos del Receptor',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildReceptorField(
            controller: _receptorNombreController,
            label: 'Nombre / Razón Social',
            icon: Icons.person_outline,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildReceptorField(
            controller: _receptorNifController,
            label: 'NIF / CIF',
            icon: Icons.badge_outlined,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildReceptorField(
            controller: _receptorDireccionController,
            label: 'Dirección',
            icon: Icons.location_on_outlined,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildReceptorField(
                  controller: _receptorCPController,
                  label: 'C.P.',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: _buildReceptorField(
                  controller: _receptorCiudadController,
                  label: 'Ciudad',
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildReceptorField(
            controller: _receptorProvinciaController,
            label: 'Provincia',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildReceptorField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    required bool isDark,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      validator: (value) => value?.isEmpty ?? true ? 'Requerido' : null,
    );
  }

  Widget _buildConceptoCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Colors.purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Concepto',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _conceptoController,
            decoration: InputDecoration(
              hintText: 'Ej: Servicios de asesoría - Enero 2024',
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Requerido' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDetallesCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Detalles',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _vencimiento,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) setState(() => _vencimiento = date);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_rounded, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vencimiento',
                        style: TextStyle(fontSize: 12, color: theme.hintColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_vencimiento.day}/${_vencimiento.month}/${_vencimiento.year}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _metodoPago,
            decoration: InputDecoration(
              labelText: 'Método de pago',
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'transferencia',
                child: Text('Transferencia'),
              ),
              DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
              DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
              DropdownMenuItem(value: 'bizum', child: Text('Bizum')),
            ],
            onChanged: (value) => setState(() => _metodoPago = value!),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.list_alt_rounded,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Conceptos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => setState(() => _items.add(FacturaItemForm())),
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('Añadir'),
              style: TextButton.styleFrom(
                foregroundColor: theme.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildItemCard(index, item, theme, isDark);
        }),
      ],
    );
  }

  Widget _buildItemCard(
    int index,
    FacturaItemForm item,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Concepto ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (_items.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => setState(() => _items.removeAt(index)),
                  color: Colors.red,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: item.descripcion,
            decoration: InputDecoration(
              labelText: 'Descripción',
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
              isDense: true,
            ),
            onChanged: (value) => item.descripcion = value,
            validator: (value) => value?.isEmpty ?? true ? 'Requerido' : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _compactNumberField(
                  initialValue: item.cantidad?.toString(),
                  label: 'Cant.',
                  isDark: isDark,
                  onChanged: (value) {
                    item.cantidad = int.tryParse(value.replaceAll(',', '.')) ?? 1;
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _compactNumberField(
                  initialValue: item.precioUnitario?.toString(),
                  label: 'Precio €',
                  isDark: isDark,
                  decimal: true,
                  onChanged: (value) {
                    item.precioUnitario = double.tryParse(value.replaceAll(',', '.')) ?? 0;
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _compactNumberField(
                  initialValue: item.descuento?.toStringAsFixed(0),
                  label: 'Dto %',
                  isDark: isDark,
                  decimal: true,
                  onChanged: (value) {
                    item.descuento = double.tryParse(value.replaceAll(',', '.')) ?? 0;
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<double>(
                  value: item.iva ?? 21,
                  decoration: InputDecoration(
                    labelText: 'IVA aplicado',
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                  items: [0.0, 4.0, 10.0, 21.0].map((val) => DropdownMenuItem<double>(value: val, child: Text('${val.toInt()}%'))).toList(),
                  onChanged: (val) => setState(() => item.iva = val ?? 21),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: theme.primaryColor.withOpacity(.08), borderRadius: BorderRadius.circular(12)),
                  child: Text('Línea: ${item.totalConIva.toStringAsFixed(2)}€', textAlign: TextAlign.center, style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactNumberField({
    required String? initialValue,
    required String label,
    required bool isDark,
    required ValueChanged<String> onChanged,
    bool decimal = false,
  }) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(12),
        isDense: true,
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      onChanged: onChanged,
      validator: (value) => value?.isEmpty ?? true ? 'Req.' : null,
    );
  }

  Widget _buildTotalsPreviewCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primaryColor.withOpacity(.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: theme.primaryColor.withOpacity(.10), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.calculate_outlined, color: theme.primaryColor),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Resumen económico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descuentoGlobalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Descuento global (%)',
              helperText: 'Se aplica antes del IVA, sobre la base imponible.',
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.percent_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _totalRow('Subtotal bruto', _subtotal, theme),
          _totalRow('Base imponible', _subtotalConDescuentos, theme),
          _totalRow('IVA', _totalIVA, theme),
          const Divider(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total factura', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text('${_total.toStringAsFixed(2)}€', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: theme.primaryColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.hintColor)),
          Text('${value.toStringAsFixed(2)}€', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildNotasCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notes_outlined,
                  color: Colors.grey[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Notas (opcional)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notasController,
            decoration: InputDecoration(
              hintText: 'Información adicional...',
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(fontSize: 14, color: theme.hintColor),
                    ),
                    Text(
                      '${_total.toStringAsFixed(2)}€',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveFactura,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _isEdit ? 'Actualizar' : 'Crear Factura',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Subtotal: ${_subtotal.toStringAsFixed(2)}€',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
                const SizedBox(width: 16),
                Text(
                  'IVA: ${_totalIVA.toStringAsFixed(2)}€',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _conceptoController.dispose();
    _notasController.dispose();
    _descuentoGlobalController.dispose();
    _receptorNombreController.dispose();
    _receptorNifController.dispose();
    _receptorDireccionController.dispose();
    _receptorCPController.dispose();
    _receptorCiudadController.dispose();
    _receptorProvinciaController.dispose();
    super.dispose();
  }
}

class FacturaItemForm {
  String descripcion = '';
  int? cantidad = 1;
  double? precioUnitario = 0;
  double? iva = 21;
  double? descuento = 0;

  double get base {
    return (cantidad ?? 0) * (precioUnitario ?? 0);
  }

  double get baseConDescuento {
    final d = ((descuento ?? 0).clamp(0, 100)).toDouble();
    return base * (1 - d / 100);
  }

  double get totalConIva {
    return baseConDescuento * (1 + ((iva ?? 21) / 100));
  }
}
