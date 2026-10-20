import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/settings_model.dart';
import 'backup_service.dart';

class HfSyncResult {
  final bool success;
  final String message;
  final int? timestamp;
  final String? data;

  const HfSyncResult({
    required this.success,
    required this.message,
    this.timestamp,
    this.data,
  });
}

class HfSyncService {
  static final HfSyncService _instance = HfSyncService._internal();
  factory HfSyncService() => _instance;
  HfSyncService._internal();

  /// Normalize Space URL (strip trailing slashes, ensure https://)
  String _normalizeUrl(String url) {
    var trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Map<String, String> _buildHeaders(String? apiKey) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }
    return headers;
  }

  /// Test connection to the Hugging Face Space endpoint
  Future<HfSyncResult> testConnection(String spaceUrl, String? apiKey) async {
    try {
      final base = _normalizeUrl(spaceUrl);
      final uri = Uri.parse('$base/health');

      final response = await http
          .get(uri, headers: _buildHeaders(apiKey))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final serviceName = decoded['service'] ?? 'Pocket Hub';
        final lastSync = decoded['last_sync_timestamp'] as int?;
        return HfSyncResult(
          success: true,
          message: 'Connected to $serviceName successfully!',
          timestamp: lastSync,
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return const HfSyncResult(
          success: false,
          message: 'Authentication failed. Please verify your POCKET_API_KEY secret.',
        );
      } else {
        return HfSyncResult(
          success: false,
          message: 'Server returned HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      debugPrint('[HfSyncService] testConnection error: $e');
      return HfSyncResult(
        success: false,
        message: 'Could not connect to Space: ${e.toString()}',
      );
    }
  }

  /// Push encrypted vault backup snapshot to the Hugging Face Space
  Future<HfSyncResult> pushBackup({
    required String spaceUrl,
    String? apiKey,
    required String backupData,
  }) async {
    try {
      final base = _normalizeUrl(spaceUrl);
      final uri = Uri.parse('$base/sync/push');

      final body = jsonEncode({
        'data': backupData,
        'appVersion': '1.5.18',
        'deviceId': 'Pocket Android',
      });

      final response = await http
          .post(uri, headers: _buildHeaders(apiKey), body: body)
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return HfSyncResult(
          success: true,
          message: 'Vault encrypted backup safely synced to Hugging Face Space!',
          timestamp: decoded['timestamp'] as int?,
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return const HfSyncResult(
          success: false,
          message: 'Space authorization rejected. Check your Secret Key.',
        );
      } else {
        return HfSyncResult(
          success: false,
          message: 'Sync push failed with HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[HfSyncService] pushBackup error: $e');
      return HfSyncResult(
        success: false,
        message: 'Sync push failed: ${e.toString()}',
      );
    }
  }

  /// Pull encrypted backup from the Hugging Face Space
  Future<HfSyncResult> pullBackup({
    required String spaceUrl,
    String? apiKey,
  }) async {
    try {
      final base = _normalizeUrl(spaceUrl);
      final uri = Uri.parse('$base/sync/pull');

      final response = await http
          .get(uri, headers: _buildHeaders(apiKey))
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final rawData = decoded['data'] as String?;
        if (rawData == null || rawData.isEmpty) {
          return const HfSyncResult(
            success: false,
            message: 'Server returned empty backup payload.',
          );
        }
        return HfSyncResult(
          success: true,
          message: 'Remote backup retrieved successfully from Space.',
          timestamp: decoded['timestamp'] as int?,
          data: rawData,
        );
      } else if (response.statusCode == 404) {
        return const HfSyncResult(
          success: false,
          message: 'No backup found on this Space yet. Push a backup first.',
        );
      } else {
        return HfSyncResult(
          success: false,
          message: 'Sync pull failed: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[HfSyncService] pullBackup error: $e');
      return HfSyncResult(
        success: false,
        message: 'Sync pull error: ${e.toString()}',
      );
    }
  }

  /// Silently triggers auto-sync if configured in settings
  Future<void> autoSyncIfEnabled(UserSettingsModel settings, dynamic storage) async {
    if (!settings.hfAutoSyncEnabled) return;
    final url = settings.hfSpaceUrl;
    if (url == null || url.trim().isEmpty) return;

    try {
      final backupData = BackupService(storage).exportJsonBackupString();
      final result = await pushBackup(
        spaceUrl: url,
        apiKey: settings.hfApiKey,
        backupData: backupData,
      );
      if (result.success) {
        debugPrint('[HfSyncService] Background auto-sync to Hugging Face Space succeeded.');
      }
    } catch (e) {
      debugPrint('[HfSyncService] autoSync error (ignored in background): $e');
    }
  }
}
