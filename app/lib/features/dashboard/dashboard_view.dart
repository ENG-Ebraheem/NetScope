import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/models.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/metric_badge.dart';
import '../../shared/widgets/app_icon_avatar.dart';
import '../../shared/widgets/usage_chart.dart';
import '../applications/app_details_dialog.dart';

class DashboardView extends StatelessWidget {
  final DashboardData? data;
  final LiveTelemetry? live;
  final String language;
  final VoidCallback onRefresh;

  const DashboardView({
    super.key,
    required this.data,
    this.live,
    required this.language,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final todayRx = data?.todayRx ?? 0;
    final todayTx = data?.todayTx ?? 0;
    final todayTotal = data?.todayTotal ?? 0;

    final dlSpeedRaw = live?.downloadSpeed ?? 0;
    final ulSpeedRaw = live?.uploadSpeed ?? 0;
    final dlSpeed = formatSpeedMbps(dlSpeedRaw, lang: language);
    final ulSpeed = formatSpeedMbps(ulSpeedRaw, lang: language);

    final topApps = (data?.topApps ?? []).take(5).toList();
    final hourlyTrend = data?.hourlyTrend ?? [];
    final peakDl = formatSpeedMbps(live?.peakDownloadSpeed ?? 0, lang: language);
    final peakUl = formatSpeedMbps(live?.peakUploadSpeed ?? 0, lang: language);
    final linkMbps = live?.linkSpeedMbps ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.get('dashboard', language),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppStrings.get('active_profile', language)}: ${live?.profileName ?? AppStrings.get('detecting_network', language)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh Metrics (Ctrl+R)',
                  style: IconButton.styleFrom(
                    backgroundColor:
                        isDark ? AppColors.darkCard : AppColors.lightCard,
                    side: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Top Metrics Row: Today's Usage (50%) | Live Speedometer (50%)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;

                final todayCard = GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryCyan.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 16,
                                      color: AppColors.primaryCyan,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    AppStrings.get('today_usage', language),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryCyan.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  language == 'ar' ? 'اليوم' : 'Today',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryCyan,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            formatBytes(todayTotal, lang: language),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: MetricBadge(
                              type: MetricType.download,
                              label: AppStrings.get('download', language),
                              value: formatBytes(todayRx, lang: language),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MetricBadge(
                              type: MetricType.upload,
                              label: AppStrings.get('upload', language),
                              value: formatBytes(todayTx, lang: language),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                final speedCard = GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: AppColors.statusActive.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.speed_rounded,
                                      size: 16,
                                      color: AppColors.statusActive,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    language == 'ar' ? 'السرعة اللحظية' : 'Current Transfer Speed',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: (live?.monitoringActive ?? true)
                                          ? AppColors.statusActive
                                          : AppColors.alertWarning,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    (live?.monitoringActive ?? true) ? 'LIVE' : 'PAUSED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: (live?.monitoringActive ?? true)
                                          ? AppColors.statusActive
                                          : AppColors.alertWarning,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.downloadColor),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              AppStrings.get('download_speed', language),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dlSpeed,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.downloadColor,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.arrow_upward_rounded, size: 14, color: AppColors.uploadColor),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              AppStrings.get('upload_speed', language),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        ulSpeed,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.uploadColor,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.data_usage_rounded,
                                  size: 13,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    '${AppStrings.get('peak_speed', language)}: ↓ $peakDl • ↑ $peakUl',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (linkMbps > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${AppStrings.get('link_capacity', language)}: $linkMbps Mbps',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );

                if (isWide) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: todayCard),
                        const SizedBox(width: 18),
                        Expanded(child: speedCard),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    todayCard,
                    const SizedBox(height: 18),
                    speedCard,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Middle Section: Top 5 Consuming Applications (No scroll)
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.get('top_apps', language),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        language == 'ar'
                            ? 'ترتيب حسب الأعلى استهلاكاً'
                            : 'Ranked by highest bandwidth',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (topApps.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          AppStrings.get('no_apps_found', language),
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: topApps.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 16),
                      itemBuilder: (context, idx) {
                            final app = topApps[idx];
                            final ratio = todayTotal > 0
                                ? (app.total / todayTotal).clamp(0.0, 1.0)
                                : 0.0;

                            return InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AppDetailsDialog(
                                    app: app,
                                    language: language,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                children: [
                                  AppIconAvatar(
                                    iconPath: app.iconPath,
                                    processName: app.processName,
                                    category: app.category,
                                    size: 38,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                app.displayName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            if (app.category == 'system') ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.systemProcess
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  language == 'ar'
                                                      ? 'نظام'
                                                      : 'System',
                                                  style: const TextStyle(
                                                      fontSize: 9,
                                                      color:
                                                          AppColors.systemProcess,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          app.processName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                '↓ ${formatBytes(app.rx, lang: language)}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        AppColors.downloadColor,
                                                    fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                '↑ ${formatBytes(app.tx, lang: language)}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.uploadColor,
                                                    fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: ratio.toDouble(),
                                            minHeight: 6,
                                            backgroundColor: isDark
                                                ? const Color(0xFF334155)
                                                : const Color(0xFFE2E8F0),
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                    Color>(AppColors.primaryCyan),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      formatBytes(app.total, lang: language),
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bottom Section: Compact 24-Hour Trend Chart
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryCyan.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.show_chart_rounded,
                                size: 15, color: AppColors.primaryCyan),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.get('activity_trend', language),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Text(
                        language == 'ar'
                            ? 'تحديث تلقائي كل ثانية'
                            : 'Auto-updated per second',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  UsageChart(
                    points: hourlyTrend,
                    height: 130,
                    language: language,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
