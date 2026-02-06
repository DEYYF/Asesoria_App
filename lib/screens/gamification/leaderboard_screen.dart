import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/gamification_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<dynamic> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final service = GamificationService(auth);

    final data = await service.getLeaderboard();
    if (mounted) {
      setState(() {
        _leaderboard = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ranking de Clientes"),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _leaderboard.isEmpty
          ? const Center(child: Text("No hay datos aún"))
          : ListView.builder(
              itemCount: _leaderboard.length,
              itemBuilder: (context, index) {
                final item = _leaderboard[index];
                final isTop3 = index < 3;
                final rank = index + 1;

                Color? rankColor;
                if (index == 0)
                  rankColor = Colors.amber;
                else if (index == 1)
                  rankColor = Colors.grey.shade400;
                else if (index == 2)
                  rankColor = Colors.orangeAccent.shade100;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: isTop3 ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: rankColor ?? Colors.blueGrey.shade50,
                      ),
                      child: Center(
                        child: Text(
                          "#$rank",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: rankColor != null
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      item['name'] ?? 'Anónimo',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "Nivel ${item['level']} • ${item['streak']} días racha",
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${item['points']} XP",
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
