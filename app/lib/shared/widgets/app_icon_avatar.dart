import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/api_service.dart';

class AppIconAvatar extends StatelessWidget {
  final String? iconPath;
  final String processName;
  final String category;
  final double size;

  const AppIconAvatar({
    super.key,
    this.iconPath,
    required this.processName,
    required this.category,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final api = ApiService();
    final iconUrl = api.getIconUrl(iconPath);

    Color bgCategory;
    IconData fallbackIcon;

    if (category == 'system') {
      bgCategory = AppColors.systemProcess.withOpacity(0.15);
      fallbackIcon = Icons.shield_rounded;
    } else if (category == 'unattributed') {
      bgCategory = const Color(0xFF64748B).withOpacity(0.15);
      fallbackIcon = Icons.help_outline_rounded;
    } else {
      bgCategory = AppColors.primaryCyan.withOpacity(0.15);
      final proc = processName.toLowerCase();
      if (proc.contains('chrome') || proc.contains('edge') || proc.contains('firefox') || proc.contains('brave')) {
        fallbackIcon = Icons.language_rounded;
      } else if (proc.contains('python') || proc.contains('dart') || proc.contains('code') || proc.contains('node')) {
        fallbackIcon = Icons.terminal_rounded;
      } else if (proc.contains('discord') || proc.contains('telegram') || proc.contains('slack')) {
        fallbackIcon = Icons.chat_bubble_outline_rounded;
      } else {
        fallbackIcon = Icons.widgets_rounded;
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgCategory,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: iconUrl != null
          ? Image.network(
              iconUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Center(
                child: Icon(fallbackIcon, size: size * 0.55, color: AppColors.primaryCyan),
              ),
            )
          : Center(
              child: Icon(fallbackIcon, size: size * 0.55, color: category == 'system' ? AppColors.systemProcess : AppColors.primaryCyan),
            ),
    );
  }
}
