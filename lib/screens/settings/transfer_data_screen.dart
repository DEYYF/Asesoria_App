import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class Advisor {
  final String id;
  final String nombre;
  Advisor({required this.id, required this.nombre});

  factory Advisor.fromJson(Map<String, dynamic> json) {
    return Advisor(
      id: json['_id'] ?? '',
      nombre: json['nombre'] ?? 'Sin Nombre',
    );
  }
}

class TransferDataScreen extends StatefulWidget {
  const TransferDataScreen({super.key});

  @override
  State<TransferDataScreen> createState() => _TransferDataScreenState();
}

class _TransferDataScreenState extends State<TransferDataScreen> {
  bool _isLoading = false;
  List<Advisor> _advisors = [];

  String? _fromAdvisorId;
  String? _toAdvisorId;

  // Selected modules
  bool _clients = true;
  bool _automations = true;
  bool _tasks = true;
  bool _budgets = true;
  bool _finance = true;
  bool _appointments = true;

  @override
  void initState() {
    super.initState();
    _loadAdvisors();
  }

  Future<void> _loadAdvisors() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final response = await api.get('/users');
      // Assuming GET /api/users returns List<dynamic> of users for superadmin

      if (response.statusCode == 200) {
        final List<dynamic> data = await api.parseJsonResponse(response);
        setState(() {
          _advisors = data.map((json) => Advisor.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando asesores: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _transferData() async {
    if (_fromAdvisorId == null || _toAdvisorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona origen y destino')),
      );
      return;
    }

    if (_fromAdvisorId == _toAdvisorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El origen y destino deben ser diferentes'),
        ),
      );
      return;
    }

    final modules = <String>[];
    if (_clients) modules.add('clients');
    if (_automations) modules.add('automations');
    if (_tasks) modules.add('tasks');
    if (_budgets) modules.add('budgets');
    if (_finance) modules.add('finance');
    if (_appointments) modules.add('appointments');

    if (modules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un módulo')),
      );
      return;
    }

    // Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Transferencia'),
        content: const Text(
          'Esta acción transferirá la propiedad de todos los elementos seleccionados del asesor origen al asesor destino. Esta acción es irreversible.\n\n¿Estás seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Transferir Datos',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.post('/users/transfer-data', {
        'fromAdvisorId': _fromAdvisorId,
        'toAdvisorId': _toAdvisorId,
        'modules': modules,
      });

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transferencia completada con éxito'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error en transferencia: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transferir Datos')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transferencia de Cartera',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mueve clientes, tareas y otros datos de un asesor a otro.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // Advisors Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _fromAdvisorId,
                            decoration: const InputDecoration(
                              labelText: 'Asesor Origen (Desde)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_remove_rounded),
                            ),
                            items: _advisors.map((u) {
                              return DropdownMenuItem(
                                value: u.id,
                                child: Text(u.nombre),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _fromAdvisorId = val),
                          ),
                          const SizedBox(height: 16),
                          const Icon(
                            Icons.arrow_downward_rounded,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _toAdvisorId,
                            decoration: const InputDecoration(
                              labelText: 'Asesor Destino (Para)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_add_alt_1_rounded),
                            ),
                            items: _advisors.map((u) {
                              return DropdownMenuItem(
                                value: u.id,
                                child: Text(u.nombre),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _toAdvisorId = val),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Datos a Transferir',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  Card(
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: _clients,
                          title: const Text('Clientes'),
                          subtitle: const Text(
                            'Perfiles completos de clientes',
                          ),
                          secondary: const Icon(Icons.people_alt_rounded),
                          onChanged: (v) => setState(() => _clients = v!),
                        ),
                        CheckboxListTile(
                          value: _automations,
                          title: const Text('Automatizaciones'),
                          subtitle: const Text('Reglas automáticas creadas'),
                          secondary: const Icon(Icons.auto_fix_high_rounded),
                          onChanged: (v) => setState(() => _automations = v!),
                        ),
                        CheckboxListTile(
                          value: _tasks,
                          title: const Text('Tareas'),
                          subtitle: const Text('Tareas asignadas en Kanban'),
                          secondary: const Icon(Icons.task_alt_rounded),
                          onChanged: (v) => setState(() => _tasks = v!),
                        ),
                        CheckboxListTile(
                          value: _budgets,
                          title: const Text('Presupuestos'),
                          subtitle: const Text('Historial de presupuestos'),
                          secondary: const Icon(Icons.receipt_long_rounded),
                          onChanged: (v) => setState(() => _budgets = v!),
                        ),
                        CheckboxListTile(
                          value: _finance,
                          title: const Text('Finanzas'),
                          subtitle: const Text(
                            'Movimientos financieros registrados',
                          ),
                          secondary: const Icon(Icons.attach_money_rounded),
                          onChanged: (v) => setState(() => _finance = v!),
                        ),
                        CheckboxListTile(
                          value: _appointments,
                          title: const Text('Citas'),
                          subtitle: const Text('Citas programadas y pasadas'),
                          secondary: const Icon(Icons.calendar_today_rounded),
                          onChanged: (v) => setState(() => _appointments = v!),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _transferData,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('TRANSFERIR DATOS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
