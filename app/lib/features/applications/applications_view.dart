import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/models.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/metric_badge.dart';
import '../../shared/widgets/app_icon_avatar.dart';
import '../../shared/widgets/usage_chart.dart';
import 'app_details_dialog.dart';

class ApplicationsView extends StatefulWidget {
  final HistoryData? historyData;
  final List<ApplicationUsage> applications;
  final String language;
  final Function(String period, String? start, String? end) onPeriodChanged;
  final VoidCallback onRefresh;

  const ApplicationsView({
    super.key,
    required this.historyData,
    required this.applications,
    required this.language,
    required this.onPeriodChanged,
    required this.onRefresh,
  });

  @override
  State<ApplicationsView> createState() => _ApplicationsViewState();
}

class _ApplicationsViewState extends State<ApplicationsView> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedPeriod = 'today';
  String _selectedSort = 'total';
  String _selectedCategory = 'all';
  DateTimeRange? _customRange;

  final List<Map<String, String>> _periods = [
    {'value': 'today', 'key': 'today'},
    {'value': 'yesterday', 'key': 'yesterday'},
    {'value': '7days', 'key': 'last_7_days'},
    {'value': 'week', 'key': 'this_week'},
    {'value': 'month', 'key': 'this_month'},
    {'value': 'last_month', 'key': 'last_month'},
    {'value': 'year', 'key': 'this_year'},
    {'value': 'custom', 'key': 'custom_range'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.historyData != null && widget.historyData!.period.isNotEmpty) {
      _selectedPeriod = widget.historyData!.period;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = 'custom';
        _customRange = picked;
      });
      final startStr = picked.start.toIso8601String().split('T').first;
      final endStr = picked.end.toIso8601String().split('T').first;
      widget.onPeriodChanged('custom', startStr, endStr);
    }
  }

  void _onPeriodSelect(String period) {
    if (period == 'custom') {
      _pickCustomRange();
    } else {
      setState(() => _selectedPeriod = period);
      widget.onPeriodChanged(period, null, null);
    }
  }

  List<ApplicationUsage> _getFilteredAndSortedApps() {
    final rawApps = widget.applications.isNotEmpty
        ? widget.applications
        : (widget.historyData?.applications ?? []);

    final query = _searchController.text.trim().toLowerCase();

    var list = rawApps.where((app) {
      if (_selectedCategory != 'all' && app.category != _selectedCategory) {
        return false;
      }
      if (query.isEmpty) return true;
      return app.displayName.toLowerCase().contains(query) ||
          app.processName.toLowerCase().contains(query) ||
          app.category.toLowerCase().contains(query);
    }).toList();

    switch (_selectedSort) {
      case 'rx':
        list.sort((a, b) => b.rx.compareTo(a.rx));
        break;
      case 'tx':
        list.sort((a, b) => b.tx.compareTo(a.tx));
        break;
      case 'name':
        list.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        break;
      case 'total':
      default:
        list.sort((a, b) => b.total.compareTo(a.total));
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalRx = widget.historyData?.totalRx ?? 0;
    final totalTx = widget.historyData?.totalTx ?? 0;
    final total = widget.historyData?.total ?? (totalRx + totalTx);
    final chartPoints = widget.historyData?.chartData ?? [];

    final filteredApps = _getFilteredAndSortedApps();
    final maxAppUsage = filteredApps.isNotEmpty
        ? filteredApps.map((a) => a.total).reduce(math.max)
        : 0;

    final sortOptions = [
      {'value': 'total', 'label': AppStrings.get('sort_total', widget.language)},
      {'value': 'rx', 'label': AppStrings.get('sort_download', widget.language)},
      {'value': 'tx', 'label': AppStrings.get('sort_upload', widget.language)},
      {'value': 'name', 'label': AppStrings.get('sort_name', widget.language)},
    ];

    final categoryOptions = [
      {'value': 'all', 'label': AppStrings.get('category_all', widget.language)},
      {'value': 'app', 'label': AppStrings.get('category_apps', widget.language)},
      {'value': 'system', 'label': AppStrings.get('category_system', widget.language)},
    ];

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
                      AppStrings.get('apps_and_usage', widget.language),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.get('apps_and_usage_sub', widget.language),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: widget.onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh (Ctrl+R)',
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                    side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Period Selector Bar
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _periods.map((p) {
                    final isSelected = _selectedPeriod == p['value'];
                    final label = AppStrings.get(p['key']!, widget.language);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => _onPeriodSelect(p['value']!),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryCyan.withOpacity(isDark ? 0.22 : 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(color: AppColors.primaryCyan.withOpacity(0.6), width: 1.2)
                                : Border.all(color: Colors.transparent),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primaryCyan
                                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Summary Badges Card
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.get('total', widget.language),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatBytes(total, lang: widget.language),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 3,
                    child: MetricBadge(
                      type: MetricType.download,
                      label: AppStrings.get('download', widget.language),
                      value: formatBytes(totalRx, lang: widget.language),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 3,
                    child: MetricBadge(
                      type: MetricType.upload,
                      label: AppStrings.get('upload', widget.language),
                      value: formatBytes(totalTx, lang: widget.language),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Historical Trend Chart
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.show_chart_rounded, size: 18, color: AppColors.primaryCyan),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.get('historical_trend', widget.language),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  UsageChart(
                    points: chartPoints,
                    height: 150,
                    language: widget.language,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Applications Section Header & Filter Controls
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.apps_rounded, size: 18, color: AppColors.primaryCyan),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.get('applications', widget.language),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryCyan.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${filteredApps.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryCyan,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Category Chips + Search Box + Sort Dropdown
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: categoryOptions.map((cat) {
                                final isSelected = _selectedCategory == cat['value'];
                                return InkWell(
                                  onTap: () => setState(() => _selectedCategory = cat['value']!),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primaryCyan.withOpacity(isDark ? 0.25 : 0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      cat['label']!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.primaryCyan
                                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          SizedBox(
                            width: 220,
                            height: 38,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                                hintText: AppStrings.get('search_placeholder', widget.language),
                                hintStyle: const TextStyle(fontSize: 11),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 16),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                              ),
                            ),
                          ),

                          Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedSort,
                                icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                                items: sortOptions.map((opt) {
                                  return DropdownMenuItem<String>(
                                    value: opt['value'],
                                    child: Text(
                                      opt['label']!,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedSort = val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Applications List
                  if (filteredApps.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.withOpacity(0.5)),
                            const SizedBox(height: 10),
                            Text(
                              AppStrings.get('no_apps_found', widget.language),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredApps.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final app = filteredApps[idx];
                        final isRankTop = idx < 3;
                        final ratio = maxAppUsage > 0 ? (app.total / maxAppUsage).clamp(0.02, 1.0) : 0.02;

                        return Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B).withOpacity(0.4) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isRankTop
                                  ? AppColors.primaryCyan.withOpacity(0.25)
                                  : (isDark ? AppColors.darkBorder.withOpacity(0.5) : AppColors.lightBorder),
                              width: 1,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => AppDetailsDialog(app: app, language: widget.language),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: isRankTop
                                              ? AppColors.primaryCyan.withOpacity(0.18)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '#${idx + 1}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isRankTop
                                                  ? AppColors.primaryCyan
                                                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      AppIconAvatar(
                                        iconPath: app.iconPath,
                                        processName: app.processName,
                                        category: app.category,
                                        size: 38,
                                      ),
                                      const SizedBox(width: 14),

                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    app.displayName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                if (app.isActive) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.statusActive.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          width: 5,
                                                          height: 5,
                                                          decoration: const BoxDecoration(
                                                            color: AppColors.statusActive,
                                                            shape: BoxShape.circle,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          AppStrings.get('active_now', widget.language),
                                                          style: const TextStyle(
                                                            fontSize: 8.5,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.statusActive,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              app.processName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              AppStrings.get('download', widget.language),
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              '↓ ${formatBytes(app.rx, lang: widget.language)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.downloadColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              AppStrings.get('upload', widget.language),
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              '↑ ${formatBytes(app.tx, lang: widget.language)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.uploadColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      SizedBox(
                                        width: 95,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              AppStrings.get('total', widget.language),
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              formatBytes(app.total, lang: widget.language),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: ratio.toDouble(),
                                      minHeight: 3,
                                      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isRankTop ? AppColors.primaryCyan : AppColors.primaryCyan.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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
