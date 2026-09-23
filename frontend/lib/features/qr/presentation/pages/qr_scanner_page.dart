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

enum _PermissionState { checking, granted, denied, permanentlyDenied }

class _QRScannerPageState extends ConsumerState<QRScannerPage> {
  // autoStart is off — we gate camera start behind our own explicit
  // permission_handler request below. Leaving mobile_scanner to request
  // permission internally proved unreliable on some OEM Android builds:
  // a denial there surfaced as a generic "genericError" instead of the
  // expected permissionDenied code, so the user just saw "camera
  // unavailable" with no way to fix it. Requesting permission ourselves
  // first gives a real OS-level status we can act on.
  final MobileScannerController _controller = MobileScannerController(autoStart: false);
  bool _isProcessing = false;
  _PermissionState _permissionState = _PermissionState.checking;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
    }
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _permissionState = _PermissionState.granted);
      await _controller.start();
    } else if (status.isPermanentlyDenied) {
      setState(() => _permissionState = _PermissionState.permanentlyDenied);
    } else {
      setState(() => _permissionState = _PermissionState.denied);
    }
  }

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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_permissionState) {
      case _PermissionState.checking:
        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
      case _PermissionState.denied:
        return _PermissionRequest(onRequest: _requestCameraPermission);
      case _PermissionState.permanentlyDenied:
        return _CameraError(
          isPermissionDenied: true,
          message: 'LendLoop needs camera access to scan pickup and return QR codes. '
              "Camera was previously denied — enable it in this app's Settings to continue.",
          onRetry: _requestCameraPermission,
        );
      case _PermissionState.granted:
        return MobileScanner(
          controller: _controller,
          onDetect: _onBarcodeDetected,
          errorBuilder: (context, error, child) => _CameraError(
            isPermissionDenied: error.errorCode == MobileScannerErrorCode.permissionDenied,
            message: error.errorCode == MobileScannerErrorCode.permissionDenied
                ? 'LendLoop needs camera access to scan pickup and return QR codes. Allow it in Settings to continue.'
                : 'The camera could not be started (${error.errorCode.name}). Make sure no other app '
                    '(camera, video call) is using it, then try again.',
            onRetry: _retryCamera,
          ),
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
        );
    }
  }
}

/// Prompts for camera permission the first time (before it's been denied
/// outright) — a plain "denied" status can still be asked again, unlike
/// "permanently denied" which needs a trip to Settings.
class _PermissionRequest extends StatelessWidget {
  final VoidCallback onRequest;
  const _PermissionRequest({required this.onRequest});

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
              const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 56),
              const SizedBox(height: 20),
              const Text('Camera permission needed',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text(
                'LendLoop needs camera access to scan pickup and return QR codes.',
                style: TextStyle(color: Colors.white70, fontSize: 13.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRequest,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Allow Camera'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the camera fails outright — either permission was
/// permanently denied, or mobile_scanner hit a genuine start-up error
/// (camera in use, hardware issue). The widget's own default error state
/// is just a bare exclamation icon with no explanation, so this replaces
/// it with an actionable message.
class _CameraError extends StatelessWidget {
  final bool isPermissionDenied;
  final String message;
  final VoidCallback onRetry;
  const _CameraError({required this.isPermissionDenied, required this.message, required this.onRetry});

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
                isPermissionDenied ? Icons.videocam_off_rounded : Icons.error_outline_rounded,
                color: Colors.white70, size: 56,
              ),
              const SizedBox(height: 20),
              Text(
                isPermissionDenied ? 'Camera permission needed' : 'Camera unavailable',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (isPermissionDenied)
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
