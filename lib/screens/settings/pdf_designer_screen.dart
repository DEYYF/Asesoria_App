import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/settings_model.dart';
import '../../utils/notification_helper.dart';
import 'widgets/settings_widgets.dart';

class PdfDesignerScreen extends StatefulWidget {
  const PdfDesignerScreen({super.key});

  @override
  State<PdfDesignerScreen> createState() => _PdfDesignerScreenState();
}

class _PdfDesignerScreenState extends State<PdfDesignerScreen> {
  late TextEditingController _headerController;
  late TextEditingController _footerController;
  late TextEditingController _footerContactController;
  late TextEditingController _logoController;
  late PdfSettings _workingSettings;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).settings;
    _workingSettings = settings?.pdfSettings ?? PdfSettings();
    _headerController = TextEditingController(
      text: _workingSettings.headerTitle,
    );
    _footerController = TextEditingController(
      text: _workingSettings.footerText,
    );
    _footerContactController = TextEditingController(
      text: _workingSettings.footerContactInfo,
    );
    _logoController = TextEditingController(text: _workingSettings.logoUrl);
  }

  @override
  void dispose() {
    _headerController.dispose();
    _footerController.dispose();
    _footerContactController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final provider = Provider.of<SettingsProvider>(context, listen: false);

    final updatedPdf = _workingSettings.copyWith(
      headerTitle: _headerController.text,
      footerText: _footerController.text,
      footerContactInfo: _footerContactController.text,
      logoUrl: _logoController.text,
    );

    try {
      if (provider.settings != null) {
        await provider.updateSettings(
          provider.settings!.copyWith(pdfSettings: updatedPdf),
        );
        if (mounted) {
          NotificationHelper.showSuccess(
            context,
            'Diseño guardado correctamente',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(context, 'Error al guardar: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          'Diseñador de PDF',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text(
                'GUARDAR',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('PREVISUALIZACIÓN EN VIVO'),
            _buildLivePreview(isDark),
            const SizedBox(height: 32),

            _buildSectionHeader('IDENTIDAD VISUAL'),
            SettingsGroup(
              children: [
                _buildColorPickerTile(
                  'Color Principal',
                  _workingSettings.primaryColor,
                  (c) {
                    setState(
                      () => _workingSettings = _workingSettings.copyWith(
                        primaryColor: c,
                      ),
                    );
                  },
                ),
                _buildColorPickerTile(
                  'Color Secundario',
                  _workingSettings.secondaryColor,
                  (c) {
                    setState(
                      () => _workingSettings = _workingSettings.copyWith(
                        secondaryColor: c,
                      ),
                    );
                  },
                ),
                _buildColorPickerTile(
                  'Color de Acento',
                  _workingSettings.accentColor,
                  (c) {
                    setState(
                      () => _workingSettings = _workingSettings.copyWith(
                        accentColor: c,
                      ),
                    );
                  },
                ),
                _buildTextFieldTile(
                  'URL del Logo',
                  _logoController,
                  Icons.image_outlined,
                  onChanged: (v) => setState(() {}),
                ),
              ],
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('TEXTOS DEL DOCUMENTO'),
            SettingsGroup(
              children: [
                _buildTextFieldTile(
                  'Título Cabecera',
                  _headerController,
                  Icons.title_rounded,
                  onChanged: (v) => setState(() {}),
                ),
                _buildTextFieldTile(
                  'Pie de Página',
                  _footerController,
                  Icons.short_text_rounded,
                  onChanged: (v) => setState(() {}),
                ),
                _buildTextFieldTile(
                  'Información Contacto',
                  _footerContactController,
                  Icons.contact_mail_outlined,
                  onChanged: (v) => setState(() {}),
                ),
                _buildFontPickerTile(),
              ],
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('OPCIONES PREMIUM'),
            SettingsGroup(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Incluir Portada',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Añade una página de presentación profesional',
                  ),
                  value: _workingSettings.includeCoverPage,
                  activeColor: Colors.blue,
                  onChanged: (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      includeCoverPage: v,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text(
                    'Resumen de Macros',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Muestra gráficos y totales en la cabecera',
                  ),
                  value: _workingSettings.showMacrosSummary,
                  activeColor: Colors.blue,
                  onChanged: (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      showMacrosSummary: v,
                    ),
                  ),
                ),
                _buildHeaderStylePickerTile(),
              ],
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('DISEÑO Y ESPACIADO'),
            SettingsGroup(
              children: [
                _buildDropdownTile(
                  'Márgenes de Página',
                  _workingSettings.pageMargins,
                  ['small', 'medium', 'large'],
                  {
                    'small': 'Pequeños',
                    'medium': 'Medianos',
                    'large': 'Grandes',
                  },
                  (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      pageMargins: v,
                    ),
                  ),
                ),
                _buildSliderTile(
                  'Espaciado de Líneas',
                  _workingSettings.lineSpacing,
                  0.8,
                  2.0,
                  (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      lineSpacing: v,
                    ),
                  ),
                ),
                _buildSliderTile(
                  'Espaciado de Secciones',
                  _workingSettings.sectionSpacing,
                  10,
                  40,
                  (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      sectionSpacing: v,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('TIPOGRAFÍA'),
            SettingsGroup(
              children: [
                _buildSliderTile(
                  'Tamaño Cabeceras',
                  _workingSettings.headerFontSize,
                  12,
                  24,
                  (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      headerFontSize: v,
                    ),
                  ),
                ),
                _buildSliderTile(
                  'Tamaño Texto',
                  _workingSettings.bodyFontSize,
                  8,
                  14,
                  (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      bodyFontSize: v,
                    ),
                  ),
                ),
                _buildSliderTile(
                  'Tamaño Tablas',
                  _workingSettings.tableFontSize,
                  7,
                  12,
                  (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      tableFontSize: v,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('ESTILO DE TABLAS'),
            SettingsGroup(
              children: [
                _buildDropdownTile(
                  'Estilo de Bordes',
                  _workingSettings.tableBorderStyle,
                  ['none', 'light', 'medium', 'bold'],
                  {
                    'none': 'Sin bordes',
                    'light': 'Ligero',
                    'medium': 'Medio',
                    'bold': 'Grueso',
                  },
                  (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      tableBorderStyle: v,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text(
                    'Filas Alternadas',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Colores alternos en filas de tabla'),
                  value: _workingSettings.alternateRowColors,
                  activeColor: Colors.blue,
                  onChanged: (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      alternateRowColors: v,
                    ),
                  ),
                ),
                _buildColorPickerTile(
                  'Color Cabecera Tabla',
                  _workingSettings.tableHeaderColor.isEmpty
                      ? _workingSettings.primaryColor
                      : _workingSettings.tableHeaderColor,
                  (c) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      tableHeaderColor: c,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('MARCA DE AGUA Y LOGO'),
            SettingsGroup(
              children: [
                _buildTextFieldTile(
                  'Texto Marca de Agua',
                  TextEditingController(text: _workingSettings.watermarkText)
                    ..addListener(
                      () => setState(
                        () => _workingSettings = _workingSettings.copyWith(
                          watermarkText: TextEditingController(
                            text: _workingSettings.watermarkText,
                          ).text,
                        ),
                      ),
                    ),
                  Icons.water_drop_outlined,
                  onChanged: (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      watermarkText: v,
                    ),
                  ),
                ),
                _buildSliderTile(
                  'Opacidad Marca de Agua',
                  _workingSettings.watermarkOpacity,
                  0.05,
                  0.3,
                  (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      watermarkOpacity: v,
                    ),
                  ),
                ),
                _buildDropdownTile(
                  'Tamaño del Logo',
                  _workingSettings.logoSize,
                  ['small', 'medium', 'large'],
                  {'small': 'Pequeño', 'medium': 'Mediano', 'large': 'Grande'},
                  (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      logoSize: v,
                    ),
                  ),
                ),
                _buildDropdownTile(
                  'Posición del Logo',
                  _workingSettings.logoPosition,
                  ['header', 'footer', 'cover'],
                  {
                    'header': 'Cabecera',
                    'footer': 'Pie',
                    'cover': 'Solo Portada',
                  },
                  (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      logoPosition: v,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('OPCIONES AVANZADAS'),
            SettingsGroup(
              children: [
                _buildDropdownTile(
                  'Orientación de Página',
                  _workingSettings.pageOrientation,
                  ['auto', 'portrait', 'landscape'],
                  {
                    'auto': 'Automática',
                    'portrait': 'Vertical',
                    'landscape': 'Horizontal',
                  },
                  (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      pageOrientation: v,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text(
                    'Números de Página',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Mostrar numeración en pie de página'),
                  value: _workingSettings.showPageNumbers,
                  activeColor: Colors.blue,
                  onChanged: (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      showPageNumbers: v,
                    ),
                  ),
                ),
                _buildDropdownTile(
                  'Formato de Fecha',
                  _workingSettings.dateFormat,
                  ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'],
                  {
                    'DD/MM/YYYY': 'DD/MM/YYYY',
                    'MM/DD/YYYY': 'MM/DD/YYYY',
                    'YYYY-MM-DD': 'YYYY-MM-DD',
                  },
                  (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      dateFormat: v,
                    ),
                  ),
                ),
                _buildTextFieldTile(
                  'Símbolo de Moneda',
                  TextEditingController(text: _workingSettings.currencySymbol),
                  Icons.euro_outlined,
                  onChanged: (v) => setState(
                    () => _workingSettings = _workingSettings.copyWith(
                      currencySymbol: v,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: Colors.grey.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildLivePreview(bool isDark) {
    final primary = _hexToColor(_workingSettings.primaryColor);
    final secondary = _hexToColor(_workingSettings.secondaryColor);
    final accent = _hexToColor(_workingSettings.accentColor);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_workingSettings.includeCoverPage)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.star_rounded, size: 14, color: accent),
                  const SizedBox(width: 8),
                  const Text(
                    'PORTADA PREMIUM ACTIVADA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          // Header Accent
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildHeaderLayout(primary, secondary),
          ),
          if (_workingSettings.showMacrosSummary)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildMockMacro(primary, 'CAL'),
                  const SizedBox(width: 8),
                  _buildMockMacro(secondary, 'PRO'),
                  const SizedBox(width: 8),
                  _buildMockMacro(accent, 'GRA'),
                ],
              ),
            ),
          // Mock Body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                _buildMockLine(70, secondary),
                _buildMockLine(100, Colors.grey[100]!),
                _buildMockLine(100, Colors.grey[100]!),
                _buildMockLine(40, Colors.grey[100]!),
              ],
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            width: double.infinity,
            child: Text(
              _footerController.text.isEmpty
                  ? 'Texto del pie de página...'
                  : _footerController.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockLine(double width, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 10,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }

  Widget _buildColorPickerTile(
    String title,
    String currentHex,
    Function(String) onPicked,
  ) {
    final colors = [
      '#007AFF',
      '#34C759',
      '#FF9500',
      '#FF2D55',
      '#5856D6',
      '#AF52DE',
      '#5AC8FA',
      '#8E8E93',
      '#000000',
    ];

    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: _hexToColor(currentHex),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seleccionar Color',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: colors
                      .map(
                        (hex) => GestureDetector(
                          onTap: () {
                            onPicked(hex);
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: _hexToColor(hex),
                              shape: BoxShape.circle,
                              border: currentHex == hex
                                  ? Border.all(color: Colors.blue, width: 3)
                                  : null,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderStylePickerTile() {
    final styles = [
      {
        'id': 'classic',
        'name': 'Clásico (Logo Izqda)',
        'icon': Icons.format_align_left_rounded,
      },
      {
        'id': 'modern',
        'name': 'Moderno (Centrado)',
        'icon': Icons.format_align_center_rounded,
      },
      {
        'id': 'minimal',
        'name': 'Minimalista',
        'icon': Icons.horizontal_rule_rounded,
      },
      {
        'id': 'side',
        'name': 'Lateral',
        'icon': Icons.vertical_distribute_rounded,
      },
    ];

    return ListTile(
      title: const Text(
        'Estilo de Cabecera',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      leading: const Icon(Icons.style_outlined, color: Colors.blue),
      trailing: Text(
        styles.firstWhere(
              (s) => s['id'] == _workingSettings.headerStyle,
            )['name']
            as String,
        style: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Estilo de Cabecera',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                ...styles.map(
                  (s) => ListTile(
                    leading: Icon(s['icon'] as IconData, color: Colors.blue),
                    title: Text(s['name'] as String),
                    trailing: _workingSettings.headerStyle == s['id']
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(
                        () => _workingSettings = _workingSettings.copyWith(
                          headerStyle: s['id'] as String,
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderLayout(Color primary, Color secondary) {
    final style = _workingSettings.headerStyle;
    final logo = Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        image: _logoController.text.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(_logoController.text),
                fit: BoxFit.contain,
              )
            : null,
      ),
      child: _logoController.text.isEmpty
          ? const Icon(Icons.business_rounded, color: Colors.grey)
          : null,
    );

    final titleColumn = Column(
      crossAxisAlignment: style == 'modern'
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          _headerController.text.isEmpty
              ? 'TÍTULO CABECERA'
              : _headerController.text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
            fontFamily: _workingSettings.fontFamily == 'Helvetica'
                ? null
                : 'Courier',
          ),
        ),
        Text(
          'Documento Profesional • ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
          style: TextStyle(fontSize: 9, color: Colors.grey[500]),
        ),
      ],
    );

    if (style == 'modern') {
      return Column(children: [logo, const SizedBox(height: 12), titleColumn]);
    } else if (style == 'minimal') {
      return Row(children: [titleColumn]);
    } else if (style == 'side') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [titleColumn, logo],
      );
    }
    // Classic
    return Row(
      children: [
        logo,
        const SizedBox(width: 16),
        Expanded(child: titleColumn),
      ],
    );
  }

  Widget _buildMockMacro(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFontPickerTile() {
    final fonts = ['Helvetica', 'Times', 'Courier'];
    return ListTile(
      title: const Text(
        'Fuente del Documento',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      leading: const Icon(Icons.font_download_rounded, color: Colors.blue),
      trailing: Text(
        _workingSettings.fontFamily,
        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
      ),
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Seleccionar Fuente',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                ...fonts.map(
                  (f) => ListTile(
                    title: Text(f),
                    trailing: _workingSettings.fontFamily == f
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(
                        () => _workingSettings = _workingSettings.copyWith(
                          fontFamily: f,
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextFieldTile(
    String label,
    TextEditingController controller,
    IconData icon, {
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
                labelStyle: const TextStyle(fontSize: 14),
              ),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String currentValue,
    List<String> options,
    Map<String, String> labels,
    Function(String) onChanged,
  ) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(labels[currentValue] ?? currentValue),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                ...options.map(
                  (option) => ListTile(
                    title: Text(labels[option] ?? option),
                    trailing: currentValue == option
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      onChanged(option);
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliderTile(
    String title,
    double currentValue,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                currentValue.toStringAsFixed(1),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: currentValue,
          min: min,
          max: max,
          divisions: ((max - min) * 10).round(),
          activeColor: Colors.blue,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }
}
