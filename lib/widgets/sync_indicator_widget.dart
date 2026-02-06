import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/offline_sync_service.dart';

class SyncIndicatorWidget extends StatefulWidget {
  const SyncIndicatorWidget({super.key});

  @override
  State<SyncIndicatorWidget> createState() => _SyncIndicatorWidgetState();
}

class _SyncIndicatorWidgetState extends State<SyncIndicatorWidget>
    with SingleTickerProviderStateMixin {
  int _count = 0;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _checkCount();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkCount() async {
    if (!mounted) return;
    final syncService = Provider.of<OfflineSyncService>(context, listen: false);
    final count = await syncService.getQueueCount();

    if (mounted && count != _count) {
      setState(() {
        _count = count;
      });
    }

    // Check again in 5 seconds
    Future.delayed(const Duration(seconds: 5), _checkCount);
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: '$_count actualizaciones pendientes de sincronizar',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _controller,
                child: const Icon(
                  Icons.sync_rounded,
                  size: 14,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$_count',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
