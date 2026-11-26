import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_icon_avatar.dart';
import '../../shared/widgets/metric_badge.dart';

class AppDetailsDialog extends StatefulWidget {
  final ApplicationUsage app;
  final String language;

  const AppDetailsDialog({
    super.key,
    required this.app,
    required this.language,
  });

  @override
  State<AppDetailsDialog> createState() => _AppDetailsDialogState();
}

class _AppDetailsDialogState extends State<AppDetailsDialog> {
  final ApiService _api = ApiService();
  List<ActiveConnection> _connections = [];
  bool _loadingConnections = true;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    final conns = await _api.getActiveConnections(appId: widget.app.appId);
    if (mounted) {
      setState(() {
        _connections = conns;
        _loadingConnections = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final app = widget.app;
    final language = widget.language;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  AppIconAvatar(
                    iconPath: app.iconPath,
                    processName: app.processName,
                    category: app.category,
                    size: 52,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.displayName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          app.processName,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: AppStrings.get('close', language),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),

              // Metrics Summary Badges
              Row(
                children: [
                  Expanded(
                    child: MetricBadge(
                      type: MetricType.download,
                      label: AppStrings.get('download', language),
                      value: formatBytes(app.rx, lang: language),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricBadge(
                      type: MetricType.upload,
                      label: AppStrings.get('upload', language),
                      value: formatBytes(app.tx, lang: language),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricBadge(
                      type: MetricType.total,
                      label: AppStrings.get('total', language),
                      value: formatBytes(app.total, lang: language),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Metadata rows
              _buildDetailRow(
                context,
                icon: Icons.folder_open_rounded,
                label: AppStrings.get('executable_path', language),
                value: app.executablePath.isNotEmpty ? app.executablePath : 'N/A',
                selectable: true,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                icon: Icons.category_rounded,
                label: AppStrings.get('category', language),
                value: app.category == 'system'
                    ? AppStrings.get('system_traffic', language)
                    : (app.category == 'unattributed'
                        ? AppStrings.get('unattributed_traffic', language)
                        : (language == 'ar' ? 'تطبيق مستخدم' : 'User Application')),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                icon: Icons.history_toggle_off_rounded,
                label: AppStrings.get('first_seen', language),
                value: app.firstSeen ?? 'N/A',
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                icon: Icons.access_time_rounded,
                label: AppStrings.get('last_seen', language),
                value: app.lastSeen ?? 'N/A',
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // Active Connections Section
              Row(
                children: [
                  const Icon(Icons.lan_rounded, size: 16, color: AppColors.primaryCyan),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.get('active_connections', language),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${_connections.length}',
                    style: const TextStyle(fontSize: 12, color: AppColors.primaryCyan, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: _loadingConnections
                    ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    : _connections.isEmpty
                        ? Center(
                            child: Text(
                              AppStrings.get('no_active_connections', language),
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _connections.length,
                            separatorBuilder: (_, __) => const Divider(height: 10),
                            itemBuilder: (_, idx) {
                              final c = _connections[idx];
                              final remote = c.remoteAddress.isNotEmpty
                                  ? '${c.remoteAddress}:${c.remotePort}'
                                  : '*:${c.localPort}';
                              return Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryCyan.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      c.protocol,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryCyan),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      remote,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Text(
                                    c.state,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: c.state == 'ESTABLISHED'
                                          ? AppColors.statusActive
                                          : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
              ),
              const SizedBox(height: 20),

              // Close Action
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryCyan,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(AppStrings.get('close', language)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool selectable = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: selectable
              ? SelectableText(
                  value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                )
              : Text(
                  value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
        ),
      ],
    );
  }
}
