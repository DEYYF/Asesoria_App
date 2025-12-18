import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../../models/progreso_model.dart';

// SVG Paths from HeatmapPanel.jsx
const bodyPaths = {
  'front': {
    'Traps': "M103,18 L115,22 L110,35 L90,35 L85,22 L97,18 Z",
    'Pectorals':
        "M75,45 Q100,55 125,45 Q135,60 125,80 Q100,85 75,80 Q65,60 75,45 Z",
    'Deltoids': "M60,40 Q50,55 55,70 L70,60 Z M140,40 Q150,55 145,70 L130,60 Z",
    'Biceps': "M55,70 Q50,90 55,100 L68,90 Z M145,70 Q150,90 145,100 L132,90 Z",
    'Forearms':
        "M50,100 Q45,125 50,135 L62,125 Z M150,100 Q155,125 150,135 L138,125 Z",
    'Abs': "M85,80 L115,80 L112,115 L88,115 Z",
    'Obliques':
        "M85,80 L72,100 L80,120 L88,115 Z M115,80 L128,100 L120,120 L112,115 Z",
    'Quads':
        "M80,120 Q70,170 80,210 L95,200 L90,125 Z M120,120 Q130,170 120,210 L105,200 L110,125 Z",
    'Calves':
        "M80,210 Q75,235 80,255 L90,245 Z M120,210 Q125,235 120,255 L110,245 Z",
  },
  'back': {
    'Traps': "M85,20 L115,20 L110,40 L90,40 Z",
    'Lats': "M80,40 L65,70 L85,90 L115,90 L135,70 L120,40 L110,40 L90,40 Z",
    'LowerBack': "M90,90 L110,90 L105,110 L95,110 Z",
    'Glutes': "M80,110 L120,110 Q130,135 120,150 L80,150 Q70,135 80,110 Z",
    'Hamstrings':
        "M80,150 Q75,185 80,210 L95,205 L90,150 Z M120,150 Q125,185 120,210 L105,205 L110,150 Z",
    'Calves':
        "M80,210 Q75,235 80,255 L90,245 Z M120,210 Q125,235 120,255 L110,245 Z",
    'Triceps': "M60,55 Q55,75 60,85 L70,75 Z M140,55 Q145,75 140,85 L130,75 Z",
    'RearDelts': "M60,40 L70,55 L60,55 Z M140,40 L130,55 L140,55 Z",
  },
};

const groupMapping = {
  "Pecho": ["front.Pectorals"],
  "Espalda": ["back.Lats", "back.LowerBack", "back.RearDelts"],
  "Trapecio": ["back.Traps", "front.Traps"],
  "Hombro": ["front.Deltoids", "back.RearDelts"],
  "Brazo": ["front.Biceps", "back.Triceps"],
  "Antebrazo": ["front.Forearms"],
  "Glúteo": ["back.Glutes"],
  "Cuádriceps": ["front.Quads"],
  "Femoral": ["back.Hamstrings"],
  "Pierna": [
    "front.Quads",
    "back.Hamstrings",
    "front.Calves",
    "back.Calves",
    "back.Glutes",
  ],
  "Gemelo": ["back.Calves", "front.Calves"],
  "CINTURA ANCHA": ["front.Obliques"],
  "CINTURA ESTRECHA": ["front.Abs"],
};

// Silhouette Base Path
const silhouettePath =
    "M100,5 Q125,5 140,25 L160,35 L170,100 L160,140 L140,230 L135,290 L115,310 L100,270 L85,310 L65,290 L60,230 L40,140 L30,100 L40,35 L60,25 Q75,5 100,5 Z";

class HeatmapPanel extends StatefulWidget {
  final List<Progreso> historial;

  const HeatmapPanel({super.key, required this.historial});

  @override
  State<HeatmapPanel> createState() => _HeatmapPanelState();
}

class _HeatmapPanelState extends State<HeatmapPanel> {
  Progreso? _selectedProgreso;

  // Hover state
  String? _hoveredPart;
  OverlayEntry? _overlayEntry;
  final Map<String, Path> _parsedPaths = {};

  @override
  void initState() {
    super.initState();
    if (widget.historial.isNotEmpty) {
      _selectedProgreso = widget.historial.last;
    }
    _parsePaths();
  }

