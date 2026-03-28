class User {
  final String name;
  final String phone;
  final String platform;
  final String zone;
  final String plan;
  final String policyId;
  final double totalEarnings;
  final double earningsProtected;
  final bool isVerified;
  final String language;

  const User({
    required this.name,
    required this.phone,
    required this.platform,
    required this.zone,
    required this.plan,
    required this.policyId,
    required this.totalEarnings,
    required this.earningsProtected,
    required this.isVerified,
    this.language = 'English',
  });

  static User getMockUser() {
    return const User(
      name: 'Arjun Singh',
      phone: '98765 43210',
      platform: 'Blinkit',
      zone: 'Bellandur',
      plan: 'Standard',
      policyId: 'SR-9921',
      totalEarnings: 42850.00,
      earningsProtected: 1240.50,
      isVerified: true,
      language: 'English',
    );
  }
}
