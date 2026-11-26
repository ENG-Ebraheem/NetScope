class ApplicationUsage {
  final String appId;
  final String executablePath;
  final String processName;
  final String displayName;
  final String category;
  final String? iconPath;
  final num rx;
  final num tx;
  final num total;
  final num rxSpeed;
  final num txSpeed;
  final bool isActive;
  final String? firstSeen;
  final String? lastSeen;

  ApplicationUsage({
    required this.appId,
    required this.executablePath,
    required this.processName,
    required this.displayName,
    required this.category,
    this.iconPath,
    required this.rx,
    required this.tx,
    required this.total,
    this.rxSpeed = 0.0,
    this.txSpeed = 0.0,
    this.isActive = false,
    this.firstSeen,
    this.lastSeen,
  });

  factory ApplicationUsage.fromJson(Map<String, dynamic> json) {
    return ApplicationUsage(
      appId: json['app_id'] ?? '',
      executablePath: json['executable_path'] ?? '',
      processName: json['process_name'] ?? 'Unknown',
      displayName: json['display_name'] ?? 'Unknown Application',
      category: json['category'] ?? 'app',
      iconPath: json['icon_path'],
      rx: json['rx'] ?? 0,
      tx: json['tx'] ?? 0,
      total: json['total'] ?? 0,
      rxSpeed: json['rx_speed'] ?? 0.0,
      txSpeed: json['tx_speed'] ?? 0.0,
      isActive: json['is_active'] ?? false,
      firstSeen: json['first_seen'],
      lastSeen: json['last_seen'],
    );
  }
}

class ActiveConnection {
  final String appId;
  final String localAddress;
  final int localPort;
  final String remoteAddress;
  final int remotePort;
  final String protocol;
  final String state;

  ActiveConnection({
    required this.appId,
    required this.localAddress,
    required this.localPort,
    required this.remoteAddress,
    required this.remotePort,
    required this.protocol,
    required this.state,
  });

  factory ActiveConnection.fromJson(Map<String, dynamic> json) {
    return ActiveConnection(
      appId: json['app_id'] ?? '',
      localAddress: json['local_address'] ?? '',
      localPort: json['local_port'] ?? 0,
      remoteAddress: json['remote_address'] ?? '',
      remotePort: json['remote_port'] ?? 0,
      protocol: json['protocol'] ?? 'TCP',
      state: json['state'] ?? '-',
    );
  }
}

class AppAlert {
  final String id;
  final String type;
  final String title;
  final String message;
  final String timestamp;

  AppAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
  });

  factory AppAlert.fromJson(Map<String, dynamic> json) {
    return AppAlert(
      id: json['id'] ?? '',
      type: json['type'] ?? 'info',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class DashboardData {
  final num todayRx;
  final num todayTx;
  final num todayTotal;
  final num monthRx;
  final num monthTx;
  final num monthTotal;
  final List<ApplicationUsage> topApps;
  final List<ChartPoint> hourlyTrend;
  final LiveTelemetry live;

  DashboardData({
    required this.todayRx,
    required this.todayTx,
    required this.todayTotal,
    required this.monthRx,
    required this.monthTx,
    required this.monthTotal,
    required this.topApps,
    required this.hourlyTrend,
    required this.live,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    var rawTop = json['top_apps'] as List? ?? [];
    var rawHourly = json['hourly_trend'] as List? ?? [];

    return DashboardData(
      todayRx: json['today_rx'] ?? 0,
      todayTx: json['today_tx'] ?? 0,
      todayTotal: json['today_total'] ?? 0,
      monthRx: json['month_rx'] ?? 0,
      monthTx: json['month_tx'] ?? 0,
      monthTotal: json['month_total'] ?? 0,
      topApps: rawTop.map((e) => ApplicationUsage.fromJson(e)).toList(),
      hourlyTrend: rawHourly.map((e) => ChartPoint.fromJson(e)).toList(),
      live: LiveTelemetry.fromJson(json['live'] ?? {}),
    );
  }
}

class ChartPoint {
  final String label;
  final num rx;
  final num tx;
  final num total;

  ChartPoint({
    required this.label,
    required this.rx,
    required this.tx,
  }) : total = rx + tx;

  factory ChartPoint.fromJson(Map<String, dynamic> json) {
    return ChartPoint(
      label: json['label'] ?? '',
      rx: json['rx'] ?? 0,
      tx: json['tx'] ?? 0,
    );
  }
}

class LiveTelemetry {
  final bool monitoringActive;
  final bool paused;
  final String profileName;
  final num downloadSpeed;
  final num uploadSpeed;
  final num peakDownloadSpeed;
  final num peakUploadSpeed;
  final int linkSpeedMbps;
  final String downloadSpeedFormatted;
  final String uploadSpeedFormatted;
  final int activeAppsCount;
  final int totalAppsMonitored;
  final int alertsCount;
  final AppAlert? latestAlert;

  LiveTelemetry({
    required this.monitoringActive,
    required this.paused,
    required this.profileName,
    required this.downloadSpeed,
    required this.uploadSpeed,
    this.peakDownloadSpeed = 0.0,
    this.peakUploadSpeed = 0.0,
    this.linkSpeedMbps = 0,
    required this.downloadSpeedFormatted,
    required this.uploadSpeedFormatted,
    required this.activeAppsCount,
    required this.totalAppsMonitored,
    this.alertsCount = 0,
    this.latestAlert,
  });

  factory LiveTelemetry.fromJson(Map<String, dynamic> json) {
    return LiveTelemetry(
      monitoringActive: json['monitoring_active'] ?? true,
      paused: json['paused'] ?? false,
      profileName: json['profile_name'] ?? 'Local Network',
      downloadSpeed: json['download_speed'] ?? 0.0,
      uploadSpeed: json['upload_speed'] ?? 0.0,
      peakDownloadSpeed: json['peak_download_speed'] ?? 0.0,
      peakUploadSpeed: json['peak_upload_speed'] ?? 0.0,
      linkSpeedMbps: (json['link_speed_mbps'] as num?)?.toInt() ?? 0,
      downloadSpeedFormatted: json['download_speed_formatted'] ?? '0 B/s',
      uploadSpeedFormatted: json['upload_speed_formatted'] ?? '0 B/s',
      activeAppsCount: json['active_apps_count'] ?? 0,
      totalAppsMonitored: json['total_apps_monitored'] ?? 0,
      alertsCount: json['alerts_count'] ?? 0,
      latestAlert: json['latest_alert'] != null ? AppAlert.fromJson(json['latest_alert']) : null,
    );
  }
}

class HistoryData {
  final String period;
  final num totalRx;
  final num totalTx;
  final num total;
  final List<ChartPoint> chartData;
  final List<ApplicationUsage> applications;

  HistoryData({
    required this.period,
    required this.totalRx,
    required this.totalTx,
    required this.total,
    required this.chartData,
    required this.applications,
  });

  factory HistoryData.fromJson(Map<String, dynamic> json) {
    var rawChart = json['chart_data'] as List? ?? [];
    var rawApps = json['applications'] as List? ?? [];

    return HistoryData(
      period: json['period'] ?? '7days',
      totalRx: json['total_rx'] ?? 0,
      totalTx: json['total_tx'] ?? 0,
      total: json['total'] ?? 0,
      chartData: rawChart.map((e) => ChartPoint.fromJson(e)).toList(),
      applications: rawApps.map((e) => ApplicationUsage.fromJson(e)).toList(),
    );
  }
}

class StorageStats {
  final String filePath;
  final num sizeBytes;
  final double sizeMb;
  final int applicationsCount;
  final int trafficRecordsCount;
  final int hourlyRecordsCount;
  final int dailyRecordsCount;

  StorageStats({
    required this.filePath,
    required this.sizeBytes,
    required this.sizeMb,
    required this.applicationsCount,
    required this.trafficRecordsCount,
    required this.hourlyRecordsCount,
    required this.dailyRecordsCount,
  });

  factory StorageStats.fromJson(Map<String, dynamic> json) {
    return StorageStats(
      filePath: json['file_path'] ?? '',
      sizeBytes: json['size_bytes'] ?? 0,
      sizeMb: (json['size_mb'] as num?)?.toDouble() ?? 0.0,
      applicationsCount: json['applications_count'] ?? 0,
      trafficRecordsCount: json['traffic_records_count'] ?? 0,
      hourlyRecordsCount: json['hourly_records_count'] ?? 0,
      dailyRecordsCount: json['daily_records_count'] ?? 0,
    );
  }
}

String formatBytes(num bytes, {String lang = 'en'}) {
  final isAr = lang == 'ar';
  final unitB = isAr ? 'بايت' : 'B';
  final unitKb = isAr ? 'ك.بايت' : 'KB';
  final unitMb = isAr ? 'م.بايت' : 'MB';
  final unitGb = isAr ? 'ج.بايت' : 'GB';

  if (bytes < 1024) {
    return '${bytes.toStringAsFixed(0)} $unitB';
  } else if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} $unitKb';
  } else if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} $unitMb';
  } else {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} $unitGb';
  }
}

String formatSpeedMbps(num bytesPerSec, {String lang = 'en'}) {
  if (bytesPerSec <= 0) return '0.00 Mbps';
  final bitsPerSec = bytesPerSec * 8;
  if (bitsPerSec >= 1000 * 1000) {
    return '${(bitsPerSec / (1000 * 1000)).toStringAsFixed(2)} Mbps';
  } else if (bitsPerSec >= 1000) {
    return '${(bitsPerSec / 1000).toStringAsFixed(1)} Kbps';
  } else {
    return '${bitsPerSec.toStringAsFixed(0)} bps';
  }
}
