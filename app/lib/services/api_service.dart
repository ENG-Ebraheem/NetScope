import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:58220';
  static const String wsUrl = 'ws://127.0.0.1:58220/ws/live';

  WebSocketChannel? _wsChannel;
  Timer? _reconnectTimer;
  final StreamController<LiveTelemetry> _liveTelemetryController = StreamController<LiveTelemetry>.broadcast();
  Stream<LiveTelemetry> get liveStream => _liveTelemetryController.stream;

  bool _isWsConnecting = false;
  bool _isDisposed = false;

  void initWebSocket() {
    if (_isWsConnecting || _isDisposed) return;
    _isWsConnecting = true;

    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsChannel!.stream.listen((message) {
        try {
          final data = jsonDecode(message);
          final telemetry = LiveTelemetry.fromJson(data);
          _liveTelemetryController.add(telemetry);
        } catch (_) {}
      }, onError: (err) {
        _reconnectWebSocket();
      }, onDone: () {
        _reconnectWebSocket();
      });
    } catch (_) {
      _reconnectWebSocket();
    }
  }

  void _reconnectWebSocket() {
    if (_isDisposed) return;
    _isWsConnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_isDisposed) initWebSocket();
    });
  }

  Future<DashboardData?> getDashboard() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/dashboard')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return DashboardData.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (_) {}
    return null;
  }

  Future<List<ApplicationUsage>> getApplications({
    String period = 'today',
    String search = '',
    String sort = 'total',
    String category = 'all',
    String? start,
    String? end,
  }) async {
    try {
      final params = <String, String>{
        'period': period,
        'search': search,
        'sort': sort,
        'category': category,
      };
      if (start != null) params['start'] = start;
      if (end != null) params['end'] = end;

      final uri = Uri.parse('$baseUrl/api/applications').replace(queryParameters: params);
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
        return list.map((e) => ApplicationUsage.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<HistoryData?> getHistory({String period = '7days', String? start, String? end}) async {
    try {
      final queryParams = <String, String>{'period': period};
      if (start != null) queryParams['start'] = start;
      if (end != null) queryParams['end'] = end;

      final uri = Uri.parse('$baseUrl/api/history').replace(queryParameters: queryParams);
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return HistoryData.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (_) {}
    return null;
  }

  Future<List<ActiveConnection>> getActiveConnections({String? appId}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/connections').replace(
        queryParameters: appId != null ? {'app_id': appId} : null,
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
        return list.map((e) => ActiveConnection.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<AppAlert>> getAlerts() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/alerts')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
        return list.map((e) => AppAlert.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  String getExportUrl({
    String format = 'csv',
    String period = 'today',
    String? start,
    String? end,
    String category = 'all',
  }) {
    final params = <String, String>{
      'format': format,
      'period': period,
      'category': category,
    };
    if (start != null) params['start'] = start;
    if (end != null) params['end'] = end;
    return Uri.parse('$baseUrl/api/export').replace(queryParameters: params).toString();
  }

  Future<Map<String, String>> getSettings() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/settings')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return map.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
    return {};
  }

  Future<bool> setSetting(String key, String value) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'key': key, 'value': value}),
      ).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleMonitoring() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/monitor/toggle')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['monitoring_active'] ?? true;
      }
    } catch (_) {}
    return true;
  }

  Future<bool> clearHistory() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/database/clear')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<StorageStats?> getStorageStats() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/storage')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        return StorageStats.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (_) {}
    return null;
  }

  String? getIconUrl(String? iconPath) {
    if (iconPath == null || iconPath.isEmpty) return null;
    final fileName = iconPath.split(RegExp(r'[\\/]')).last;
    return '$baseUrl/icons/$fileName';
  }

  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _wsChannel?.sink.close();
    _liveTelemetryController.close();
  }
}
