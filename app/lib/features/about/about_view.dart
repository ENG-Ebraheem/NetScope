import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/models.dart';
import '../../shared/widgets/glass_card.dart';

class AboutView extends StatelessWidget {
  final String language;
  final LiveTelemetry? live;

  const AboutView({
    super.key,
    required this.language,
    this.live,
  });

  static const String _whatsappUrl = 'https://wa.me/HeMo_dev';
  static const String _githubUrl = 'https://github.com/ENG-Ebraheem';

  Future<void> _openExternalUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              language == 'ar' ? 'تعذر فتح الرابط: $url' : 'Could not open link: $url',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              language == 'ar' ? 'تعذر فتح الرابط: $url' : 'Could not open link: $url',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMonitoring = live?.monitoringActive ?? true;

    final colorGuides = [
      {
        'color': AppColors.primaryCyan,
        'title': AppStrings.get('color_cyan_title', language),
        'desc': AppStrings.get('color_cyan_desc', language),
        'icon': Icons.arrow_downward_rounded,
      },
      {
        'color': AppColors.statusActive,
        'title': AppStrings.get('color_green_title', language),
        'desc': AppStrings.get('color_green_desc', language),
        'icon': Icons.arrow_upward_rounded,
      },
      {
        'color': const Color(0xFF0284C7),
        'title': AppStrings.get('color_blue_title', language),
        'desc': AppStrings.get('color_blue_desc', language),
        'icon': Icons.window_rounded,
      },
      {
        'color': const Color(0xFF8B5CF6),
        'title': AppStrings.get('color_purple_title', language),
        'desc': AppStrings.get('color_purple_desc', language),
        'icon': Icons.business_center_rounded,
      },
      {
        'color': const Color(0xFFF59E0B),
        'title': AppStrings.get('color_amber_title', language),
        'desc': AppStrings.get('color_amber_desc', language),
        'icon': Icons.language_rounded,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Text(
              AppStrings.get('about_title', language),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),

            // Hero Brand Card
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryCyan.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/app_icon.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.network(
                          'icons/Icon-512.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.downloadGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.radar_rounded, color: Colors.white, size: 36),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NetScope',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.get('about_version', language),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryCyan,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppStrings.get('tagline', language),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 1: Compact & Elegant Color Guide
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.palette_rounded, size: 17, color: AppColors.primaryCyan),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.get('color_guide_title', language),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AppStrings.get('color_guide_sub', language),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final twoCols = constraints.maxWidth >= 620;
                      final itemWidth = twoCols
                          ? (constraints.maxWidth - 10) / 2
                          : constraints.maxWidth;

                      return Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: colorGuides.map((item) {
                          final col = item['color'] as Color;
                          return Container(
                            width: itemWidth,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? col.withOpacity(0.07)
                                  : col.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: col.withOpacity(0.22), width: 1),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  margin: const EdgeInsets.only(top: 1),
                                  decoration: BoxDecoration(
                                    color: col.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Icon(
                                    item['icon'] as IconData,
                                    size: 14,
                                    color: col,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['title'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: col,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item['desc'] as String,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.3,
                                          color: isDark
                                              ? const Color(0xFFCBD5E1)
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 2: Privacy & Architecture Guarantee
            Row(
              children: [
                const Icon(Icons.verified_user_rounded, size: 20, color: AppColors.statusActive),
                const SizedBox(width: 8),
                Text(
                  AppStrings.get('privacy_title', language),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.statusActive.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.lock_rounded, size: 16, color: AppColors.statusActive),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                AppStrings.get('privacy_offline', language),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.get('privacy_offline_desc', language),
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryCyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primaryCyan),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                AppStrings.get('privacy_light', language),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.get('privacy_light_desc', language),
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 3: Live System Status Overview
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isMonitoring ? AppColors.statusActive : const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isMonitoring ? AppColors.statusActive : const Color(0xFFEF4444))
                                    .withOpacity(0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              language == 'ar' ? 'حالة الخدمة' : 'Service Status',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              isMonitoring
                                  ? AppStrings.get('service_active_badge', language)
                                  : AppStrings.get('service_paused_badge', language),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isMonitoring ? AppColors.statusActive : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_rounded, size: 18, color: AppColors.primaryCyan),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.get('active_profile', language),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              live?.profileName ?? AppStrings.get('detecting_network', language),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryCyan,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.desktop_windows_rounded, size: 18, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              language == 'ar' ? 'بيئة التشغيل' : 'Platform',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const Text(
                              'Windows 10/11 Desktop',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 4: Developer Card (Bottom)
            GlassCard(
              padding: const EdgeInsets.all(22),
              borderColor: AppColors.primaryCyan.withOpacity(0.32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppColors.downloadGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryCyan.withOpacity(0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.code_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryCyan.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                AppStrings.get('developer_section_title', language),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryCyan,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              AppStrings.get('developer_name', language),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppStrings.get('developer_bio', language),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      _buildContactButton(
                        context: context,
                        label: AppStrings.get('contact_whatsapp', language),
                        accentColor: const Color(0xFF25D366),
                        isDark: isDark,
                        icon: const _WhatsAppLogoIcon(size: 18),
                        onTap: () => _openExternalUrl(context, _whatsappUrl),
                      ),
                      _buildContactButton(
                        context: context,
                        label: AppStrings.get('contact_github', language),
                        accentColor: isDark ? Colors.white : const Color(0xFF0F172A),
                        isDark: isDark,
                        icon: _GitHubLogoIcon(
                          size: 18,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        onTap: () => _openExternalUrl(context, _githubUrl),
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

  Widget _buildContactButton({
    required BuildContext context,
    required String label,
    required Color accentColor,
    required bool isDark,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withOpacity(0.35), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.open_in_new_rounded, size: 14, color: accentColor.withOpacity(0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhatsAppLogoIcon extends StatelessWidget {
  final double size;

  const _WhatsAppLogoIcon({this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _WhatsAppBubblePainter(),
          ),
          Icon(
            Icons.phone_rounded,
            size: size * 0.56,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _WhatsAppBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final paint = Paint()
      ..color = const Color(0xFF25D366)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addOval(Rect.fromCircle(center: Offset(12 * s, 11.5 * s), radius: 9.8 * s))
      ..moveTo(5.0 * s, 17.5 * s)
      ..lineTo(2.4 * s, 21.8 * s)
      ..lineTo(7.4 * s, 20.1 * s)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GitHubLogoIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _GitHubLogoIcon({this.size = 18, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GitHubMarkPainter(color),
    );
  }
}

class _GitHubMarkPainter extends CustomPainter {
  final Color color;

  _GitHubMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(12.000 * s, 2.000 * s);
    path.cubicTo(6.477 * s, 2.000 * s, 2.000 * s, 6.484 * s, 2.000 * s, 12.017 * s);
    path.cubicTo(2.000 * s, 16.442 * s, 4.865 * s, 20.197 * s, 8.839 * s, 21.521 * s);
    path.cubicTo(9.339 * s, 21.613 * s, 9.521 * s, 21.304 * s, 9.521 * s, 21.038 * s);
    path.cubicTo(9.521 * s, 20.801 * s, 9.513 * s, 20.170 * s, 9.508 * s, 19.335 * s);
    path.cubicTo(6.726 * s, 19.940 * s, 6.139 * s, 17.992 * s, 6.139 * s, 17.992 * s);
    path.cubicTo(5.685 * s, 16.834 * s, 5.029 * s, 16.526 * s, 5.029 * s, 16.526 * s);
    path.cubicTo(4.121 * s, 15.906 * s, 5.098 * s, 15.918 * s, 5.098 * s, 15.918 * s);
    path.cubicTo(6.101 * s, 15.988 * s, 6.628 * s, 16.950 * s, 6.628 * s, 16.950 * s);
    path.cubicTo(7.520 * s, 18.480 * s, 8.969 * s, 18.038 * s, 9.538 * s, 17.782 * s);
    path.cubicTo(9.630 * s, 17.135 * s, 9.888 * s, 16.694 * s, 10.174 * s, 16.444 * s);
    path.cubicTo(7.954 * s, 16.191 * s, 5.619 * s, 15.331 * s, 5.619 * s, 11.493 * s);
    path.cubicTo(5.619 * s, 10.400 * s, 6.009 * s, 9.505 * s, 6.648 * s, 8.805 * s);
    path.cubicTo(6.545 * s, 8.552 * s, 6.202 * s, 7.533 * s, 6.746 * s, 6.155 * s);
    path.cubicTo(6.746 * s, 6.155 * s, 7.586 * s, 5.885 * s, 9.496 * s, 7.181 * s);
    path.arcToPoint(
      Offset(12.000 * s, 6.844 * s),
      radius: Radius.elliptical(9.564 * s, 9.564 * s),
      rotation: 0.0,
      largeArc: false,
      clockwise: true,
    );
    path.cubicTo(12.850 * s, 6.848 * s, 13.705 * s, 6.959 * s, 14.504 * s, 7.181 * s);
    path.cubicTo(16.413 * s, 5.885 * s, 17.251 * s, 6.154 * s, 17.251 * s, 6.154 * s);
    path.cubicTo(17.797 * s, 7.533 * s, 17.453 * s, 8.552 * s, 17.351 * s, 8.805 * s);
    path.cubicTo(17.991 * s, 9.505 * s, 18.379 * s, 10.400 * s, 18.379 * s, 11.493 * s);
    path.cubicTo(18.379 * s, 15.341 * s, 16.040 * s, 16.188 * s, 13.813 * s, 16.436 * s);
    path.cubicTo(14.172 * s, 16.745 * s, 14.491 * s, 17.356 * s, 14.491 * s, 18.291 * s);
    path.cubicTo(14.491 * s, 19.629 * s, 14.479 * s, 20.710 * s, 14.479 * s, 21.038 * s);
    path.cubicTo(14.479 * s, 21.306 * s, 14.659 * s, 21.618 * s, 15.167 * s, 21.520 * s);
    path.arcToPoint(
      Offset(22.000 * s, 12.017 * s),
      radius: Radius.elliptical(10.019 * s, 10.019 * s),
      rotation: 0.0,
      largeArc: false,
      clockwise: false,
    );
    path.cubicTo(22.000 * s, 6.484 * s, 17.522 * s, 2.000 * s, 12.000 * s, 2.000 * s);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GitHubMarkPainter oldDelegate) => oldDelegate.color != color;
}
