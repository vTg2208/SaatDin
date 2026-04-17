import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/plan_model.dart';
import '../../services/api_service.dart';
import '../../widgets/plan_card.dart';
import '../../widgets/progress_dots.dart';
import '../../routes/app_routes.dart';
import 'payment/payment_flow_arguments.dart';

class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  final ApiService _apiService = ApiService();

  int _selectedIndex = 1; // Default to Standard (most popular)
  bool _isProceeding = false;

  Future<bool> _confirmOverwriteIfNeeded() async {
    final status = await _apiService.getWorkerStatus();
    if (!mounted) return false;
    if (!status.exists || status.worker == null) {
      return true;
    }

    final worker = status.worker!;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Replace current cover?',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'You are already covered in ${worker.zone} on ${worker.platform} (${worker.plan}).\n\nContinuing will replace that profile with this new setup.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep current cover'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace and continue'),
            ),
          ],
        );
      },
    );

    return approved == true;
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final platform = args?['platform'] ?? 'Blinkit';
    final zone = args?['zone'] ?? 'Bellandur';
    final pincode = args?['pincode'] ?? '';
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
              const ProgressDots(total: 4, current: 2),
              const SizedBox(height: 28),

              // Title
              const Text(
                'Pick your shield',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Zone: $zone · Weekly debit from UPI · $platform',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Plan cards
              Expanded(
                child: FutureBuilder<List<InsurancePlan>>(
                  future: _apiService.getPlans(
                    zone: pincode.isNotEmpty ? pincode : zone,
                    platform: platform,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load plans. Please go back and try again.',
                          style: TextStyle(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final plans = snapshot.data ?? const <InsurancePlan>[];
                    if (plans.isEmpty) {
                      return const Center(
                        child: Text(
                          'No plans available from backend for this selection.',
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    if (_selectedIndex >= plans.length) {
                      _selectedIndex = plans.length - 1;
                    }

                    return ListView(
                      children: [
                        ...plans.asMap().entries.map((entry) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: 12,
                              top: entry.value.isPopular ? 8 : 0,
                            ),
                            child: PlanCard(
                              plan: entry.value,
                              isSelected: _selectedIndex == entry.key,
                              onTap: () {
                                setState(() {
                                  _selectedIndex = entry.key;
                                });
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                        const _AutoDebitNote(),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: plans.isEmpty || _isProceeding
                                ? null
                                : () async {
                                    if (phone.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Missing phone number. Please retry onboarding.'),
                                        ),
                                      );
                                      return;
                                    }

                                    setState(() {
                                      _isProceeding = true;
                                    });

                                    final canContinue = await _confirmOverwriteIfNeeded();
                                    if (!mounted) return;
                                    if (!canContinue) {
                                      setState(() {
                                        _isProceeding = false;
                                      });
                                      return;
                                    }

                                    setState(() {
                                      _isProceeding = false;
                                    });

                                    final selectedPlan = plans[_selectedIndex];

                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.paymentConfirm,
                                      arguments: PaymentFlowArguments(
                                        plan: selectedPlan,
                                        phone: phone,
                                        name: name,
                                        platform: platform,
                                        zone: zone,
                                        pincode: pincode,
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  plans.isEmpty
                                      ? 'No plans available'
                                      : _isProceeding
                                          ? 'Checking...'
                                          : 'Review Shield Details',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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

class _AutoDebitNote extends StatelessWidget {
  const _AutoDebitNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Auto-debited every Monday. Cancel anytime in settings.',
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
      ),
    );
  }
}
