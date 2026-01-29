import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/factura_model.dart';
import '../../services/factura_service.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FacturaDetailScreen extends StatefulWidget {
  final String facturaId;

  const FacturaDetailScreen({super.key, required this.facturaId});

  @override
  State<FacturaDetailScreen> createState() => _FacturaDetailScreenState();
}

class _FacturaDetailScreenState extends State<FacturaDetailScreen> {
  late FacturaService _facturaService;
  Factura? _factura;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _facturaService = FacturaService(
      Provider.of<ApiService>(context, listen: false),
    );
    _loadFactura();
  }

  Future<void> _loadFactura() async {
    setState(() => _isLoading = true);
    try {
      final factura = await _facturaService.getFacturaById(widget.facturaId);
      setState(() {
        _factura = factura;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _downloadPDF() async {
    try {
      final bytes = await _facturaService.downloadPDF(widget.facturaId);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Factura-${_factura!.numeroFactura}.pdf');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF descargado: ${file.path}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al descargar PDF: $e')));
      }
    }
  }

  Future<void> _sendEmail() async {
    try {
      await _facturaService.sendEmail(widget.facturaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Factura enviada por email')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al enviar email: $e')));
      }
    }
  }

  Future<void> _updateEstado(String nuevoEstado) async {
    try {
      final updated = await _facturaService.updateEstado(
        widget.facturaId,
        estado: nuevoEstado,
        fechaPago: nuevoEstado == 'pagada' ? DateTime.now() : null,
      );
      setState(() => _factura = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado actualizado a: $nuevoEstado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_factura == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Factura no encontrada')),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(_factura!.numeroFactura),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: _downloadPDF,
            tooltip: 'Descargar PDF',
          ),
          IconButton(
            icon: const Icon(Icons.email_rounded),
            onPressed: _sendEmail,
            tooltip: 'Enviar por email',
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert_rounded),
            itemBuilder: (context) => [
              if (_factura!.isPendiente)
                const PopupMenuItem(
                  value: 'marcar_pagada',
                  child: Text('Marcar como pagada'),
                ),
              if (_factura!.isPendiente)
                const PopupMenuItem(
                  value: 'cancelar',
                  child: Text('Cancelar factura'),
                ),
            ],
            onSelected: (value) {
              if (value == 'marcar_pagada') {
                _updateEstado('pagada');
              } else if (value == 'cancelar') {
                _updateEstado('cancelada');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(theme, isDark),
            const SizedBox(height: 16),
            _buildClienteCard(theme, isDark),
            if (_factura!.presupuestoId != null) ...[
              const SizedBox(height: 16),
              _buildPresupuestoLinkCard(theme, isDark),
            ],
            const SizedBox(height: 16),
            _buildItemsCard(theme, isDark),
            const SizedBox(height: 16),
            _buildTotalesCard(theme, isDark),
            if (_factura!.notas != null) ...[
              const SizedBox(height: 16),
              _buildNotasCard(theme, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, bool isDark) {
    Color estadoColor;
    switch (_factura!.estado) {
      case 'pagada':
        estadoColor = Colors.green;
        break;
      case 'vencida':
        estadoColor = Colors.red;
        break;
      case 'cancelada':
        estadoColor = Colors.grey;
        break;
      default:
        estadoColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _factura!.numeroFactura,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: estadoColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _factura!.estado.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _factura!.concepto,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fecha',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(_factura!.fecha),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vencimiento',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(_factura!.vencimiento),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClienteCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cliente',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _factura!.datosReceptor.nombre,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'NIF: ${_factura!.datosReceptor.nif}',
            style: TextStyle(fontSize: 13, color: theme.hintColor),
          ),
          const SizedBox(height: 4),
          Text(
            _factura!.datosReceptor.direccion,
            style: TextStyle(fontSize: 13, color: theme.hintColor),
          ),
          Text(
            '${_factura!.datosReceptor.codigoPostal} ${_factura!.datosReceptor.ciudad}',
            style: TextStyle(fontSize: 13, color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conceptos',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 12),
          ..._factura!.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.descripcion,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.cantidad} x ${item.precioUnitario.toStringAsFixed(2)}€ (IVA ${item.iva}%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${item.total.toStringAsFixed(2)}€',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalesCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildTotalRow('Subtotal', _factura!.subtotal, theme, false),
          const SizedBox(height: 8),
          _buildTotalRow('IVA', _factura!.totalIVA, theme, false),
          if (_factura!.descuentoGlobal > 0) ...[
            const SizedBox(height: 8),
            _buildTotalRow(
              'Descuento (${_factura!.descuentoGlobal}%)',
              -(_factura!.subtotal * _factura!.descuentoGlobal / 100),
              theme,
              false,
            ),
          ],
          const Divider(height: 24),
          _buildTotalRow('TOTAL', _factura!.total, theme, true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount,
    ThemeData theme,
    bool isTotal,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? theme.primaryColor : theme.hintColor,
          ),
        ),
        Text(
          '${amount.toStringAsFixed(2)}€',
          style: TextStyle(
            fontSize: isTotal ? 20 : 15,
            fontWeight: FontWeight.bold,
            color: isTotal
                ? theme.primaryColor
                : theme.textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildNotasCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notas',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(_factura!.notas!, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPresupuestoLinkCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: theme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Auto-generada',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Esta factura se generó desde un presupuesto aceptado.',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
