import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/progress_dots.dart';
import 'payment_flow_arguments.dart';

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  PaymentFlowArguments? _arguments(BuildContext context) {
    return ModalRoute.of(context)?.settings.arguments as PaymentFlowArguments?;
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

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Positioned(
              top: -70,
              right: -40,
              child: _BackgroundOrb(color: AppColors.primary.withOpacity(0.10), size: 220),
            ),
            Positioned(
              bottom: 80,
              left: -60,
              child: _BackgroundOrb(color: AppColors.success.withOpacity(0.08), size: 180),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const _CloseButton(),
                    const SizedBox(height: 24),
                    const ProgressDots(total: 3, current: 2),
                    const SizedBox(height: 28),
                    const Text(
                      'Cover scheduled',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SaatDin has locked in your weekly protection for the upcoming cycle.',
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
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.9, end: 1),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutBack,
                            builder: (context, scale, child) {
                              return Transform.scale(scale: scale, child: child);
                            },
                            child: _SuccessHero(args: args),
                          ),
                          const SizedBox(height: 12),
                          _ReceiptCard(args: args),
                          const SizedBox(height: 12),
                          const _NoteCard(),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
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
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Go to home',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.home_rounded, size: 20),
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
      ),
    );
  }
}

class _SuccessHero extends StatelessWidget {
  final PaymentFlowArguments args;

  const _SuccessHero({required this.args});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
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
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: AppColors.successLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.success.withOpacity(0.2), width: 8),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 58,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Your protection is scheduled',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${args.plan.name} starts with the next weekly cycle for ${args.locationLabel}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _Chip(label: args.paymentMethod, icon: Icons.payment_rounded),
              _Chip(
                label: args.loyaltyDiscountPercent > 0
                    ? '₹${(args.plan.weeklyPremium * (1 - args.loyaltyDiscountPercent / 100)).toStringAsFixed(0)}/week'
                    : '₹${args.plan.weeklyPremium}/week',
                icon: Icons.currency_rupee_rounded,
              ),
              if (args.loyaltyDiscountPercent > 0)
                _Chip(
                  label: '${args.loyaltyDiscountPercent.toStringAsFixed(0)}% loyalty discount',
                  icon: Icons.discount_rounded,
                ),
              const _Chip(label: 'Next weekly cycle', icon: Icons.calendar_month_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final PaymentFlowArguments args;

  const _ReceiptCard({required this.args});

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
            'Payment receipt',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _Row(label: 'Plan', value: args.plan.name),
          _Row(label: 'Payment method', value: args.paymentMethod),
          _Row(label: 'Status', value: 'Successful', valueColor: AppColors.success),
          _Row(label: 'Location', value: args.locationLabel),
          _Row(
            label: 'Weekly debit',
            value: args.loyaltyDiscountPercent > 0
                ? '₹${(args.plan.weeklyPremium * (1 - args.loyaltyDiscountPercent / 100)).toStringAsFixed(0)}'
                : '₹${args.plan.weeklyPremium}',
          ),
          if (args.loyaltyDiscountPercent > 0)
            _Row(
              label: 'Loyalty savings',
              value: '₹${(args.plan.weeklyPremium * args.loyaltyDiscountPercent / 100).toStringAsFixed(0)}/week',
              valueColor: AppColors.success,
            ),
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
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your profile is now active. You can manage coverage, payouts, and cancellations from Home.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Chip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Row({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: 'Home',
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.home,
                (route) => false,
              );
            },
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textPrimary,
            ),
            splashRadius: 20,
            tooltip: 'Home',
          ),
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
