import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();

  bool hasScanned = false;

  void _onDetect(BarcodeCapture capture) async {
    if (hasScanned) return;
    final code = capture.barcodes.first.rawValue;
    if (code != null) {
      hasScanned = true;
      await controller.stop(); 
      Navigator.pop(context, code);
    }
  }

  @override
  void dispose() {
    controller.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () async {
                await controller.stop(); 
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}