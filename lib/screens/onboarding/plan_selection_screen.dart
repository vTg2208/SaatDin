import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/plan_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../widgets/plan_card.dart';
import '../../widgets/progress_dots.dart';
import '../../routes/app_routes.dart';

class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({
    super.key,
    this.initialArgs,
    this.plansLoader,
    this.workerStatusLoader,
    this.registerUser,
  });

  final Map<String, dynamic>? initialArgs;
  final Future<List<InsurancePlan>> Function(
    ApiService apiService, {
    required String zone,
    required String platform,
  })?
  plansLoader;
  final Future<WorkerStatus> Function(ApiService apiService)?
  workerStatusLoader;
  final Future<User?> Function(
    ApiService apiService, {
    required String phone,
    required String platformName,
    required String zone,
    required String planName,
    String? name,
  })?
  registerUser;

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  final ApiService _apiService = ApiService();

  int _selectedIndex = 0;
  bool _isActivating = false;
  late String _platform;
  late String _zone;
  late String _pincode;
  late String _phone;
  late String _name;
  late Future<List<InsurancePlan>> _plansFuture;
  bool _didInit = false;
  bool _hasSeededSelection = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;

    final routeArgs =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final args = routeArgs ?? widget.initialArgs ?? const <String, dynamic>{};

    _platform = args['platform'] ?? 'Blinkit';
    _zone = args['zone'] ?? 'Bellandur';
    _pincode = args['pincode'] ?? '';
    _phone = (args['phone'] as String?)?.trim() ?? '';
    _name = (args['name'] as String?)?.trim() ?? '';

    final selectedZone = _pincode.isNotEmpty ? _pincode : _zone;
    _plansFuture =
        widget.plansLoader?.call(
          _apiService,
          zone: selectedZone,
          platform: _platform,
        ) ??
        _apiService.getPlans(zone: selectedZone, platform: _platform);

    _didInit = true;
  }

  Future<bool> _confirmOverwriteIfNeeded() async {
    final status =
        await (widget.workerStatusLoader?.call(_apiService) ??
            _apiService.getWorkerStatus());
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
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
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
              const ProgressDots(total: 4, current: 3),
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
                'Zone: $_zone · Weekly debit from UPI · $_platform',
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
                  future: _plansFuture,
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

                    if (!_hasSeededSelection) {
                      final popularIndex = plans.indexWhere(
                        (plan) => plan.isPopular,
                      );
                      _selectedIndex = popularIndex >= 0 ? popularIndex : 0;
                      _hasSeededSelection = true;
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
                            onPressed: plans.isEmpty || _isActivating
                                ? null
                                : () async {
                                    if (_phone.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Missing phone number. Please retry onboarding.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    setState(() {
                                      _isActivating = true;
                                    });

                                    final canContinue =
                                        await _confirmOverwriteIfNeeded();
                                    if (!canContinue) {
                                      if (!context.mounted) return;
                                      setState(() {
                                        _isActivating = false;
                                      });
                                      return;
                                    }

                                    final selectedPlan = plans[_selectedIndex];
                                    final user =
                                        await (widget.registerUser?.call(
                                              _apiService,
                                              phone: _phone,
                                              platformName: _platform,
                                              zone: _pincode.isNotEmpty
                                                  ? _pincode
                                                  : _zone,
                                              planName: selectedPlan.name,
                                              name: _name,
                                            ) ??
                                            _apiService.registerUser(
                                              phone: _phone,
                                              platformName: _platform,
                                              zone: _pincode.isNotEmpty
                                                  ? _pincode
                                                  : _zone,
                                              planName: selectedPlan.name,
                                              name: _name,
                                            ));

                                    if (!context.mounted) return;

                                    setState(() {
                                      _isActivating = false;
                                    });

                                    if (user == null) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Activation failed. Please verify OTP again and retry.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    if (!context.mounted) return;
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      AppRoutes.home,
                                      (route) => false,
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
                                      : _isActivating
                                      ? 'Activating...'
                                      : 'Activate for ₹${plans[_selectedIndex].weeklyPremium}/week',
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
