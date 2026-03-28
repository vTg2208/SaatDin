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
