import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/dieta_model.dart';
import '../diet/diet_detail_screen.dart';

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
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_dietas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Aún no hay dietas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea la primera dieta para este cliente',
              style: TextStyle(color: theme.hintColor),
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final auth = Provider.of<AuthService>(context, listen: false);
                if (auth.isClient) return const SizedBox.shrink();
                return ElevatedButton.icon(
                  onPressed: () =>
                      context.push('/clientes/${widget.clienteId}/crear-dieta'),
                  icon: const Icon(Icons.add),
                  label: const Text('Crear dieta'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dietas asignadas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              Builder(
                builder: (context) {
                  final auth = Provider.of<AuthService>(context, listen: false);
                  if (auth.isClient) return const SizedBox.shrink();
                  return ElevatedButton.icon(
                    onPressed: () => context.push(
                      '/clientes/${widget.clienteId}/crear-dieta',
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva dieta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_dietas.length == 1)
            SizedBox(
              height: 140,
              width: double.infinity,
              child: _buildDietaCard(_dietas.first),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: _dietas.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 260,
                    child: _buildDietaCard(_dietas[index]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDietaCard(Dieta dieta) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
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
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor,
                        theme.primaryColor.withOpacity(0.5),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dieta.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _CompactChip(
                          label: '${dieta.macros.kcal.toInt()} kcal',
                          icon: Icons.local_fire_department_rounded,
                          iconColor: Colors.orangeAccent,
                        ),
                        if (dieta.objetivo != null) ...[
                          const SizedBox(width: 8),
                          _CompactChip(
                            label: dieta.objetivo!,
                            icon: Icons.track_changes_rounded,
                            iconColor: theme.primaryColor,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;

  const _CompactChip({
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
