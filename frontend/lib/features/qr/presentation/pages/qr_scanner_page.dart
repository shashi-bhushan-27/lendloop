/// QR Scanner Page — Scan pickup / return QR codes

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lendloop/core/constants/app_colors.dart';
import 'package:lendloop/services/api_client.dart';

class QRScannerPage extends ConsumerStatefulWidget {
  const QRScannerPage({super.key});

  @override
  ConsumerState<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends ConsumerState<QRScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  String? _result;

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.first;
    final token = barcode.rawValue;
    if (token == null) return;

    setState(() => _isProcessing = true);
    _controller.stop();

    try {
      final response = await ApiClient.instance.post('/qr/verify', data: {'token': token});
      final data = response.data as Map<String, dynamic>;
      if (!mounted) return;
      _showResult(
        success: data['success'] as bool? ?? false,
        message: 'QR verified: ${data['qr_type'] ?? 'unknown'} confirmed!',
      );
    } catch (e) {
      if (!mounted) return;
      _showResult(success: false, message: 'QR verification failed. Please try again.');
    }
  }

  void _showResult({required bool success, required String message}) {
    setState(() { _result = message; _isProcessing = false; });
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: success ? AppColors.success.withOpacity(0.95) : AppColors.error.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white, size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              success ? 'Verified!' : 'Failed',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                  foregroundColor: success ? AppColors.success : AppColors.error),
              onPressed: () {
                Navigator.pop(context);
                _controller.start();
              },
              child: const Text('Scan Again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR Code', style: TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onBarcodeDetected),
          // Overlay
          Center(
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Column(
              children: [
                if (_isProcessing) const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                const Text(
                  'Point the camera at a LendLoop QR code\nto verify item pickup or return.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Torch Toggle
          Positioned(
            top: 16, right: 16,
            child: IconButton(
              icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
              onPressed: _controller.toggleTorch,
            ),
          ),
        ],
      ),
    );
  }
}
