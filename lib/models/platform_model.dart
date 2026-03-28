import 'package:flutter/material.dart';

class DeliveryPlatform {
  final String name;
  final String deliveryTime;
  final String coverageLevel;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  const DeliveryPlatform({
    required this.name,
    required this.deliveryTime,
    required this.coverageLevel,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  static List<DeliveryPlatform> getPlatforms() {
    return [
      const DeliveryPlatform(
        name: 'Blinkit',
        deliveryTime: '10-min delivery',
        coverageLevel: 'Higher coverage',
        icon: Icons.delivery_dining,
        iconColor: Color(0xFFE23744),
        iconBackground: Color(0xFFFFF0F0),
      ),
      const DeliveryPlatform(
        name: 'Zepto',
        deliveryTime: '10-min delivery',
        coverageLevel: 'Higher coverage',
        icon: Icons.flash_on,
        iconColor: Color(0xFFF7941D),
        iconBackground: Color(0xFFFFF8EC),
      ),
      const DeliveryPlatform(
        name: 'Swiggy Instamart',
        deliveryTime: '30-min delivery',
        coverageLevel: 'Standard coverage',
        icon: Icons.favorite,
        iconColor: Color(0xFFFC8019),
        iconBackground: Color(0xFFFFF0E6),
      ),
    ];
  }
}
