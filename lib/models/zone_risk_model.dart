class ZoneRisk {
  final String pincode;
  final String name;
  final double lat;
  final double lon;
  final bool blinkit;
  final bool zepto;
  final bool swiggyInstamart;
  final double floodRiskScore;
  final double aqiRiskScore;
  final double trafficCongestionScore;
  final double compositeRiskScore;
  final double zoneRiskMultiplier;
  final String riskTier;
  final int customRainLockThresholdMm3hr;

  const ZoneRisk({
    required this.pincode,
    required this.name,
    required this.lat,
    required this.lon,
    required this.blinkit,
    required this.zepto,
    required this.swiggyInstamart,
    required this.floodRiskScore,
    required this.aqiRiskScore,
    required this.trafficCongestionScore,
    required this.compositeRiskScore,
    required this.zoneRiskMultiplier,
    required this.riskTier,
    required this.customRainLockThresholdMm3hr,
  });

  factory ZoneRisk.fromJson(String pincode, Map<String, dynamic> json) {
    final coordinates = (json['coordinates_approx'] as Map<String, dynamic>? ?? {});
    final stores = (json['dark_stores'] as Map<String, dynamic>? ?? {});

    return ZoneRisk(
      pincode: pincode,
      name: (json['name'] as String? ?? '').trim(),
      lat: (coordinates['lat'] as num? ?? 0).toDouble(),
      lon: (coordinates['lon'] as num? ?? 0).toDouble(),
      blinkit: stores['Blinkit'] == true,
      zepto: stores['Zepto'] == true,
      swiggyInstamart: stores['Swiggy_Instamart'] == true,
      floodRiskScore: (json['flood_risk_score'] as num? ?? 0).toDouble(),
      aqiRiskScore: (json['aqi_risk_score'] as num? ?? 0).toDouble(),
      trafficCongestionScore:
          (json['traffic_congestion_score'] as num? ?? 0).toDouble(),
      compositeRiskScore: (json['composite_risk_score'] as num? ?? 0).toDouble(),
      zoneRiskMultiplier: (json['zone_risk_multiplier'] as num? ?? 1).toDouble(),
      riskTier: (json['risk_tier'] as String? ?? 'MEDIUM').trim(),
      customRainLockThresholdMm3hr:
          (json['custom_rainlock_threshold_mm_3hr'] as num? ?? 35).toInt(),
    );
  }

  factory ZoneRisk.fromApiJson(Map<String, dynamic> json) {
    final supports = (json['supports'] as Map<String, dynamic>? ?? {});
    return ZoneRisk(
      pincode: (json['pincode'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      lat: 0,
      lon: 0,
      blinkit: supports['blinkit'] == true,
      zepto: supports['zepto'] == true,
      swiggyInstamart: supports['swiggyInstamart'] == true,
      floodRiskScore: 0,
      aqiRiskScore: 0,
      trafficCongestionScore: 0,
      compositeRiskScore: 0,
      zoneRiskMultiplier: (json['zoneRiskMultiplier'] as num? ?? 1).toDouble(),
      riskTier: (json['riskTier'] as String? ?? 'MEDIUM').trim(),
      customRainLockThresholdMm3hr:
          (json['customRainLockThresholdMm3hr'] as num? ?? 35).toInt(),
    );
  }

  bool supportsPlatform(String platformName) {
    switch (platformName.toLowerCase()) {
      case 'blinkit':
        return blinkit;
      case 'zepto':
        return zepto;
      case 'swiggy instamart':
      case 'swiggy_instamart':
      case 'instamart':
        return swiggyInstamart;
      default:
        return false;
    }
  }
}
