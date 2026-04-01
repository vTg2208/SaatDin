import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../routes/app_routes.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  final ApiService _apiService = ApiService();

  bool _isVerifying = false;
  bool _isResending = false;

  bool get _canVerify {
    final len = _otpController.text.trim().length;
    return len == 4 || len == 6;
  }

  @override
  void initState() {
    super.initState();
    _otpController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp(String phone) async {
    if (!_canVerify || _isVerifying) return;

    setState(() {
      _isVerifying = true;
    });

    final ok = await _apiService.verifyOtp(phone, _otpController.text.trim());

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
    });

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_apiService.lastError ?? 'Invalid OTP. Please try again.'),
        ),
      );
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.checkWorkerStatus,
      (route) => false,
      arguments: {'phone': phone},
    );
  }

  Future<void> _resendOtp(String phone) async {
    if (_isResending) return;

    setState(() {
      _isResending = true;
    });

    final ok = await _apiService.sendOtp(phone);

    if (!mounted) return;

    setState(() {
      _isResending = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'OTP sent again.' : (_apiService.lastError ?? 'Failed to resend OTP.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final phone = (args?['phone'] as String?)?.trim() ?? '';

    if (phone.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
        ),
        body: const Center(
          child: Text(
            'Phone number missing. Please restart onboarding.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('OTP Verification'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter OTP',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We sent an OTP to +91 $phone',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _otpController,
                      focusNode: _otpFocusNode,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'OTP',
                        hintText: '4 or 6 digit OTP',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canVerify && !_isVerifying
                            ? () => _verifyOtp(phone)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(_isVerifying ? 'Verifying...' : 'Verify OTP'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isResending ? null : () => _resendOtp(phone),
                      child: Text(_isResending ? 'Resending...' : 'Resend OTP'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
