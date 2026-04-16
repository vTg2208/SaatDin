import 'package:flutter/material.dart';

import '../../../models/user_model.dart';
import '../../../routes/app_routes.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/progress_dots.dart';
import 'payment_flow_arguments.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final ApiService _apiService = ApiService();
  _PaymentOption _selectedOption = _PaymentOption.upi;
  bool _isProcessing = false;

  PaymentFlowArguments? _arguments(BuildContext context) {
    return ModalRoute.of(context)?.settings.arguments as PaymentFlowArguments?;
  }

  Future<void> _payNow(PaymentFlowArguments args) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final User? user = await _apiService.registerUser(
      phone: args.phone,
      platformName: args.platform,
      zone: args.billingZone,
      planName: args.plan.name,
      name: args.name,
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment could not be completed. Please try again.'),
        ),
      );
      return;
    }

    final discountedAmount =
        (args.plan.weeklyPremium * (1 - args.loyaltyDiscountPercent / 100));

    try {
      await _apiService.recordPremiumPayment(
        amount: discountedAmount,
        status: 'paid',
        providerRef: 'demo-${DateTime.now().millisecondsSinceEpoch}',
        metadata: {
          'source': 'onboarding-payment-flow',
          'paymentMethod': _selectedOption.title,
          'plan': args.plan.name,
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment was captured, but policy sync failed. Please retry once.'),
        ),
      );
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.paymentSuccess,
      arguments: args.copyWith(paymentMethod: _selectedOption.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = _arguments(context);
    if (args == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'Payment details are missing.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            left: -40,
            child: _BackgroundOrb(color: AppColors.primary.withOpacity(0.08), size: 180),
          ),
          Positioned(
            bottom: 110,
            right: -50,
            child: _BackgroundOrb(color: AppColors.accent.withOpacity(0.08), size: 200),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _BackButton(onPressed: () => Navigator.pop(context)),
                  const SizedBox(height: 24),
                  const ProgressDots(total: 3, current: 1),
                  const SizedBox(height: 28),
                  const Text(
                    'Set up weekly debit',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete the weekly debit setup so ${args.plan.name} starts on the upcoming Monday cycle.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: [
                        _AmountCard(args: args),
                        const SizedBox(height: 12),
                        _PaymentMethods(
                          selectedOption: _selectedOption,
                          onSelected: (option) {
                            setState(() {
                              _selectedOption = option;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        const _NoteCard(),
                        const SizedBox(height: 12),
                        if (args.loyaltyDiscountPercent == 0)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.trending_up_rounded, color: AppColors.accent, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Keep your weeks clean and unlock up to 10% discount on your premium.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : () => _payNow(args),
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
                                if (_isProcessing)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                else
                                  const Icon(Icons.lock_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _isProcessing
                                      ? 'Setting up cover...'
                                      : 'Confirm for next cycle · ₹${(args.plan.weeklyPremium * (1 - args.loyaltyDiscountPercent / 100)).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PaymentOption { upi, card, wallet }

extension on _PaymentOption {
  String get title {
    switch (this) {
      case _PaymentOption.upi:
        return 'UPI AutoPay';
      case _PaymentOption.card:
        return 'Debit / Credit Card';
      case _PaymentOption.wallet:
        return 'Wallet';
    }
  }

  String get subtitle {
    switch (this) {
      case _PaymentOption.upi:
        return 'Recommended for weekly debits';
      case _PaymentOption.card:
        return 'Visa, Mastercard and RuPay';
      case _PaymentOption.wallet:
        return 'Use an existing balance';
    }
  }

  IconData get icon {
    switch (this) {
      case _PaymentOption.upi:
        return Icons.qr_code_2_rounded;
      case _PaymentOption.card:
        return Icons.credit_card_rounded;
      case _PaymentOption.wallet:
        return Icons.account_balance_wallet_rounded;
    }
  }
}

class _AmountCard extends StatelessWidget {
  final PaymentFlowArguments args;

  const _AmountCard({required this.args});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      args.plan.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      args.locationLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (args.loyaltyDiscountPercent > 0) ...
                      [
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${args.loyaltyDiscountPercent.toStringAsFixed(0)}% loyalty discount',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Weekly debit',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '₹',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '${(args.plan.weeklyPremium * (1 - args.loyaltyDiscountPercent / 100)).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: AppColors.success, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Secure checkout. Your cover is applied right after payment.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
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

class _PaymentMethods extends StatelessWidget {
  final _PaymentOption selectedOption;
  final ValueChanged<_PaymentOption> onSelected;

  const _PaymentMethods({
    required this.selectedOption,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose payment method',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ..._PaymentOption.values.map((option) {
            final isSelected = option == selectedOption;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelected(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.cardSelectedBackground
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.12)
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          option.icon,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              option.subtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.calendar_month_rounded, color: AppColors.accent, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Once confirmed, your cover starts with the next Monday-to-Sunday cycle until you cancel from Home.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Back',
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 16,
            color: AppColors.textPrimary,
          ),
          splashRadius: 20,
          tooltip: 'Back',
        ),
      ),
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _BackgroundOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