  void _parsePaths() {
    for (var viewKey in bodyPaths.keys) {
      final parts = bodyPaths[viewKey]!;
      parts.forEach((key, svgString) {
        _parsedPaths['$viewKey.$key'] = parseSvgPathData(svgString);
      });
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HeatmapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.historial != oldWidget.historial &&
        widget.historial.isNotEmpty) {
      _selectedProgreso = widget.historial.last;
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay(BuildContext context, String text, Offset position) {
    _removeOverlay();
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: position.dy - 40,
        left: position.dx - 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  Color _getColor(String view, String part) {
    if (_selectedProgreso == null || _selectedProgreso!.musculo == null)
      return Colors.grey.shade300;

    final fullPart = '$view.$part';

    for (var m in _selectedProgreso!.musculo!) {
      final affectedParts = groupMapping[m.nombre] ?? [];
      if (affectedParts.contains(fullPart)) {
        if (_hoveredPart == fullPart)
          return Colors.blue.shade700; // Highlight on hover
        return Colors.blue;
      }
    }
    return _hoveredPart == fullPart
        ? Colors.grey.shade400
        : Colors.grey.shade300;
  }

  String? _getValue(String view, String part) {
    if (_selectedProgreso == null || _selectedProgreso!.musculo == null)
      return null;

    final fullPart = '$view.$part';
    for (var m in _selectedProgreso!.musculo!) {
      final affectedParts = groupMapping[m.nombre] ?? [];
      if (affectedParts.contains(fullPart)) {
        return '${m.nombre}: ${m.medida} cm';
      }
    }
    return null;
  }

  void _handleHover(
    PointerEvent event,
    String viewKey,
    BoxConstraints constraints,
  ) {
    final scaleX = 120.0 / 200.0;
    final scaleY = 200.0 / 320.0;

    final localDx = event.localPosition.dx / scaleX;
    final localDy = event.localPosition.dy / scaleY;
    final point = Offset(localDx, localDy);

    String? hitPart;

    final parts = bodyPaths[viewKey]!;
    for (var key in parts.keys) {
      final fullKey = '$viewKey.$key';
      final path = _parsedPaths[fullKey];
      if (path != null && path.contains(point)) {
        hitPart = fullKey;
        break;
      }
    }

    if (hitPart != _hoveredPart) {
      setState(() {
        _hoveredPart = hitPart;
      });

      if (hitPart != null) {
        final parts = hitPart!.split('.');
        final val = _getValue(parts[0], parts[1]);
        if (val != null) {
          _showOverlay(context, val, event.position);
        } else {
          _removeOverlay();
        }
      } else {
        _removeOverlay();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Mapa Corporal",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (widget.historial.isNotEmpty)
                  DropdownButton<Progreso>(
                    value: _selectedProgreso,
                    underline: Container(),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    onChanged: (val) {
                      setState(() => _selectedProgreso = val);
                      _hoveredPart = null;
                      _removeOverlay();
                    },
                    items: widget.historial
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              '${p.fecha.day}/${p.fecha.month}/${p.fecha.year}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
            if (widget.historial.isEmpty)
              const Text(
                "No hay registros",
                style: TextStyle(color: Colors.grey),
              ),

            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem(Colors.grey.shade300, "Sin dato"),
                const SizedBox(width: 16),
                _legendItem(Colors.blue, "Registrado"),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildView('FRONTAL', 'front'),
                const SizedBox(width: 24),
                _buildView('TRASERO', 'back'),
              ],
            ),
            if (_selectedProgreso != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _buildDataTable(_selectedProgreso!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(Progreso p) {
    final weightStr = p.peso != null ? '${p.peso} kg' : '-';
    final fatStr = p.grasaCorporal != null ? '${p.grasaCorporal}%' : '-';

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _dataItem("Peso", weightStr, Icons.fitness_center)),
            const SizedBox(width: 12),
            Expanded(child: _dataItem("Grasa", fatStr, Icons.water_drop)),
          ],
        ),
        if (p.musculo != null && p.musculo!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Medidas musculares",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: p.musculo!.map((m) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${m.nombre}: ",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "${m.medida} cm",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _dataItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildView(String label, String viewKey) {
    return Column(
      children: [
        MouseRegion(
          onHover: (event) => _handleHover(
            event,
            viewKey,
            const BoxConstraints(maxWidth: 120, maxHeight: 200),
          ),
          onExit: (_) {
            setState(() => _hoveredPart = null);
            _removeOverlay();
          },
          child: CustomPaint(
            size: const Size(120, 200),
            painter: BodyPainter(
              silhouette: silhouettePath,
              parts: bodyPaths[viewKey]!,
              getColor: (part) => _getColor(viewKey, part),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class BodyPainter extends CustomPainter {
  final String silhouette;
  final Map<String, String> parts;
  final Color Function(String) getColor;

  BodyPainter({
    required this.silhouette,
    required this.parts,
    required this.getColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Scale to fit 200x320 coord system of SVG to container size
    final scaleX = size.width / 200;
    final scaleY = size.height / 320;
    canvas.scale(scaleX, scaleY);

    final paint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 1.5;

    // Silhouette
    final silPath = parseSvgPathData(silhouette);
    canvas.drawPath(silPath, paint..color = Colors.grey.shade200);
    canvas.drawPath(silPath, strokePaint..color = Colors.blueGrey.shade100);

    // Parts
    parts.forEach((key, pathData) {
      final path = parseSvgPathData(pathData);
      final color = getColor(key);
      canvas.drawPath(path, paint..color = color);
      canvas.drawPath(path, strokePaint..color = Colors.white);
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
