import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/zone_risk_model.dart';

class ZoneRiskService {
  static const String _runtimeAssetPath = 'assets/data/zone_risk_runtime.json';

  static List<ZoneRisk>? _cache;

  Future<List<ZoneRisk>> getAllZones() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString(_runtimeAssetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final pincodeMap = decoded['pincodes'] as Map<String, dynamic>? ?? {};

    final zones = pincodeMap.entries
        .map((entry) => ZoneRisk.fromJson(
              entry.key,
              entry.value as Map<String, dynamic>,
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    _cache = zones;
    return zones;
  }

  Future<List<ZoneRisk>> getZonesForPlatform(String platformName) async {
    final allZones = await getAllZones();
    return allZones.where((zone) => zone.supportsPlatform(platformName)).toList();
  }

  Future<ZoneRisk?> getByPincode(String pincode) async {
    final allZones = await getAllZones();
    for (final zone in allZones) {
      if (zone.pincode == pincode) return zone;
    }
    return null;
  }

  Future<double?> getMultiplier(String pincode) async {
    final zone = await getByPincode(pincode);
    return zone?.zoneRiskMultiplier;
  }
}
