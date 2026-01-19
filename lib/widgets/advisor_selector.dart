import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/super_admin_provider.dart';
import '../services/auth_service.dart';

class AdvisorSelector extends StatefulWidget {
  const AdvisorSelector({super.key});

  @override
  State<AdvisorSelector> createState() => _AdvisorSelectorState();
}

class _AdvisorSelectorState extends State<AdvisorSelector> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saProvider = Provider.of<SuperAdminProvider>(
        context,
        listen: false,
      );
      if (saProvider.advisors.isEmpty) {
        saProvider.loadAdvisors();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    if (!auth.isSuperAdmin) return const SizedBox.shrink();

    final saProvider = Provider.of<SuperAdminProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.1),
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
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: saProvider.selectedAdvisorId,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.primaryColor,
          ),
          dropdownColor: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Row(
                children: [
                  Icon(
                    Icons.public_rounded,
                    size: 20,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Vista Global (Todos)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
            ),
            ...saProvider.advisors.map((advisor) {
              return DropdownMenuItem<String?>(
                value: advisor['_id'],
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.primaryColor.withOpacity(0.1),
                      child: Text(
                        (advisor['nombre'] ?? '?')[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      advisor['nombre'] ?? 'Asesor',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
          onChanged: (val) {
            saProvider.selectAdvisor(val);
          },
        ),
      ),
    );
  }
}
