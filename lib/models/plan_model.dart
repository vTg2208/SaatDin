class InsurancePlan {
  final String name;
  final int weeklyPremium;
  final int perTriggerPayout;
  final int maxDaysPerWeek;
  final bool isPopular;

  const InsurancePlan({
    required this.name,
    required this.weeklyPremium,
    required this.perTriggerPayout,
    required this.maxDaysPerWeek,
    this.isPopular = false,
  });

  factory InsurancePlan.fromJson(Map<String, dynamic> json) {
    return InsurancePlan(
      name: (json['name'] as String? ?? '').trim(),
      weeklyPremium: (json['weeklyPremium'] as num? ?? 0).toInt(),
      perTriggerPayout: (json['perTriggerPayout'] as num? ?? 0).toInt(),
      maxDaysPerWeek: (json['maxDaysPerWeek'] as num? ?? 0).toInt(),
      isPopular: json['isPopular'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weeklyPremium': weeklyPremium,
      'perTriggerPayout': perTriggerPayout,
      'maxDaysPerWeek': maxDaysPerWeek,
      'isPopular': isPopular,
    };
  }

  static List<InsurancePlan> getPlans() {
    return const [
      InsurancePlan(
        name: 'Basic',
        weeklyPremium: 45,
        perTriggerPayout: 250,
        maxDaysPerWeek: 2,
      ),
      InsurancePlan(
        name: 'Standard',
        weeklyPremium: 69,
        perTriggerPayout: 400,
        maxDaysPerWeek: 3,
        isPopular: true,
      ),
      InsurancePlan(
        name: 'Premium',
        weeklyPremium: 89,
        perTriggerPayout: 550,
        maxDaysPerWeek: 4,
      ),
    ];
  }
}
