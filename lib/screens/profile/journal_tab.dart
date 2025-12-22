import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/cliente_model.dart';
import '../../services/api_service.dart';
import '../../utils/isolate_utils.dart';
import 'package:provider/provider.dart';

class JournalTab extends StatefulWidget {
  final Cliente cliente;

  const JournalTab({super.key, required this.cliente});

  @override
  State<JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends State<JournalTab> {
  bool _isLoading = true;

  // Data: DateTime (Day) -> Session data with exercises
  Map<DateTime, Map<String, dynamic>> _sessionsMap = {};

  // Data: DateTime (Month start) -> List of Days in that month
  Map<DateTime, List<DateTime>> _monthsMap = {};
  List<DateTime> _sortedMonths = [];

  // Navigation State
  bool _showMonthGrid = true;
  DateTime? _selectedMonth;
  List<DateTime> _currentMonthDays = [];
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
    _loadFullHistory();
  }

  Future<void> _loadFullHistory() async {
    final api = Provider.of<ApiService>(context, listen: false);

    try {
      // Fetch all training session records for this client
      debugPrint('🔍 Fetching sessions for client: ${widget.cliente.id}');
      final res = await api.get(
        '/entrenamientos/registros/cliente/${widget.cliente.id}/sesiones',
      );

      debugPrint('📡 Response status: ${res.statusCode}');

      if (res.statusCode != 200) {
        debugPrint(
          '❌ Failed to load sessions: ${res.statusCode} - ${res.body}',
        );
        throw Exception('Failed to load sessions');
      }

      // Process session history in isolate for better performance
      final result = await processSessionHistoryInIsolate(res.body);
      debugPrint('✅ Processed ${result.sessionsMap.length} unique dates');

      // Convert string-based maps to DateTime-based maps
      Map<DateTime, Map<String, dynamic>> sessionsMap = {};
      result.sessionsMap.forEach((key, value) {
        sessionsMap[DateTime.parse(key)] = value as Map<String, dynamic>;
      });

      Map<DateTime, List<DateTime>> monthsMap = {};
      result.monthsMap.forEach((monthKey, dates) {
        final month = DateTime.parse(monthKey);
        monthsMap[month] = dates.map((d) => DateTime.parse(d)).toList();
      });

      final sortedMonths = result.sortedMonths
          .map((s) => DateTime.parse(s))
          .toList();

      setState(() {
        _sessionsMap = sessionsMap;
        _monthsMap = monthsMap;
        _sortedMonths = sortedMonths;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('💥 Error loading full history: $e');
      setState(() => _isLoading = false);
    }
  }

  void _openMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      _showMonthGrid = false;
      _currentMonthDays = _monthsMap[month] ?? [];
    });
  }

  void _backToGrid() {
    setState(() {
      _showMonthGrid = true;
      _selectedMonth = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_sortedMonths.isEmpty) {
      return _buildEmptyJournal();
    }

    return Container(
      color: const Color(0xFFE5E5EA),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _showMonthGrid ? _buildMonthGrid() : _buildPagesView(),
      ),
    );
  }

  Widget _buildMonthGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _sortedMonths.length,
        itemBuilder: (context, index) {
          final month = _sortedMonths[index];
          return GestureDetector(
            onTap: () => _openMonth(month),
            child: _buildNotebookCover(month),
          );
        },
      ),
    );
  }

  Widget _buildNotebookCover(DateTime month) {
    final monthName = DateFormat('MMMM', 'es').format(month).toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 4)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 20,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E),
                border: Border(right: BorderSide(color: Colors.white12)),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  monthName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${month.year}',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagesView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFFE5E5EA),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  size: 18,
                  color: Colors.blue,
                ),
                onPressed: _backToGrid,
              ),
              Text(
                _selectedMonth != null
                    ? DateFormat(
                        'MMMM yyyy',
                      ).format(_selectedMonth!).toUpperCase()
                    : '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _currentMonthDays.length,
            itemBuilder: (context, index) {
              final date = _currentMonthDays[index];
              return _buildNotebookPage(date, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotebookPage(DateTime date, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFBF7),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          gradient: const LinearGradient(
            colors: [Color(0xFFE0E0E0), Color(0xFFFDFBF7), Color(0xFFFDFBF7)],
            stops: [0.0, 0.05, 1.0],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: NotebookPainter())),
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEEE').format(date).toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        DateFormat('MMM d, y').format(date),
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF2C2C2E),
                        ),
                      ),
                    ],
                  ),
                  const Divider(
                    height: 30,
                    thickness: 2,
                    color: Colors.black12,
                  ),

                  Expanded(child: _buildSessionContent(date)),
                ],
              ),
            ),

            if (_getSessionNote(date) != null)
              Positioned(
                bottom: 40,
                right: 20,
                child: _buildPostIt(_getSessionNote(date)!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionContent(DateTime date) {
    final sessionData = _sessionsMap[date];
    if (sessionData == null) return const SizedBox();

    final ejercicios = sessionData['ejercicios'] as List<dynamic>;

    return ListView.builder(
      itemCount: ejercicios.length,
      itemBuilder: (context, i) {
        final ejercicio = ejercicios[i];
        final nombre = ejercicio['ejercicioNombre'] ?? 'Ejercicio';
        final series = ejercicio['series'] as List<dynamic>? ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exercise Title
              Text(
                nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF3A3A3C),
                ),
              ),
              const SizedBox(height: 6),
              // Sets List
              if (series.isNotEmpty)
                ...series.asMap().entries.map((entry) {
                  final setNum = entry.key + 1;
                  final s = entry.value;
                  final peso = s['peso'] ?? 0;
                  final reps = s['reps'] ?? 0;
                  final rir = s['rir'];

                  return Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$setNum',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF555555),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$peso kg × $reps reps',
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 13,
                            color: Color(0xFF555555),
                          ),
                        ),
                        if (rir != null && rir > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            'RIR: $rir',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList()
              else
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    'Sin datos',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      color: Colors.grey.shade400,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostIt(String text) {
    return Transform.rotate(
      angle: -0.05,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9C4),
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.push_pin, size: 16, color: Colors.redAccent),
            const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(
                fontFamily: 'Kalam',
                fontSize: 12,
                color: Color(0xFF4A4A4A),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _getSessionNote(DateTime date) {
    final sessionData = _sessionsMap[date];
    if (sessionData == null) return null;

    final comentarios = sessionData['comentarios'] as String?;
    if (comentarios != null && comentarios.isNotEmpty) {
      return comentarios;
    }

    return null;
  }

  Widget _buildEmptyJournal() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Libreta vacía', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class NotebookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.1)
      ..strokeWidth = 1.0;

    double y = 80;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += 30;
    }

    final marginPaint = Paint()
      ..color = Colors.red.withOpacity(0.1)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(32, 0), Offset(32, size.height), marginPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
