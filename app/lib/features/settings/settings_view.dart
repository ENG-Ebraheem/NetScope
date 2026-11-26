import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/models.dart';
import '../../shared/widgets/glass_card.dart';

class SettingsView extends StatefulWidget {
  final Map<String, String> settings;
  final StorageStats? storageStats;
  final String language;
  final String currentThemeMode;
  final Function(String key, String value) onSettingChanged;
  final Function(String lang) onLanguageChanged;
  final Function(String themeMode) onThemeChanged;
  final VoidCallback onClearHistory;

  const SettingsView({
    super.key,
    required this.settings,
    this.storageStats,
    required this.language,
    this.currentThemeMode = 'dark',
    required this.onSettingChanged,
    required this.onLanguageChanged,
    required this.onThemeChanged,
    required this.onClearHistory,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late TextEditingController _dailyQuotaCtrl;
  late TextEditingController _monthlyQuotaCtrl;

  @override
  void initState() {
    super.initState();
    _dailyQuotaCtrl = TextEditingController(text: widget.settings['daily_quota_mb'] ?? '0');
    _monthlyQuotaCtrl = TextEditingController(text: widget.settings['monthly_quota_mb'] ?? '0');
  }

  @override
  void didUpdateWidget(covariant SettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newDaily = widget.settings['daily_quota_mb'] ?? '0';
    final oldDaily = oldWidget.settings['daily_quota_mb'] ?? '0';
    if (newDaily != oldDaily && _dailyQuotaCtrl.text != newDaily) {
      _dailyQuotaCtrl.text = newDaily;
    }
    final newMonthly = widget.settings['monthly_quota_mb'] ?? '0';
    final oldMonthly = oldWidget.settings['monthly_quota_mb'] ?? '0';
    if (newMonthly != oldMonthly && _monthlyQuotaCtrl.text != newMonthly) {
      _monthlyQuotaCtrl.text = newMonthly;
    }
  }

  @override
  void dispose() {
    _dailyQuotaCtrl.dispose();
    _monthlyQuotaCtrl.dispose();
    super.dispose();
  }

  void _saveQuota(String key, TextEditingController ctrl) {
    final parsed = int.tryParse(ctrl.text.trim()) ?? 0;
    final clean = parsed < 0 ? '0' : parsed.toString();
    ctrl.text = clean;
    widget.onSettingChanged(key, clean);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.language == 'ar' ? 'تم حفظ الإعداد بنجاح' : 'Setting saved'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final language = widget.language;
    final settings = widget.settings;
    final storageStats = widget.storageStats;

    final startWithWindows = settings['start_with_windows'] == 'true';
    final runInBackground = settings['run_in_background'] == 'true';
    final launchMinimized = settings['launch_minimized'] == 'true';
    final usageAlerts = settings['usage_notifications'] == 'true';
    final alertOnNewApp = settings['alert_on_new_app'] == 'true';
    final selectedTheme = settings['theme_mode'] ?? widget.currentThemeMode;
    final themeLabel = selectedTheme == 'system'
        ? AppStrings.get('auto_theme', language)
        : (selectedTheme == 'light'
            ? AppStrings.get('light_theme', language)
            : AppStrings.get('dark_theme', language));
    final themeIcon = selectedTheme == 'system'
        ? Icons.brightness_auto_rounded
        : (selectedTheme == 'light' ? Icons.light_mode_rounded : Icons.dark_mode_rounded);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.get('settings_title', language),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            const SizedBox(height: 24),

            // Section 1: Windows Integration
            _buildSectionHeader(AppStrings.get('startup_section', language)),
            GlassCard(
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: AppStrings.get('start_with_windows', language),
                    subtitle: AppStrings.get('start_with_windows_sub', language),
                    icon: Icons.power_settings_new_rounded,
                    value: startWithWindows,
                    onChanged: (val) => widget.onSettingChanged('start_with_windows', val ? 'true' : 'false'),
                  ),
                  const Divider(height: 24),
                  _buildSwitchTile(
                    title: AppStrings.get('run_in_background', language),
                    subtitle: AppStrings.get('run_in_background_sub', language),
                    icon: Icons.sync_rounded,
                    value: runInBackground,
                    onChanged: (val) => widget.onSettingChanged('run_in_background', val ? 'true' : 'false'),
                  ),
                  const Divider(height: 24),
                  _buildSwitchTile(
                    title: AppStrings.get('launch_minimized', language),
                    subtitle: AppStrings.get('launch_minimized_sub', language),
                    icon: Icons.horizontal_rule_rounded,
                    value: launchMinimized,
                    onChanged: (val) => widget.onSettingChanged('launch_minimized', val ? 'true' : 'false'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: Appearance & Language
            _buildSectionHeader(AppStrings.get('appearance_section', language)),
            GlassCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(themeIcon, size: 22, color: AppColors.primaryCyan),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.get('theme_mode', language),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                themeLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(AppStrings.get('dark_theme', language)),
                            selected: selectedTheme == 'dark',
                            onSelected: (_) {
                              widget.onThemeChanged('dark');
                              widget.onSettingChanged('theme_mode', 'dark');
                            },
                          ),
                          ChoiceChip(
                            label: Text(AppStrings.get('light_theme', language)),
                            selected: selectedTheme == 'light',
                            onSelected: (_) {
                              widget.onThemeChanged('light');
                              widget.onSettingChanged('theme_mode', 'light');
                            },
                          ),
                          ChoiceChip(
                            label: Text(AppStrings.get('auto_theme', language)),
                            selected: selectedTheme == 'system',
                            onSelected: (_) {
                              widget.onThemeChanged('system');
                              widget.onSettingChanged('theme_mode', 'system');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.translate_rounded, size: 22, color: AppColors.primaryCyan),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.get('language', language),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                language == 'ar' ? 'العربية (RTL متكامل)' : 'English (Left-to-Right)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('English'),
                            selected: language == 'en',
                            onSelected: (_) {
                              widget.onLanguageChanged('en');
                              widget.onSettingChanged('language', 'en');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('العربية'),
                            selected: language == 'ar',
                            onSelected: (_) {
                              widget.onLanguageChanged('ar');
                              widget.onSettingChanged('language', 'ar');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 3: Notifications & Quotas
            _buildSectionHeader(AppStrings.get('notifications_section', language)),
            GlassCard(
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: AppStrings.get('usage_alerts', language),
                    subtitle: AppStrings.get('usage_alerts_sub', language),
                    icon: Icons.notifications_active_rounded,
                    value: usageAlerts,
                    onChanged: (val) => widget.onSettingChanged('usage_notifications', val ? 'true' : 'false'),
                  ),
                  if (usageAlerts) ...[
                    const Divider(height: 24),
                    _buildSwitchTile(
                      title: AppStrings.get('alert_on_new_app', language),
                      subtitle: AppStrings.get('alert_on_new_app_sub', language),
                      icon: Icons.fiber_new_rounded,
                      value: alertOnNewApp,
                      onChanged: (val) => widget.onSettingChanged('alert_on_new_app', val ? 'true' : 'false'),
                    ),
                    const Divider(height: 24),
                    _buildQuotaRow(
                      icon: Icons.today_rounded,
                      title: AppStrings.get('daily_quota_mb', language),
                      subtitle: AppStrings.get('daily_quota_sub', language),
                      controller: _dailyQuotaCtrl,
                      onSave: () => _saveQuota('daily_quota_mb', _dailyQuotaCtrl),
                    ),
                    const Divider(height: 24),
                    _buildQuotaRow(
                      icon: Icons.date_range_rounded,
                      title: AppStrings.get('monthly_quota_mb', language),
                      subtitle: AppStrings.get('monthly_quota_sub', language),
                      controller: _monthlyQuotaCtrl,
                      onSave: () => _saveQuota('monthly_quota_mb', _monthlyQuotaCtrl),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 4: Storage & History
            _buildSectionHeader(AppStrings.get('storage_section', language)),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.get('database_size', language),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${storageStats?.sizeMb ?? 0.0} MB',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.get('records_count', language),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(storageStats?.trafficRecordsCount ?? 0) + (storageStats?.hourlyRecordsCount ?? 0)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.get('all_apps', language),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${storageStats?.applicationsCount ?? 0}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.get('clear_history', language),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.alertDanger),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppStrings.get('clear_history_sub', language),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _confirmClearHistory(context),
                        icon: const Icon(Icons.delete_forever_rounded, color: AppColors.alertDanger, size: 18),
                        label: Text(
                          AppStrings.get('clear_history', language),
                          style: const TextStyle(color: AppColors.alertDanger),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.alertDanger),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.2),
      ),
    );
  }

  Widget _buildQuotaRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required VoidCallback onSave,
  }) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.primaryCyan),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
        SizedBox(
          width: 100,
          height: 36,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            onSubmitted: (_) => onSave(),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onSave,
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.primaryCyan),
          tooltip: 'Save',
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.primaryCyan),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primaryCyan,
        ),
      ],
    );
  }

  void _confirmClearHistory(BuildContext context) {
    final language = widget.language;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.get('clear_confirm_title', language)),
        content: Text(AppStrings.get('clear_confirm_msg', language)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.get('cancel', language)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onClearHistory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertDanger,
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.get('clear_btn', language)),
          ),
        ],
      ),
    );
  }
}
