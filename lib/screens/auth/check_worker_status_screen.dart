import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

class CheckWorkerStatusScreen extends StatefulWidget {
  const CheckWorkerStatusScreen({super.key});

  @override
  State<CheckWorkerStatusScreen> createState() => _CheckWorkerStatusScreenState();
}

class _CheckWorkerStatusScreenState extends State<CheckWorkerStatusScreen> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveFlow());
  }

  Future<void> _resolveFlow() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final incomingPhone = (args?['phone'] as String? ?? '').trim();

    final status = await _apiService.getWorkerStatus();
    if (!mounted) return;

    if (status.exists) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
      return;
    }

    final phone = status.phone.isNotEmpty ? status.phone : incomingPhone;
    if (phone.isEmpty) {
      await _apiService.clearSession();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.welcome,
        (route) => false,
      );
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.nameInput,
      (route) => false,
      arguments: {'phone': phone},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/gig.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: const Color(0xFFF5F5F5).withValues(alpha: 0.9),
            ),
          ),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Checking your rider profile...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Logging you in or setting up your cover in a moment.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
