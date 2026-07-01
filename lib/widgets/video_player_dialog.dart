import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/notification_helper.dart';

class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerDialog({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  YoutubePlayerController? _controller;
  Timer? _loadingTimer;

  bool _isYoutube = false;
  bool _playerReady = false;
  bool _loadTimedOut = false;
  String? _videoId;

  @override
  void initState() {
    super.initState();
    _videoId = _extractYoutubeId(widget.videoUrl);
    _isYoutube = _videoId != null && _videoId!.isNotEmpty;

    if (_isYoutube) {
      _controller = YoutubePlayerController(
        initialVideoId: _videoId!,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          forceHD: false,
          enableCaption: false,
          controlsVisibleAtStart: true,
          hideThumbnail: false,
        ),
      );

      _loadingTimer = Timer(const Duration(seconds: 7), () {
        if (!mounted || _playerReady) return;
        setState(() => _loadTimedOut = true);
      });
    }
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  String? _extractYoutubeId(String rawUrl) {
    final url = rawUrl.trim();
    if (url.isEmpty) return null;

    final fromPackage = YoutubePlayer.convertUrlToId(url);
    if (fromPackage != null && fromPackage.isNotEmpty) return fromPackage;

    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final host = uri.host.toLowerCase().replaceFirst('www.', '');

    if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }

    if (host.contains('youtube.com')) {
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) return v;

      if (uri.pathSegments.isNotEmpty) {
        final segments = uri.pathSegments;
        final shortsIndex = segments.indexOf('shorts');
        if (shortsIndex != -1 && segments.length > shortsIndex + 1) {
          return segments[shortsIndex + 1];
        }

        final embedIndex = segments.indexOf('embed');
        if (embedIndex != -1 && segments.length > embedIndex + 1) {
          return segments[embedIndex + 1];
        }
      }
    }

    return null;
  }

  Future<void> _launchUrl() async {
    final url = Uri.tryParse(widget.videoUrl.trim());
    if (url == null) {
      if (mounted) {
        NotificationHelper.showError(context, 'El enlace del vídeo no es válido');
      }
      return;
    }

    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      NotificationHelper.showError(context, 'No se pudo abrir el enlace');
    }
  }

  void _retryYoutube() {
    if (!_isYoutube || _videoId == null) return;

    _loadingTimer?.cancel();
    _controller?.dispose();

    setState(() {
      _playerReady = false;
      _loadTimedOut = false;
      _controller = YoutubePlayerController(
        initialVideoId: _videoId!,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          forceHD: false,
          enableCaption: false,
          controlsVisibleAtStart: true,
          hideThumbnail: false,
        ),
      );
    });

    _loadingTimer = Timer(const Duration(seconds: 7), () {
      if (!mounted || _playerReady) return;
      setState(() => _loadTimedOut = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white54,
                      ),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 24,
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _isYoutube && _controller != null
                      ? _buildYoutubePlayer()
                      : _buildExternalVideoFallback(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYoutubePlayer() {
    return Stack(
      fit: StackFit.expand,
      children: [
        YoutubePlayer(
          controller: _controller!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.redAccent,
          progressColors: const ProgressBarColors(
            playedColor: Colors.redAccent,
            handleColor: Colors.white,
          ),
          onReady: () {
            if (!mounted) return;
            _loadingTimer?.cancel();
            setState(() => _playerReady = true);
            _controller?.play();
          },
          onEnded: (_) {},
        ),
        if (!_playerReady && !_loadTimedOut)
          Container(
            color: Colors.black.withOpacity(0.35),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            ),
          ),
        if (_loadTimedOut) _buildYoutubeTimeoutFallback(),
      ],
    );
  }

  Widget _buildYoutubeTimeoutFallback() {
    return Container(
      color: Colors.black.withOpacity(0.88),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_tethering_error_rounded,
            size: 42,
            color: Colors.white38,
          ),
          const SizedBox(height: 12),
          const Text(
            'El vídeo está tardando en cargar',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Puedes reintentarlo o abrirlo fuera de la app.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _retryYoutube,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('REINTENTAR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _launchUrl,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('ABRIR VÍDEO'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExternalVideoFallback() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library_rounded,
            size: 48,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          const Text(
            'Contenido externo',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Este formato se abrirá fuera de la app.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _launchUrl,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('VER VÍDEO'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
