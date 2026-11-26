import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../shared/widgets/custom_sidebar.dart';
import 'dashboard/dashboard_view.dart';
import 'applications/applications_view.dart';
import 'settings/settings_view.dart';
import 'about/about_view.dart';

class MainLayout extends StatefulWidget {
  final Function(String themeMode) onThemeChanged;
  final Function(String lang) onLanguageChanged;
  final String currentLanguage;
  final String currentThemeMode;

  const MainLayout({
    super.key,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.currentLanguage,
    required this.currentThemeMode,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final ApiService _api = ApiService();

  int _currentIndex = 0;
  DashboardData? _dashboardData;
  List<ApplicationUsage> _applications = [];
  HistoryData? _historyData;
  Map<String, String> _settings = {};
  StorageStats? _storageStats;
  LiveTelemetry? _liveTelemetry;

  Timer? _periodicTimer;
  StreamSubscription<LiveTelemetry>? _liveSub;
  String? _lastAlertId;

  String _currentAppPeriod = 'today';
  String _currentHistPeriod = 'today';
  String? _currentHistStart;
  String? _currentHistEnd;

  @override
  void initState() {
    super.initState();
    _initData();
    _startPolling();
  }

  void _initData() {
    _api.initWebSocket();
    _liveSub = _api.liveStream.listen((telemetry) {
      if (!mounted) return;
      setState(() => _liveTelemetry = telemetry);

      final alert = telemetry.latestAlert;
      final alertsEnabled = (_settings['usage_notifications'] ?? 'true') == 'true';
      if (alertsEnabled && alert != null && alert.id.isNotEmpty && alert.id != _lastAlertId) {
        _lastAlertId = alert.id;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${alert.title}: ${alert.message}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
    _fetchAll();
  }

  void _startPolling() {
    _periodicTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _fetchDashboard();
      if (_currentIndex == 1) {
        _fetchApplications();
      }
    });
  }

  Future<void> _fetchAll() async {
    await Future.wait([
      _fetchDashboard(),
      _fetchApplications(),
      _fetchHistory(),
      _fetchSettings(),
      _fetchStorage(),
    ]);
  }

  Future<void> _fetchDashboard() async {
    final d = await _api.getDashboard();
    if (d != null && mounted) {
      setState(() {
        _dashboardData = d;
        _liveTelemetry = d.live;
      });
    }
  }

  Future<void> _fetchApplications() async {
    final apps = await _api.getApplications(
      period: _currentAppPeriod,
      start: _currentHistStart,
      end: _currentHistEnd,
    );
    if (mounted) {
      setState(() => _applications = apps);
    }
  }

  Future<void> _fetchHistory() async {
    final h = await _api.getHistory(
      period: _currentHistPeriod,
      start: _currentHistStart,
      end: _currentHistEnd,
    );
    if (h != null && mounted) {
      setState(() => _historyData = h);
    }
  }

  Future<void> _fetchSettings() async {
    final s = await _api.getSettings();
    if (mounted) {
      setState(() => _settings = s);
    }
  }

  Future<void> _fetchStorage() async {
    final s = await _api.getStorageStats();
    if (mounted) {
      setState(() => _storageStats = s);
    }
  }

  Future<void> _handleUsageAppsPeriodChanged(String period, String? start, String? end) async {
    _currentHistPeriod = period;
    _currentHistStart = start;
    _currentHistEnd = end;
    _currentAppPeriod = period;
    await Future.wait([
      _fetchHistory(),
      _fetchApplications(),
    ]);
  }

  Future<void> _handleToggleMonitoring() async {
    await _api.toggleMonitoring();
    _fetchDashboard();
  }

  Future<void> _handleSettingChanged(String key, String value) async {
    setState(() => _settings[key] = value);
    await _api.setSetting(key, value);
    if (key == 'theme_mode') {
      widget.onThemeChanged(value);
    } else if (key == 'language') {
      widget.onLanguageChanged(value);
    }
    _fetchSettings();
  }

  Future<void> _handleClearHistory() async {
    await _api.clearHistory();
    _fetchAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.currentLanguage == 'ar' ? 'تم مسح سجل البيانات بنجاح' : 'History cleared successfully'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _liveSub?.cancel();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = widget.currentLanguage == 'ar';

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): _fetchAll,
      },
      child: Focus(
        autofocus: true,
        child: Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            body: Row(
              children: [
                CustomSidebar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (idx) {
                    setState(() => _currentIndex = idx);
                    if (idx == 1) {
                      _fetchHistory();
                      _fetchApplications();
                    }
                    if (idx == 2) _fetchStorage();
                  },
                  live: _liveTelemetry,
                  onToggleMonitoring: _handleToggleMonitoring,
                  language: widget.currentLanguage,
                ),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      DashboardView(
                        data: _dashboardData,
                        live: _liveTelemetry,
                        language: widget.currentLanguage,
                        onRefresh: _fetchDashboard,
                      ),
                      ApplicationsView(
                        historyData: _historyData,
                        applications: _applications,
                        language: widget.currentLanguage,
                        onPeriodChanged: _handleUsageAppsPeriodChanged,
                        onRefresh: () async {
                          await Future.wait([
                            _fetchHistory(),
                            _fetchApplications(),
                          ]);
                        },
                      ),
                      SettingsView(
                        settings: _settings,
                        storageStats: _storageStats,
                        language: widget.currentLanguage,
                        currentThemeMode: widget.currentThemeMode,
                        onSettingChanged: _handleSettingChanged,
                        onLanguageChanged: widget.onLanguageChanged,
                        onThemeChanged: widget.onThemeChanged,
                        onClearHistory: _handleClearHistory,
                      ),
                      AboutView(
                        language: widget.currentLanguage,
                        live: _liveTelemetry,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
