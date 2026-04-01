import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/platform_model.dart';
import '../../services/api_service.dart';
import '../../widgets/platform_card.dart';
import '../../widgets/progress_dots.dart';
import '../../routes/app_routes.dart';

class PlatformSelectionScreen extends StatefulWidget {
  const PlatformSelectionScreen({super.key});

  @override
  State<PlatformSelectionScreen> createState() =>
      _PlatformSelectionScreenState();
}

class _PlatformSelectionScreenState extends State<PlatformSelectionScreen> {
  final ApiService _apiService = ApiService();
  int? _selectedIndex;
  List<DeliveryPlatform> _platforms = DeliveryPlatform.getPlatforms();

  bool get _canContinue =>
      _selectedIndex != null && _selectedIndex! >= 0 && _selectedIndex! < _platforms.length;

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final phone = (args?['phone'] as String?)?.trim() ?? '';
    final name = (args?['name'] as String?)?.trim() ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Back button
              Tooltip(
                message: 'Back',
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 16,
                      color: AppColors.textPrimary,
                    ),
                    splashRadius: 20,
                    tooltip: 'Back',
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Progress dots
              const ProgressDots(total: 4, current: 0),
              const SizedBox(height: 28),

              // Title
              const Text(
                'Which platform?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "We'll use this to set your coverage zone and calculate your weekly premium.",
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Platform cards
              Expanded(
                child: FutureBuilder<List<DeliveryPlatform>>(
                  future: _apiService.getPlatforms(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load platforms. Please verify OTP and retry.',
                          style: TextStyle(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final platforms = snapshot.data ?? const <DeliveryPlatform>[];
                    _platforms = platforms;
                    if (_selectedIndex != null && _selectedIndex! >= platforms.length) {
                      _selectedIndex = null;
                    }

                    if (platforms.isEmpty) {
                      return const Center(
                        child: Text(
                          'No platforms available from backend.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    return ListView(
                      children: [
                        ...platforms.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PlatformCard(
                              platform: entry.value,
                              isSelected: _selectedIndex == entry.key,
                              onTap: () {
                                setState(() {
                                  _selectedIndex = entry.key;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canContinue
                      ? () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.zoneSelect,
                            arguments: {
                              'platform':
                                  _platforms[_selectedIndex!].name,
                              'phone': phone,
                              'name': name,
                            },
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    disabledForegroundColor: AppColors.textTertiary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
