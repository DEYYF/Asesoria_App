import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(String path) onSend;
  final VoidCallback onCancel;

  const VoiceRecorderWidget({
    super.key,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with SingleTickerProviderStateMixin {
  late AudioRecorder _audioRecorder;
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  bool _isRecording = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseScale = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startRecording();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String? path;

        if (!kIsWeb) {
          final dir = await getTemporaryDirectory();
          path =
              '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path ?? '',
        );

        setState(() {
          _isRecording = true;
        });
        _startTimer();
        _pulseController.repeat(reverse: true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Permiso de micrófono denegado")),
          );
        }
        widget.onCancel();
      }
    } catch (e) {
      debugPrint("Error starting recording: $e");
      if (mounted) {
        String msg = e.toString();
        if (msg.contains("MissingPluginException")) {
          msg =
              "Error: Debes reiniciar la aplicación (Stop & Run) después de añadir nuevas dependencias.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
        );
      }
      widget.onCancel();
    }
  }

  Future<void> _stopRecording({bool send = false}) async {
    _timer?.cancel();
    _pulseController.stop();

    try {
      final path = await _audioRecorder.stop();

      if (send && path != null) {
        widget.onSend(path);
      } else {
        widget.onCancel();
      }
    } catch (e) {
      debugPrint("Error stopping recording: $e");
      widget.onCancel();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseScale,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseScale.value,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Text(
            _formatDuration(_seconds),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            "Grabando...",
            style: TextStyle(color: theme.hintColor, fontSize: 13),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
            onPressed: () => _stopRecording(send: false),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _stopRecording(send: true),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
