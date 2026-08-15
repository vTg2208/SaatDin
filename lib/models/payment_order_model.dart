enum PaymentOrderStatus { created, pending, paid, failed, expired, refunded }

class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.status,
    required this.provider,
    required this.amount,
    required this.currency,
    required this.coverageWeekStart,
    required this.expiresAt,
    required this.checkoutData,
  });

  final String id;
  final PaymentOrderStatus status;
  final String provider;
  final double amount;
  final String currency;
  final DateTime coverageWeekStart;
  final DateTime expiresAt;
  final Map<String, dynamic> checkoutData;

  bool get isPaid => status == PaymentOrderStatus.paid;
  bool get isPending =>
      status == PaymentOrderStatus.created ||
      status == PaymentOrderStatus.pending;

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    final id = json['orderId']?.toString() ?? '';
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw const FormatException('Invalid payment order ID.');
    }

    final status = switch (json['status']?.toString().toUpperCase()) {
      'CREATED' => PaymentOrderStatus.created,
      'PENDING' => PaymentOrderStatus.pending,
      'PAID' => PaymentOrderStatus.paid,
      'FAILED' => PaymentOrderStatus.failed,
      'EXPIRED' => PaymentOrderStatus.expired,
      'REFUNDED' => PaymentOrderStatus.refunded,
      _ => throw const FormatException('Invalid payment order status.'),
    };
    final provider = json['provider']?.toString().trim() ?? '';
    if (provider.isEmpty) {
      throw const FormatException('Invalid payment provider.');
    }
    final amount = double.tryParse(json['amount']?.toString() ?? '');
    if (amount == null || !amount.isFinite || amount <= 0) {
      throw const FormatException('Invalid payment amount.');
    }
    final currency = json['currency']?.toString() ?? '';
    if (currency != 'INR') {
      throw const FormatException('Invalid payment currency.');
    }
    final weekStart = DateTime.tryParse(
      json['coverageWeekStart']?.toString() ?? '',
    );
    if (weekStart == null || weekStart.weekday != DateTime.monday) {
      throw const FormatException('Invalid coverage week start.');
    }
    final expiresAt = DateTime.tryParse(json['expiresAt']?.toString() ?? '');
    if (expiresAt == null || !expiresAt.isUtc) {
      throw const FormatException('Invalid payment expiration.');
    }
    final checkout = json['checkoutData'];
    if (checkout is! Map<String, dynamic>) {
      throw const FormatException('Invalid checkout data.');
    }

    return PaymentOrder(
      id: id,
      status: status,
      provider: provider,
      amount: amount,
      currency: currency,
      coverageWeekStart: DateTime.utc(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      ),
      expiresAt: expiresAt,
      checkoutData: Map<String, dynamic>.unmodifiable(checkout),
    );
  }
}
