import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../services/food_fact_service.dart';
import '../../../widgets/dialogs/add_edit_ingrediente_dialog.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final VoidCallback onSuccess;

  const BarcodeScannerScreen({super.key, required this.onSuccess});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() => _isProcessing = true);
    controller.stop();

    final foodService = FoodFactService();
    final item = await foodService.fetchProductByBarcode(code);

    if (mounted) {
      if (item != null) {
        // Close scanner screen
        Navigator.pop(context);

        // Open AddEditIngredienteDialog with pre-filled details
        showDialog(
          context: context,
          builder: (context) => AddEditIngredienteDialog(
            ingrediente: item,
            onSuccess: widget.onSuccess,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto no encontrado en OpenFoodFacts'),
          ),
        );
        setState(() => _isProcessing = false);
        controller.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Código de Barras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: _onDetect),
          if (_isProcessing) const Center(child: CircularProgressIndicator()),
          // Overlay to guide user
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
