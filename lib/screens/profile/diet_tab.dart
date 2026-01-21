import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/dieta_model.dart';
import '../diet/diet_detail_screen.dart';
import 'shopping_list_screen.dart';

class DietTab extends StatefulWidget {
  final String clienteId;
  const DietTab({super.key, required this.clienteId});

  @override
  State<DietTab> createState() => _DietTabState();
}

class _DietTabState extends State<DietTab> {
  List<Dieta> _dietas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDietas();
  }

  Future<void> _loadDietas() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get(
        '/dietas?clienteId=${widget.clienteId}&isCurrent=true',
      );

      if (mounted) {
        if (res.statusCode == 200) {
          final List list = jsonDecode(res.body);
          setState(() {
            _dietas = list.map((e) => Dieta.fromJson(e)).toList();
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFD700)),
      );
    }

    final theme = Theme.of(context);

    if (_dietas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              size: 64,
              color: theme.hintColor.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            Text(
              'Aún no hay dietas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: theme.hintColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea la primera dieta para este cliente',
              style: TextStyle(
                color: theme.hintColor.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final auth = Provider.of<AuthService>(context, listen: false);
                if (auth.isClient) return const SizedBox.shrink();
                return ElevatedButton.icon(
                  onPressed: () =>
                      context.push('/clientes/${widget.clienteId}/crear-dieta'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Comenzar Plan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    final currentDiet = _dietas.first;

    return RefreshIndicator(
      onRefresh: _loadDietas,
      color: theme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu Nutrición',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: theme.textTheme.headlineMedium?.color,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Resumen de tu plan actual',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.hintColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                Builder(
                  builder: (context) {
                    final auth = Provider.of<AuthService>(
                      context,
                      listen: false,
                    );
                    if (auth.isClient) return const SizedBox.shrink();
                    return _buildAddButton(theme);
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),
            _buildMacroDashboard(currentDiet, theme),
            const SizedBox(height: 24),
            _buildShoppingListButton(currentDiet, theme),
            const SizedBox(height: 40),
            Text(
              'Planes de Alimentación',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.textTheme.titleLarge?.color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _dietas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _buildDietaCard(_dietas[index]);
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(ThemeData theme) {
    return GestureDetector(
      onTap: () => context.push('/clientes/${widget.clienteId}/crear-dieta'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.add_rounded, color: theme.primaryColor),
      ),
    );
  }

  Widget _buildMacroDashboard(Dieta dieta, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroCircle(
                'Proteínas',
                '${dieta.macros.proteinas.toInt()}g',
                Colors.blue,
                0.8,
              ),
              _buildMacroCircle(
                'Carbos',
                '${dieta.macros.carbohidratos.toInt()}g',
                Colors.orange,
                0.6,
              ),
              _buildMacroCircle(
                'Grasas',
                '${dieta.macros.grasas.toInt()}g',
                Colors.purple,
                0.4,
              ),
            ],
          ),
          const SizedBox(height: 30),
          Divider(color: theme.dividerColor.withOpacity(0.05)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: Colors.orangeAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${dieta.macros.kcal.toInt()}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'kcal diarias',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.hintColor.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCircle(
    String label,
    String value,
    Color color,
    double percent,
  ) {
    return Column(
      children: [
        SizedBox(
          height: 60,
          width: 60,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: percent,
                strokeWidth: 6,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Center(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildDietaCard(Dieta dieta) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () {
            if (dieta.id != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DietDetailScreen(dietaId: dieta.id!),
                ),
              );
            }
          },
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor,
                        theme.primaryColor.withOpacity(0.5),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                dieta.nombre,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: theme.textTheme.titleMedium?.color,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (dieta.objetivo != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  dieta.objetivo!.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _CompactInfo(
                              icon: Icons.local_fire_department_rounded,
                              label: '${dieta.macros.kcal.toInt()} kcal',
                              color: Colors.orangeAccent,
                            ),
                            const SizedBox(width: 16),
                            _CompactInfo(
                              icon: Icons.calendar_today_rounded,
                              label: dieta.createdAt != null
                                  ? DateFormat('dd/MM').format(dieta.createdAt!)
                                  : 'Reciente',
                              color: theme.hintColor.withOpacity(0.6),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.dividerColor),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShoppingListButton(Dieta dieta, ThemeData theme) {
    return InkWell(
      onTap: () {
        if (dieta.id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShoppingListScreen(
                dietaId: dieta.id!,
                dietaNombre: dieta.nombre,
                clienteId: widget.clienteId,
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_checkout_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lista de la Compra',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Generar desde este plan',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CompactInfo({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}
