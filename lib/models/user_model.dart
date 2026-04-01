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

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: (json['name'] as String? ?? '').trim(),
      phone: (json['phone'] as String? ?? '').trim(),
      platform: (json['platform'] as String? ?? '').trim(),
      zone: (json['zone'] as String? ?? '').trim(),
      plan: (json['plan'] as String? ?? '').trim(),
      policyId: (json['policyId'] as String? ?? '').trim(),
      totalEarnings: (json['totalEarnings'] as num? ?? 0).toDouble(),
      earningsProtected: (json['earningsProtected'] as num? ?? 0).toDouble(),
      isVerified: json['isVerified'] == true,
      language: (json['language'] as String? ?? 'English').trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'platform': platform,
      'zone': zone,
      'plan': plan,
      'policyId': policyId,
      'totalEarnings': totalEarnings,
      'earningsProtected': earningsProtected,
      'isVerified': isVerified,
      'language': language,
    };
  }

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
