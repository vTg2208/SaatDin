import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final TextEditingController _upiIdController = TextEditingController();
  static const List<String> _commonUpiHandles = <String>[
    '@ybl',
    '@ibl',
    '@axl',
    '@okaxis',
    '@okhdfcbank',
    '@okicici',
    '@oksbi',
    '@paytm',
    '@upi',
  ];

  _PaymentOption _selectedOption = _PaymentOption.upi;
  _UpiApp _selectedUpiApp = _UpiApp.paytm;
  bool _isProcessing = false;

  PaymentFlowArguments? _arguments(BuildContext context) {
    return ModalRoute.of(context)?.settings.arguments as PaymentFlowArguments?;
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    super.dispose();
  }

  String _withSelectedHandle(String input, String handle) {
    final normalizedHandle = handle.startsWith('@') ? handle : '@$handle';
    final value = input.trim().toLowerCase();
    if (value.isEmpty) {
      return 'name$normalizedHandle';
    }

    final atIndex = value.indexOf('@');
    if (atIndex == -1) {
      return '$value$normalizedHandle';
    }

    final userPart = value.substring(0, atIndex).trim();
    return '${userPart.isEmpty ? 'name' : userPart}$normalizedHandle';
  }

  Future<void> _payNow(PaymentFlowArguments args) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final discountedAmount =
        (args.plan.weeklyPremium * (1 - args.loyaltyDiscountPercent / 100));

    if (_selectedOption == _PaymentOption.upi) {
      final launched = await _launchSelectedUpiApp(args, discountedAmount);
      if (!launched) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open ${_selectedUpiApp.label}. Please check if the app is installed.'),
          ),
        );
        return;
      }
    }

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

    try {
      await _apiService.recordPremiumPayment(
        amount: discountedAmount,
        status: 'paid',
        providerRef: 'demo-${DateTime.now().millisecondsSinceEpoch}',
        metadata: {
          'source': 'onboarding-payment-flow',
          'paymentMethod': _selectedOption.title,
          if (_selectedOption == _PaymentOption.upi) 'upiApp': _selectedUpiApp.label,
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

  Future<bool> _launchSelectedUpiApp(PaymentFlowArguments args, double amount) async {
    if (kIsWeb) {
      return false;
    }

    final params = <String, String>{
      'pa': 'saatdin@okaxis',
      'pn': 'SaatDin',
      'tn': 'Weekly premium - ${args.plan.name}',
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      'tr': 'SD-${DateTime.now().millisecondsSinceEpoch}',
    };

    final appUri = _buildAppSpecificUpiUri(params);
    final launchedApp = await launchUrl(
      appUri,
      mode: LaunchMode.externalApplication,
    );
    if (launchedApp) {
      return true;
    }

    final genericUri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: params,
    );
    return launchUrl(genericUri, mode: LaunchMode.externalApplication);
  }

  Uri _buildAppSpecificUpiUri(Map<String, String> params) {
    switch (_selectedUpiApp) {
      case _UpiApp.paytm:
        return Uri(
          scheme: 'paytmmp',
          host: 'pay',
          queryParameters: params,
        );
      case _UpiApp.phonepe:
        return Uri(
          scheme: 'phonepe',
          host: 'pay',
          queryParameters: params,
        );
      case _UpiApp.googlePay:
        return Uri(
          scheme: 'tez',
          host: 'upi',
          path: '/pay',
          queryParameters: params,
        );
      case _UpiApp.custom:
        return Uri(
          scheme: 'upi',
          host: 'pay',
          queryParameters: params,
        );
    }
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
            child: _BackgroundOrb(
              color: AppColors.primary.withOpacity(0.08),
              size: 180,
            ),
          ),
          Positioned(
            bottom: 110,
            right: -50,
            child: _BackgroundOrb(
              color: AppColors.accent.withOpacity(0.08),
              size: 200,
            ),
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
                        _PaymentDetailsCard(
                          selectedOption: _selectedOption,
                          selectedUpiApp: _selectedUpiApp,
                          isProcessing: _isProcessing,
                          onProceed: () => _payNow(args),
                          onUpiAppSelected: (app) {
                            setState(() {
                              _selectedUpiApp = app;
                            });
                          },
                          upiIdController: _upiIdController,
                          commonUpiHandles: _commonUpiHandles,
                          onUpiHandleTap: (handle) {
                            final next = _withSelectedHandle(_upiIdController.text, handle);
                            setState(() {
                              _upiIdController.value = TextEditingValue(
                                text: next,
                                selection: TextSelection.collapsed(offset: next.length),
                              );
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
                                Icon(Icons.trending_up_rounded,
                                    color: AppColors.accent, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Keep paying for 4 weeks straight and unlock up to 10% discount on your premium.',
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

enum _UpiApp { paytm, phonepe, googlePay, custom }

extension on _UpiApp {
  String get label {
    switch (this) {
      case _UpiApp.paytm:
        return 'Paytm';
      case _UpiApp.phonepe:
        return 'PhonePe';
      case _UpiApp.googlePay:
        return 'Google Pay';
      case _UpiApp.custom:
        return 'Custom UPI';
    }
  }

  Widget get icon {
    switch (this) {
      case _UpiApp.paytm:
        return const _PaytmLogo();
      case _UpiApp.phonepe:
        return const _PhonePeLogo();
      case _UpiApp.googlePay:
        return const _GooglePayLogo();
      case _UpiApp.custom:
        return const _CustomUpiLogo();
    }
  }
}

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

  Widget get icon {
    switch (this) {
      case _PaymentOption.upi:
        return const _UpiBadgeIcon();
      case _PaymentOption.card:
        return const Icon(Icons.credit_card_rounded);
      case _PaymentOption.wallet:
        return const Icon(Icons.account_balance_wallet_rounded);
    }
  }
}

class _UpiBadgeIcon extends StatelessWidget {
  const _UpiBadgeIcon();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/images/upi.png',
        width: 28,
        height: 28,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _PaymentDetailsCard extends StatelessWidget {
  final _PaymentOption selectedOption;
  final _UpiApp selectedUpiApp;
  final bool isProcessing;
  final VoidCallback onProceed;
  final ValueChanged<_UpiApp> onUpiAppSelected;
  final TextEditingController upiIdController;
  final List<String> commonUpiHandles;
  final ValueChanged<String> onUpiHandleTap;

  const _PaymentDetailsCard({
    required this.selectedOption,
    required this.selectedUpiApp,
    required this.isProcessing,
    required this.onProceed,
    required this.onUpiAppSelected,
    required this.upiIdController,
    required this.commonUpiHandles,
    required this.onUpiHandleTap,
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
          Text(
            _title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _buildForm(),
          if (selectedOption != _PaymentOption.upi) ...[
            const SizedBox(height: 16),
            _ProceedToPaymentButton(
              isProcessing: isProcessing,
              onPressed: onProceed,
            ),
          ],
        ],
      ),
    );
  }

  String get _title {
    switch (selectedOption) {
      case _PaymentOption.upi:
        return 'Enter UPI details';
      case _PaymentOption.card:
        return 'Enter card details';
      case _PaymentOption.wallet:
        return 'Enter wallet details';
    }
  }

  Widget _buildForm() {
    switch (selectedOption) {
      case _PaymentOption.upi:
        return _UpiDetailsForm(
          selectedUpiApp: selectedUpiApp,
          isProcessing: isProcessing,
          onProceed: onProceed,
          onUpiAppSelected: onUpiAppSelected,
          upiIdController: upiIdController,
          commonUpiHandles: commonUpiHandles,
          onUpiHandleTap: onUpiHandleTap,
        );
      case _PaymentOption.card:
        return const _CardDetailsForm();
      case _PaymentOption.wallet:
        return const _WalletDetailsForm();
    }
  }
}

class _UpiDetailsForm extends StatelessWidget {
  final _UpiApp selectedUpiApp;
  final bool isProcessing;
  final VoidCallback onProceed;
  final ValueChanged<_UpiApp> onUpiAppSelected;
  final TextEditingController upiIdController;
  final List<String> commonUpiHandles;
  final ValueChanged<String> onUpiHandleTap;

  const _UpiDetailsForm({
    required this.selectedUpiApp,
    required this.isProcessing,
    required this.onProceed,
    required this.onUpiAppSelected,
    required this.upiIdController,
    required this.commonUpiHandles,
    required this.onUpiHandleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pay with',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ..._buildUpiAppOptions(),
        const SizedBox(height: 10),
        _CustomUpiBox(
          selected: selectedUpiApp == _UpiApp.custom,
          onTap: () => onUpiAppSelected(_UpiApp.custom),
        ),
        const SizedBox(height: 10),
        if (selectedUpiApp != _UpiApp.custom)
          Text(
            'Amount will be pre-filled in ${selectedUpiApp.label}. You only need to authorize payment in the app.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          )
        else ...[
          _PaymentInputField(
            label: 'Custom UPI ID',
            hint: 'name@bank',
            controller: upiIdController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          const Text(
            'Common handles',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: commonUpiHandles.map((handle) {
              return ActionChip(
                label: Text(handle),
                onPressed: () => onUpiHandleTap(handle),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _ProceedToPaymentButton(
            isProcessing: isProcessing,
            onPressed: onProceed,
          ),
        ],
      ],
    );
  }

  List<Widget> _buildUpiAppOptions() {
    final widgets = <Widget>[];

    for (final app in _UpiApp.values.where((value) => value != _UpiApp.custom)) {
      final isSelected = app == selectedUpiApp;

      widgets.add(
        _UpiAppChip(
          app: app,
          selected: isSelected,
          onTap: () => onUpiAppSelected(app),
        ),
      );

      if (isSelected) {
        widgets.add(const SizedBox(height: 10));
        widgets.add(
          _ProceedToPaymentButton(
            isProcessing: isProcessing,
            onPressed: onProceed,
            label: 'Proceed with ${app.label}',
          ),
        );
      }

      widgets.add(const SizedBox(height: 10));
    }

    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }

    return widgets;
  }
}

class _ProceedToPaymentButton extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onPressed;
  final String label;

  const _ProceedToPaymentButton({
    required this.isProcessing,
    required this.onPressed,
    this.label = 'Proceed to Payment',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isProcessing ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(62),
          padding: const EdgeInsets.symmetric(vertical: 26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isProcessing)
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
              isProcessing ? 'Setting up cover...' : label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomUpiBox extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _CustomUpiBox({
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.cardSelectedBackground : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderLight,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: _CustomUpiLogo(),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom UPI',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Enter a custom UPI ID',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _UpiAppChip extends StatelessWidget {
  final _UpiApp app;
  final bool selected;
  final VoidCallback onTap;

  const _UpiAppChip({
    required this.app,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.cardSelectedBackground : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderLight,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: app.icon,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Tap to pay via ${app.label}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _PaytmLogo extends StatelessWidget {
  const _PaytmLogo();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/images/paytm.png',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _PhonePeLogo extends StatelessWidget {
  const _PhonePeLogo();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/images/phonepe.png',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _GooglePayLogo extends StatelessWidget {
  const _GooglePayLogo();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/images/googlepay.png',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _CustomUpiLogo extends StatelessWidget {
  const _CustomUpiLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Icon(
        Icons.edit_rounded,
        size: 14,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _CardDetailsForm extends StatelessWidget {
  const _CardDetailsForm();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _CardBrandChip(
              label: 'Mastercard',
              assetPath: 'assets/images/mastercard.png',
              onTap: () {},
            ),
            _CardBrandChip(
              label: 'Visa',
              assetPath: 'assets/images/visa.svg',
              isSvg: true,
              onTap: () {},
            ),
            _CardBrandChip(
              label: 'Apple Pay',
              assetPath: 'assets/images/applepay.png',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _PaymentInputField(
          label: 'Card number',
          hint: '1234 5678 9012 3456',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Expanded(
              child: _PaymentInputField(
                label: 'Expiry',
                hint: 'MM/YY',
                keyboardType: TextInputType.datetime,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _PaymentInputField(
                label: 'CVV',
                hint: '123',
                keyboardType: TextInputType.number,
                obscureText: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const _PaymentInputField(
          label: 'Cardholder name',
          hint: 'Name on card',
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }
}

class _WalletDetailsForm extends StatelessWidget {
  const _WalletDetailsForm();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _PaymentInputField(
          label: 'Wallet provider',
          hint: 'Paytm / PhonePe / Amazon Pay',
        ),
        SizedBox(height: 10),
        _PaymentInputField(
          label: 'Mobile number linked to wallet',
          hint: '10-digit mobile number',
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }
}

class _CardBrandChip extends StatelessWidget {
  final String label;
  final String? assetPath;
  final bool isSvg;
  final VoidCallback? onTap;

  const _CardBrandChip({
    required this.label,
    this.assetPath,
    this.isSvg = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Center(
            child: assetPath == null
                ? Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  )
                : isSvg
                    ? SvgPicture.asset(
                        assetPath!,
                        height: 24,
                        fit: BoxFit.contain,
                      )
                    : Image.asset(
                        assetPath!,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
          ),
        ),
      ),
    );
  }
}

class _PaymentInputField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextCapitalization textCapitalization;

  const _PaymentInputField({
    required this.label,
    required this.hint,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
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
          //const SizedBox(height: 16),
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
                        child: Center(
                          child: IconTheme(
                            data: IconThemeData(
                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                              size: 22,
                            ),
                            child: option.icon,
                          ),
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
