import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum MetricType { download, upload, total, speed }

class MetricBadge extends StatelessWidget {
  final MetricType type;
  final String label;
  final String value;
  final IconData? customIcon;

  const MetricBadge({
    super.key,
    required this.type,
    required this.label,
    required this.value,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    Color accentColor;
    IconData icon;

    switch (type) {
      case MetricType.download:
        accentColor = AppColors.downloadColor;
        icon = customIcon ?? Icons.arrow_downward_rounded;
        break;
      case MetricType.upload:
        accentColor = AppColors.uploadColor;
        icon = customIcon ?? Icons.arrow_upward_rounded;
        break;
      case MetricType.total:
        accentColor = AppColors.skyBlue;
        icon = customIcon ?? Icons.swap_vert_rounded;
        break;
      case MetricType.speed:
        accentColor = AppColors.primaryCyan;
        icon = customIcon ?? Icons.speed_rounded;
        break;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accentColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
