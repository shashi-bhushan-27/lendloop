/// Email Verification Page — OTP-based
///
/// Shows a 6-digit code input screen.
/// On page load, triggers OTP send via Postmark.
/// User enters the code they received by email.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lendloop/core/constants/app_colors.dart';
import 'package:lendloop/providers/auth_provider.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState
    extends ConsumerState<EmailVerificationPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isSendingOtp = false;
  bool _isVerifying = false;
  bool _otpSent = false;
  String? _errorMessage;
  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    // Send OTP on page load
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendOtp());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  String get _currentOtp => _controllers.map((c) => c.text).join();

  String get _userEmail {
    final authService = ref.read(authServiceProvider);
    return authService.currentFirebaseUser?.email ?? '';
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendCountdown = 0);
      } else {
        if (mounted) setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final email = _userEmail;
    if (email.isEmpty) return;

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final result = await authService.sendOtp(email);

    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _isSendingOtp = false;
        _errorMessage = failure.message;
      }),
      (_) => setState(() {
        _isSendingOtp = false;
        _otpSent = true;
        _startResendTimer();
      }),
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _currentOtp;
    if (otp.length < 6) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final result = await authService.verifyOtp(
      email: _userEmail,
      otp: otp,
    );

    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() {
          _isVerifying = false;
          _errorMessage = failure.message;
        });
        // Clear OTP fields on failure
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      },
      (data) async {
        // Success — reload user and navigate home
        await ref.read(currentUserProvider.notifier).loadUser();
        if (mounted) context.go('/home');
      },
    );
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_currentOtp.length == 6) {
      _verifyOtp();
    }
  }

  void _onKeyPress(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _signOut() async {
    await ref.read(currentUserProvider.notifier).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),

              // Icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.email_outlined,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'Verify Your Email',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              if (_otpSent) ...[
                Text(
                  'Enter the 6-digit code sent to:',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  _userEmail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else if (_isSendingOtp) ...[
                const SizedBox(height: 8),
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  'Sending verification code...',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],

              const SizedBox(height: 32),

              // 6-digit OTP input
              if (_otpSent)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: 48,
                      height: 56,
                      child: RawKeyboardListener(
                        focusNode: FocusNode(),
                        onKey: (event) => _onKeyPress(i, event),
                        child: TextField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _errorMessage != null
                                    ? AppColors.error
                                    : AppColors.textTertiary,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (v) => _onDigitChanged(i, v),
                        ),
                      ),
                    );
                  }),
                ),

              const SizedBox(height: 16),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Verify button
              if (_otpSent)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isVerifying || _currentOtp.length < 6
                            ? null
                            : _verifyOtp,
                    child: _isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Verify Code'),
                  ),
                ),

              const SizedBox(height: 16),

              // Resend OTP
              if (_otpSent)
                TextButton.icon(
                  onPressed: _resendCountdown > 0 || _isSendingOtp
                      ? null
                      : _sendOtp,
                  icon: _isSendingOtp
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    _resendCountdown > 0
                        ? 'Resend code in ${_resendCountdown}s'
                        : 'Resend Code',
                  ),
                ),

              const SizedBox(height: 8),

              // Sign out
              TextButton(
                onPressed: _signOut,
                child: Text(
                  'Sign Out',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),

              const SizedBox(height: 24),

              // Info box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.info.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.info, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Can\'t find the email? Check your spam or junk folder. The code expires in 10 minutes.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
