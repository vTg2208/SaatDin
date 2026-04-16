import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/progress_dots.dart';
import 'payment_flow_arguments.dart';

class PaymentConfirmScreen extends StatelessWidget {
  const PaymentConfirmScreen({super.key});

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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: _BackgroundOrb(color: AppColors.primary.withOpacity(0.08)),
          ),
          Positioned(
            bottom: 120,
            left: -50,
            child: _BackgroundOrb(color: AppColors.accent.withOpacity(0.08), size: 180),
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
                  const ProgressDots(total: 3, current: 0),
                  const SizedBox(height: 28),
                  const Text(
                    'Confirm your cover',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Review the cover that starts with the upcoming weekly cycle before you continue.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: [
                        _SummaryCard(args: args),
                        const SizedBox(height: 12),
                        _DetailsCard(args: args),
                        const SizedBox(height: 12),
                        const _NoteCard(
                          title: 'Weekly debit',
                          text: 'Your cover begins on the next weekly cycle. You can cancel anytime from Home.',
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.paymentMethod,
                                arguments: args,
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
                                  'Continue to payment setup',
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final PaymentFlowArguments args;

  const _SummaryCard({required this.args});

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (args.plan.isPopular)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Most popular',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    if (args.plan.isPopular) const SizedBox(height: 10),
                    Text(
                      args.plan.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${args.platform} cover for ${args.locationLabel}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
                        '${args.plan.weeklyPremium}',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    '/week',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                icon: Icons.flash_on_rounded,
                label: '₹${args.plan.perTriggerPayout} per trigger',
              ),
              _Chip(
                icon: Icons.event_available_rounded,
                label: '${args.plan.maxDaysPerWeek} days/week',
              ),
              _Chip(
                icon: Icons.lock_rounded,
                label: 'Auto-debit enabled',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final PaymentFlowArguments args;

  const _DetailsCard({required this.args});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Coverage snapshot',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _DetailRow(label: 'Name', value: args.name.isEmpty ? 'Your profile' : args.name),
          _DetailRow(label: 'Phone', value: args.phone),
          _DetailRow(label: 'Platform', value: args.platform),
          _DetailRow(label: 'Zone', value: args.locationLabel),
          _DetailRow(label: 'Billing', value: 'Every Monday via UPI'),
          if (args.loyaltyDiscountPercent > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _DetailRow(
                label: 'Loyalty discount',
                value: '- ${args.loyaltyDiscountPercent.toStringAsFixed(0)}%',
              ),
            ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String title;
  final String text;

  const _NoteCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
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

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderLight),
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _BackgroundOrb({required this.color, this.size = 220});

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
