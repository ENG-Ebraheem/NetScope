import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/models.dart';

class CustomSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final LiveTelemetry? live;
  final VoidCallback onToggleMonitoring;
  final String language;

  const CustomSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.live,
    required this.onToggleMonitoring,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMonitoring = live?.monitoringActive ?? true;

    final navItems = [
      {'icon': Icons.dashboard_rounded, 'label': AppStrings.get('dashboard', language)},
      {'icon': Icons.apps_rounded, 'label': AppStrings.get('apps_and_usage', language)},
      {'icon': Icons.tune_rounded, 'label': AppStrings.get('settings', language)},
      {'icon': Icons.info_outline_rounded, 'label': AppStrings.get('about', language)},
    ];

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          right: language == 'ar'
              ? BorderSide.none
              : BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
          left: language == 'ar'
              ? BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1)
              : BorderSide.none,
        ),
      ),
      child: Column(
        children: [
          // Branding Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryCyan.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/app_icon.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.network(
                        'icons/Icon-192.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.downloadGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.radar_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.get('app_title', language),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'v1.0.0 Windows',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Navigation Links
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final isSelected = selectedIndex == index;
                final item = navItems[index];

                return InkWell(
                  onTap: () => onDestinationSelected(index),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryCyan.withOpacity(isDark ? 0.15 : 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: AppColors.primaryCyan.withOpacity(0.3), width: 1)
                          : Border.all(color: Colors.transparent, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          size: 20,
                          color: isSelected
                              ? AppColors.primaryCyan
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item['label'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primaryCyan
                                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Network Health & Engine Status Card
          Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isMonitoring ? AppColors.statusActive : AppColors.alertWarning,
                        shape: BoxShape.circle,
                        boxShadow: isMonitoring
                            ? [
                                BoxShadow(
                                  color: AppColors.statusActive.withOpacity(0.6),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isMonitoring
                            ? AppStrings.get('status_monitoring', language)
                            : AppStrings.get('status_paused', language),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isMonitoring ? AppColors.statusActive : AppColors.alertWarning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  live?.profileName ?? 'Local Connection',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: onToggleMonitoring,
                    icon: Icon(
                      isMonitoring ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 16,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    label: Text(
                      AppStrings.get('toggle_monitoring', language),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
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
