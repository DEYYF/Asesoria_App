import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/gamification_service.dart';

class GamificationStatsCard extends StatefulWidget {
  final String clientId;
  final VoidCallback onTap;

  const GamificationStatsCard({
    Key? key,
    required this.clientId,
    required this.onTap,
  }) : super(key: key);

  @override
  State<GamificationStatsCard> createState() => _GamificationStatsCardState();
}

class _GamificationStatsCardState extends State<GamificationStatsCard> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Load data after first frame to access context/providers safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final service = GamificationService(auth);

    final stats = await service.getClientStats(widget.clientId);
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink(); // Don't show if loading
    if (_stats == null || _stats!.isEmpty) return const SizedBox.shrink();

    final points = _stats!['points'] ?? 0;
    final level = _stats!['level'] ?? 1;
    final levelName = _stats!['levelName'] ?? 'Novato';
    final streak = _stats!['streak'] ?? 0;
    final nextLevelPoints = _stats!['nextLevelPoints'] ?? points + 1000;

    double progress = 0.0;
    if (nextLevelPoints > 0) {
      progress = points / nextLevelPoints;
      if (progress > 1.0) progress = 1.0;
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Gradient background for "premium" feel
          gradient: LinearGradient(
            colors: [Colors.indigo.shade800, Colors.deepPurple.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Level Badge
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.amber.shade600,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Colors.amber, blurRadius: 6),
                ],
              ),
              child: Center(
                child: Text(
                  "$level",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        levelName.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.orangeAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$streak días",
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.amber.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$points / $nextLevelPoints XP",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
