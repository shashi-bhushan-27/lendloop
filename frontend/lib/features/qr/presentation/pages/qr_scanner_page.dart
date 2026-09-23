/// QR Scanner Page — Scan pickup / return QR codes

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
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
    setState(() => _isProcessing = false);
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

  Future<void> _retryCamera() async {
    try {
      await _controller.start();
    } catch (_) {
      // Ignored — the errorBuilder will keep showing the current failure state.
    }
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
      body: MobileScanner(
        controller: _controller,
        onDetect: _onBarcodeDetected,
        errorBuilder: (context, error, child) => _CameraError(error: error, onRetry: _retryCamera),
        placeholderBuilder: (context, child) =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        overlayBuilder: (context, constraints) => Stack(
          children: [
            // Scan window
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
      ),
    );
  }
}

/// Shown when [MobileScanner] fails to start the camera — most commonly
/// because camera permission was denied. The widget's own default error
/// state is just a bare exclamation icon with no explanation, so this
/// replaces it with an actionable message.
class _CameraError extends StatelessWidget {
  final MobileScannerException error;
  final VoidCallback onRetry;
  const _CameraError({required this.error, required this.onRetry});

  bool get _isPermissionDenied => error.errorCode == MobileScannerErrorCode.permissionDenied;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isPermissionDenied ? Icons.videocam_off_rounded : Icons.error_outline_rounded,
                color: Colors.white70, size: 56,
              ),
              const SizedBox(height: 20),
              Text(
                _isPermissionDenied ? 'Camera permission needed' : 'Camera unavailable',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _isPermissionDenied
                    ? 'LendLoop needs camera access to scan pickup and return QR codes. Allow it in Settings to continue.'
                    : 'The camera could not be started (${error.errorCode.name}). Make sure no other app is using it, then try again.',
                style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_isPermissionDenied)
                ElevatedButton.icon(
                  onPressed: openAppSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Open Settings'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                )
              else
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: const Text('Try Again', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white70)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
