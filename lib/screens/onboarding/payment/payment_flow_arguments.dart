import '../../../models/plan_model.dart';

class PaymentFlowArguments {
  final InsurancePlan plan;
  final String phone;
  final String name;
  final String platform;
  final String zone;
  final String pincode;
  final String paymentMethod;
  final double loyaltyDiscountPercent;

  const PaymentFlowArguments({
    required this.plan,
    required this.phone,
    required this.name,
    required this.platform,
    required this.zone,
    required this.pincode,
    this.paymentMethod = 'UPI AutoPay',
    this.loyaltyDiscountPercent = 0,
  });

  String get billingZone => pincode.isNotEmpty ? pincode : zone;

  String get locationLabel {
    if (pincode.isEmpty) return zone;
    return '$zone · $pincode';
  }

  PaymentFlowArguments copyWith({
    InsurancePlan? plan,
    String? phone,
    String? name,
    String? platform,
    String? zone,
    String? pincode,
    String? paymentMethod,
    double? loyaltyDiscountPercent,
  }) {
    return PaymentFlowArguments(
      plan: plan ?? this.plan,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      zone: zone ?? this.zone,
      pincode: pincode ?? this.pincode,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      loyaltyDiscountPercent: loyaltyDiscountPercent ?? this.loyaltyDiscountPercent,
    );
  }
}
