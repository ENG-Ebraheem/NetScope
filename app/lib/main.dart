import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/main_layout.dart';
import 'services/api_service.dart';
import 'services/local_storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NetScopeApp());
}

class NetScopeApp extends StatefulWidget {
  const NetScopeApp({super.key});

  @override
  State<NetScopeApp> createState() => _NetScopeAppState();
}

class _NetScopeAppState extends State<NetScopeApp> {
  final ApiService _api = ApiService();
  String _themeSetting = 'dark';
  String _currentLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _loadInitialSettings();
  }

  ThemeMode _resolveThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  void _loadInitialSettings() {
    final savedLang = LocalStorageService.get('netscope_lang');
    if (savedLang == 'ar' || savedLang == 'en') {
      _currentLanguage = savedLang!;
    }
    final savedTheme = LocalStorageService.get('netscope_theme');
    if (savedTheme == 'light' || savedTheme == 'dark' || savedTheme == 'system') {
      _themeSetting = savedTheme!;
    }

    _api.getSettings().then((settings) {
      if (!mounted) return;
      setState(() {
        final lang = settings['language'];
        if (lang == 'ar' || lang == 'en') {
          _currentLanguage = lang!;
          LocalStorageService.set('netscope_lang', lang);
        }
        final theme = settings['theme_mode'];
        if (theme == 'light' || theme == 'dark' || theme == 'system') {
          _themeSetting = theme!;
          LocalStorageService.set('netscope_theme', theme);
        }
      });
    });
  }

  void _handleThemeChanged(String mode) {
    final normalized = (mode == 'light' || mode == 'system') ? mode : 'dark';
    setState(() {
      _themeSetting = normalized;
    });
    LocalStorageService.set('netscope_theme', normalized);
    _api.setSetting('theme_mode', normalized);
  }

  void _handleLanguageChanged(String lang) {
    setState(() {
      _currentLanguage = lang;
    });
    LocalStorageService.set('netscope_lang', lang);
    _api.setSetting('language', lang);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetScope - Windows Internet Usage Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _resolveThemeMode(_themeSetting),
      home: MainLayout(
        onThemeChanged: _handleThemeChanged,
        onLanguageChanged: _handleLanguageChanged,
        currentLanguage: _currentLanguage,
        currentThemeMode: _themeSetting,
      ),
    );
  }
}
