import 'package:flutter/material.dart';
import '../premium_settings_widgets.dart';

class PdfDesignerDialog extends StatefulWidget {
  final Map<String, dynamic> settings;
  final Function(Map<String, dynamic>) onSave;

  const PdfDesignerDialog({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<PdfDesignerDialog> createState() => _PdfDesignerDialogState();
}

class _PdfDesignerDialogState extends State<PdfDesignerDialog> {
  late Map<String, dynamic> pdf;

  @override
  void initState() {
    super.initState();
    pdf = Map<String, dynamic>.from(widget.settings['pdfSettings'] ?? {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Row(
        children: [
          Icon(
            Icons.picture_as_pdf_rounded,
            color: Colors.blue.shade400,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text(
            'Diseño de PDF',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumCategory(
                title: 'IDENTIDAD & COLORES',
                icon: Icons.palette_rounded,
                color: Colors.blue.shade400,
              ),
              Row(
                children: [
                  Expanded(
                    child: PremiumColorTile(
                      label: 'Primario',
                      data: pdf,
                      field: 'primaryColor',
                      defaultColor: Colors.blue,
                      setDialogState: setState,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PremiumColorTile(
                      label: 'Secundario',
                      data: pdf,
                      field: 'secondaryColor',
                      defaultColor: Colors.green,
                      setDialogState: setState,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PremiumColorTile(
                label: 'Acento / Detalles',
                data: pdf,
                field: 'accentColor',
                defaultColor: Colors.amber,
                setDialogState: setState,
              ),
              const SizedBox(height: 16),
              PremiumTextField(
                label: 'URL del Logotipo',
                hint: 'Enlace directo a la imagen',
                data: pdf,
                field: 'logoUrl',
                icon: Icons.image_rounded,
              ),
              const SizedBox(height: 24),
              PremiumCategory(
                title: 'TEXTOS & MARCA',
                icon: Icons.text_fields_rounded,
                color: Colors.blue.shade400,
              ),
              PremiumTextField(
                label: 'Título Cabecera',
                hint: 'Nombre de la asesoría',
                data: pdf,
                field: 'headerTitle',
                icon: Icons.title_rounded,
              ),
              PremiumTextField(
                label: 'Pie de Página',
                hint: 'Texto legal o agradecimiento',
                data: pdf,
                field: 'footerText',
                icon: Icons.short_text_rounded,
              ),
              PremiumTextField(
                label: 'Información de Contacto',
                hint: 'Email o Teléfono',
                data: pdf,
                field: 'footerContactInfo',
                icon: Icons.contact_mail_rounded,
              ),
              PremiumTextField(
                label: 'Marca de Agua',
                hint: 'Texto al fondo (opcional)',
                data: pdf,
                field: 'watermarkText',
                icon: Icons.branding_watermark_rounded,
              ),
              const SizedBox(height: 24),
              PremiumCategory(
                title: 'TIPOGRAFÍA & ESTILO',
                icon: Icons.font_download_rounded,
                color: Colors.blue.shade400,
              ),
              Row(
                children: [
                  Expanded(
                    child: PremiumSlider(
                      title: 'Tamaño Título',
                      subtitle: 'Cabeceras',
                      value: pdf['headerFontSize'] ?? 18,
                      min: 12,
                      max: 24,
                      onChanged: (v) =>
                          setState(() => pdf['headerFontSize'] = v),
                      isInteger: true,
                      color: Colors.blue.shade400,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PremiumSlider(
                      title: 'Tamaño Cuerpo',
                      subtitle: 'Texto Base',
                      value: pdf['bodyFontSize'] ?? 10,
                      min: 8,
                      max: 14,
                      onChanged: (v) => setState(() => pdf['bodyFontSize'] = v),
                      isInteger: true,
                      color: Colors.blue.shade400,
                    ),
                  ),
                ],
              ),
              PremiumSlider(
                title: 'Opacidad Marca Agua',
                subtitle: 'Visibilidad del fondo',
                value: pdf['watermarkOpacity'] ?? 0.1,
                min: 0.0,
                max: 0.5,
                onChanged: (v) => setState(() => pdf['watermarkOpacity'] = v),
                color: Colors.blue.shade400,
              ),
              const SizedBox(height: 24),
              PremiumCategory(
                title: 'MAQUETACIÓN & ELEMENTOS',
                icon: Icons.layers_rounded,
                color: Colors.blue.shade400,
              ),
              PremiumToggle(
                title: 'Incluir Portada',
                subtitle: 'Página de presentación al inicio',
                value: pdf['includeCoverPage'] ?? false,
                onChanged: (v) => setState(() => pdf['includeCoverPage'] = v),
                activeColor: Colors.blue.shade400,
              ),
              PremiumToggle(
                title: 'Resumen de Macros',
                subtitle: 'Mostrar tabla nutricional al inicio',
                value: pdf['showMacrosSummary'] ?? true,
                onChanged: (v) => setState(() => pdf['showMacrosSummary'] = v),
                activeColor: Colors.blue.shade400,
              ),
              PremiumToggle(
                title: 'Numeración de Páginas',
                subtitle: 'Pie de página automático',
                value: pdf['showPageNumbers'] ?? true,
                onChanged: (v) => setState(() => pdf['showPageNumbers'] = v),
                activeColor: Colors.blue.shade400,
              ),
              const SizedBox(height: 16),
              PremiumDropdown(
                label: 'Orientación de Página',
                value: pdf['pageOrientation'] ?? 'auto',
                options: const ['auto', 'portrait', 'landscape'],
                onChanged: (v) => setState(() => pdf['pageOrientation'] = v),
              ),
              PremiumDropdown(
                label: 'Estilo de Bordes (Tabla)',
                value: pdf['tableBorderStyle'] ?? 'light',
                options: const ['none', 'light', 'bold'],
                onChanged: (v) => setState(() => pdf['tableBorderStyle'] = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'CANCELAR',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () {
            widget.onSave(pdf);
            Navigator.pop(context);
          },
          child: const Text(
            'GUARDAR DISEÑO',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
