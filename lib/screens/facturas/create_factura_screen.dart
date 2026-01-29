import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cliente_model.dart';
import '../../services/factura_service.dart';
import '../../services/api_service.dart';
import '../../services/client_service.dart';
import '../../services/auth_service.dart';
import '../../providers/super_admin_provider.dart';

class CreateFacturaScreen extends StatefulWidget {
  const CreateFacturaScreen({super.key});

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

  bool get _isAdmin =>
      Provider.of<AuthService>(context, listen: false).isSuperAdmin;

  DateTime _vencimiento = DateTime.now().add(const Duration(days: 30));
  String _metodoPago = 'transferencia';

  List<FacturaItemForm> _items = [FacturaItemForm()];

  bool _isLoading = false;
  bool _loadingClientes = true;
  String? _selectedAsesorId;

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

    _loadClientes();
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

  double get _totalIVA {
    return _items.fold(0.0, (sum, item) {
      final base = (item.cantidad ?? 0) * (item.precioUnitario ?? 0);
      final iva = base * ((item.iva ?? 21) / 100);
      return sum + iva;
    });
  }

  double get _total => _subtotal + _totalIVA;

  Future<void> _createFactura() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCliente == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona un cliente')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final facturaData = {
        'clienteId': _selectedCliente!.id,
        'concepto': _conceptoController.text,
        'items': _items.map((item) {
          final base = (item.cantidad ?? 0) * (item.precioUnitario ?? 0);
          final iva = base * ((item.iva ?? 21) / 100);
          return {
            'descripcion': item.descripcion,
            'cantidad': item.cantidad,
            'precioUnitario': item.precioUnitario,
            'iva': item.iva ?? 21,
            'descuento': 0,
            'total': base + iva,
          };
        }).toList(),
        'vencimiento': _vencimiento.toIso8601String(),
        'metodoPago': _metodoPago,
        'notas': _notasController.text.isNotEmpty
            ? _notasController.text
            : null,
        'asesorId': _selectedAsesorId,
      };

      await _facturaService.createFactura(facturaData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Factura creada correctamente')),
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
        title: const Text(
          'Nueva Factura',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildClienteCard(theme, isDark),
                  const SizedBox(height: 16),
                  _buildConceptoCard(theme, isDark),
                  const SizedBox(height: 16),
                  _buildDetallesCard(theme, isDark),
                  const SizedBox(height: 16),
                  _buildItemsSection(theme, isDark),
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
              onChanged: (value) => setState(() => _selectedCliente = value),
              validator: (value) => value == null ? 'Requerido' : null,
            ),
        ],
      ),
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
                child: TextFormField(
                  initialValue: item.cantidad?.toString(),
                  decoration: InputDecoration(
                    labelText: 'Cant.',
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
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    item.cantidad = int.tryParse(value) ?? 1;
                    setState(() {});
                  },
                  validator: (value) => value?.isEmpty ?? true ? 'Req.' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: item.precioUnitario?.toString(),
                  decoration: InputDecoration(
                    labelText: 'Precio €',
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (value) {
                    item.precioUnitario = double.tryParse(value) ?? 0;
                    setState(() {});
                  },
                  validator: (value) => value?.isEmpty ?? true ? 'Req.' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item.iva?.toString() ?? '21',
                  decoration: InputDecoration(
                    labelText: 'IVA %',
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
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    item.iva = double.tryParse(value) ?? 21;
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
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
                  onPressed: _isLoading ? null : _createFactura,
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
                      : const Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Crear Factura',
                              style: TextStyle(
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
    super.dispose();
  }
}

class FacturaItemForm {
  String descripcion = '';
  int? cantidad = 1;
  double? precioUnitario = 0;
  double? iva = 21;
}
