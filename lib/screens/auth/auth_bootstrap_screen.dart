import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

class AuthBootstrapScreen extends StatefulWidget {
  const AuthBootstrapScreen({super.key});

  @override
  State<AuthBootstrapScreen> createState() => _AuthBootstrapScreenState();
}

class _AuthBootstrapScreenState extends State<AuthBootstrapScreen> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await _apiService.initializeSession();
      if (!mounted) return;

      if (_apiService.isAuthenticated) {
        Navigator.pushReplacementNamed(context, AppRoutes.checkWorkerStatus);
        return;
      }
    } catch (_) {
      // In tests or plugin-unavailable cases, fall back to welcome flow.
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.welcome);
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
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Restoring your coverage session...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
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
