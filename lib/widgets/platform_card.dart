import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/platform_model.dart';

class PlatformCard extends StatelessWidget {
  final DeliveryPlatform platform;
  final bool isSelected;
  final VoidCallback onTap;

  const PlatformCard({
    super.key,
    required this.platform,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.cardSelectedBackground
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.cardSelectedBorder : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Platform icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: platform.iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                platform.icon,
                color: platform.iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // Platform info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    platform.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${platform.deliveryTime} · ${platform.coverageLevel}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Radio indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.success : AppColors.border,
                  width: 2,
                ),
                color: isSelected ? AppColors.success : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.circle,
                      size: 10,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
