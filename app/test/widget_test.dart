import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';
import 'package:app/models/models.dart';
import 'package:app/core/localization/app_localizations.dart';
import 'package:app/features/dashboard/dashboard_view.dart';
import 'package:app/features/about/about_view.dart';
import 'package:app/features/settings/settings_view.dart';

void main() {
  test('formatBytes and formatSpeedMbps formatting checks', () {
    expect(formatBytes(512.7, lang: 'en'), '513 B');
    expect(formatBytes(2048, lang: 'en'), '2.0 KB');
    expect(formatBytes(1048576, lang: 'en'), '1.00 MB');
    expect(formatBytes(1048576, lang: 'ar'), '1.00 م.بايت');
    expect(formatSpeedMbps(0), '0.00 Mbps');
    expect(formatSpeedMbps(62500), '500.0 Kbps');
    expect(formatSpeedMbps(1875000), '15.00 Mbps');
  });

  test('AppStrings provides both EN and AR translations', () {
    expect(AppStrings.get('dashboard', 'en'), 'Dashboard');
    expect(AppStrings.get('dashboard', 'ar'), 'لوحة المعلومات');
    expect(AppStrings.get('category_all', 'ar'), 'الكل');
    expect(AppStrings.get('developer_name', 'ar'), 'إبراهيم أحمد المقبلي');
    expect(AppStrings.get('developer_name', 'en'), 'Ebrahim Ahmed Al-Moqbily');
  });

  testWidgets('NetScopeApp desktop layout test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NetScopeApp());
    expect(find.byType(NetScopeApp), findsOneWidget);
    expect(find.text('()'), findsNothing);
    expect(find.textContaining('Hemo_4G'), findsNothing);
  });

  testWidgets('DashboardView displays clean speed figures without byte parens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final live = LiveTelemetry(
      monitoringActive: true,
      paused: false,
      profileName: 'Wi-Fi Test',
      downloadSpeed: 2048,
      uploadSpeed: 1024,
      downloadSpeedFormatted: '2.0 KB/s',
      uploadSpeedFormatted: '1.0 KB/s',
      activeAppsCount: 2,
      totalAppsMonitored: 5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardView(
          data: null,
          live: live,
          language: 'en',
          onRefresh: () {},
        ),
      ),
    );

    expect(find.text('()'), findsNothing);
    expect(find.text('16.4 Kbps'), findsOneWidget);
    expect(find.text('8.2 Kbps'), findsOneWidget);
    expect(find.textContaining('B/s)'), findsNothing);
    expect(find.textContaining('Wi-Fi Test'), findsOneWidget);
  });

  testWidgets('AboutView renders developer card and contact buttons in AR and EN', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: AboutView(language: 'ar'),
      ),
    );

    expect(find.text('إبراهيم أحمد المقبلي'), findsOneWidget);
    expect(find.textContaining('رفيقك اليومي لمتابعة سرعة واستهلاك الإنترنت'), findsOneWidget);
    expect(find.text('واتساب'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: AboutView(language: 'en'),
      ),
    );

    expect(find.text('Ebrahim Ahmed Al-Moqbily'), findsOneWidget);
    expect(find.textContaining('daily companion for tracking internet speed'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
  });

  testWidgets('SettingsView renders Dark, Light, and Like Windows theme chips', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsView(
          settings: const {'theme_mode': 'system'},
          language: 'en',
          currentThemeMode: 'system',
          onSettingChanged: (_, __) {},
          onLanguageChanged: (_) {},
          onThemeChanged: (_) {},
          onClearHistory: () {},
        ),
      ),
    );

    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('System'), findsNWidgets(2));
  });
}
