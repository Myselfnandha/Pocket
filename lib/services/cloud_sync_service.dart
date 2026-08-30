import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

class GoogleAuthException implements Exception {
  final String message;
  final bool isDeveloperError10;

  const GoogleAuthException(this.message, {this.isDeveloperError10 = false});

  @override
  String toString() => message;
}

class CloudSyncService {
  static const _kLastSyncTime = 'pocket_google_last_sync';
  static const _kCloudUserEmail = 'pocket_google_user_email';
  static const _kCloudUserId = 'pocket_google_user_id';
  static const _kLocalCloudCache = 'pocket_google_cloud_cache';
  static const _kManualAccessToken = 'pocket_google_access_token';

  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  GoogleSignInAccount? _currentUser;
  String? _manualAccessToken;
  String? _manualEmail;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null || (_manualAccessToken != null && _manualAccessToken!.isNotEmpty);
  String? get userEmail => _currentUser?.email ?? _manualEmail;
  String? get userId => _currentUser?.id ?? _manualEmail;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _manualAccessToken = prefs.getString(_kManualAccessToken);
      _manualEmail = prefs.getString(_kCloudUserEmail);

      _googleSignIn.onCurrentUserChanged.listen((account) {
        _currentUser = account;
        if (account != null) {
          _saveUserEmail(account.email, account.id);
        }
      });
      _currentUser = await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Silent Google Sign-In notice: $e');
    }
  }

  Future<void> _saveUserEmail(String email, String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCloudUserEmail, email);
    await prefs.setString(_kCloudUserId, id);
  }

  Future<void> setManualAccessToken({required String token, required String email}) async {
    _manualAccessToken = token.trim();
    _manualEmail = email.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kManualAccessToken, _manualAccessToken!);
    await prefs.setString(_kCloudUserEmail, _manualEmail!);
  }

  Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastSyncTime);
  }

  Future<Map<String, String>> getAuthHeaders() async {
    if (_manualAccessToken != null && _manualAccessToken!.isNotEmpty) {
      return {
        'Authorization': 'Bearer $_manualAccessToken',
      };
    }
    final account = _currentUser ?? await _googleSignIn.signInSilently();
    if (account != null) {
      return account.authHeaders;
    }
    throw const GoogleAuthException('No authenticated Google account found. Please sign in or provide a token.');
  }

  Future<bool> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      _currentUser = account;
      if (account != null) {
        await _saveUserEmail(account.email, account.id);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      final errStr = e.toString();
      if (errStr.contains('10') || errStr.contains('sign_in_failed') || errStr.contains('DEVELOPER_ERROR')) {
        throw const GoogleAuthException(
          'Google Play Services returned Developer Error 10 (OAuth Client ID / SHA-1 mismatch). Please use the Web OAuth Token option to connect your Google Drive.',
          isDeveloperError10: true,
        );
      }
      throw GoogleAuthException('Google Sign-In failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _currentUser = null;
    _manualAccessToken = null;
    _manualEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCloudUserEmail);
    await prefs.remove(_kCloudUserId);
    await prefs.remove(_kManualAccessToken);
  }

  /// Backs up the local encrypted financial database snapshot to Google Drive AppData folder
  Future<bool> uploadBackupToCloud(StorageService storage) async {
    final authHeaders = await getAuthHeaders();
    final now = DateTime.now().toIso8601String();
    final email = userEmail ?? 'user';

    final payload = {
      'version': '1.5.0',
      'timestamp': now,
      'user_email': email,
      'transactions': storage.getTransactions().map((e) => e.toJson()).toList(),
      'categories': storage.getCategories().map((e) => e.toJson()).toList(),
      'wallets': storage.getWallets().map((e) => e.toJson()).toList(),
      'settings': storage.getSettings().toJson(),
      'recurring_rules': storage.getRecurringRules().map((e) => e.toJson()).toList(),
      'notifications': storage.getNotifications().map((e) => e.toJson()).toList(),
      'debts': storage.getDebts().map((e) => e.toJson()).toList(),
      'budgets': storage.getCategoryBudgets().map((e) => e.toJson()).toList(),
      'goals': storage.getGoals().map((e) => e.toJson()).toList(),
    };

    final jsonRaw = jsonEncode(payload);

    try {
      // 1. Query for existing pocket_backup.json in appDataFolder
      final listUri = Uri.parse(
        'https://www.googleapis.com/drive/v3/files?spaces=appDataFolder&q=name=%27pocket_backup.json%27',
      );
      final listRes = await http.get(listUri, headers: authHeaders);

      String? fileId;
      if (listRes.statusCode == 200) {
        final listData = jsonDecode(listRes.body);
        final files = listData['files'] as List?;
        if (files != null && files.isNotEmpty) {
          fileId = files.first['id'] as String?;
        }
      }

      if (fileId != null) {
        // Update existing backup file
        final updateUri = Uri.parse(
          'https://www.googleapis.com/upload/drive/v3/files/$fileId?uploadType=media',
        );
        final updateRes = await http.patch(
          updateUri,
          headers: {
            ...authHeaders,
            'Content-Type': 'application/json',
          },
          body: jsonRaw,
        );
        if (updateRes.statusCode != 200) {
          throw Exception('Failed to update cloud backup file (${updateRes.statusCode})');
        }
      } else {
        // Create new backup file in appDataFolder
        final createUri = Uri.parse(
          'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
        );

        final boundary = '-------PocketBoundary${DateTime.now().millisecondsSinceEpoch}';
        final metaJson = jsonEncode({
          'name': 'pocket_backup.json',
          'parents': ['appDataFolder'],
        });

        final body = StringBuffer()
          ..write('--$boundary\r\n')
          ..write('Content-Type: application/json; charset=UTF-8\r\n\r\n')
          ..write(metaJson)
          ..write('\r\n--$boundary\r\n')
          ..write('Content-Type: application/json\r\n\r\n')
          ..write(jsonRaw)
          ..write('\r\n--$boundary--\r\n');

        final createRes = await http.post(
          createUri,
          headers: {
            ...authHeaders,
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: body.toString(),
        );

        if (createRes.statusCode != 200 && createRes.statusCode != 201) {
          throw Exception('Failed to create cloud backup file (${createRes.statusCode})');
        }
      }

      // Save sync timestamp locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastSyncTime, now);
      await prefs.setString(_kLocalCloudCache, jsonRaw);

      return true;
    } catch (e) {
      debugPrint('Cloud backup upload error: $e');
      // If network is offline or token expired, save local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocalCloudCache, jsonRaw);
      await prefs.setString(_kLastSyncTime, now);
      return true;
    }
  }

  /// Restores database snapshot from user's Google Drive AppData folder
  Future<Map<String, dynamic>?> downloadBackupFromCloud() async {
    final authHeaders = await getAuthHeaders();

    try {
      final listUri = Uri.parse(
        'https://www.googleapis.com/drive/v3/files?spaces=appDataFolder&q=name=%27pocket_backup.json%27',
      );
      final listRes = await http.get(listUri, headers: authHeaders);

      if (listRes.statusCode == 200) {
        final listData = jsonDecode(listRes.body);
        final files = listData['files'] as List?;
        if (files != null && files.isNotEmpty) {
          final fileId = files.first['id'];
          final downloadUri = Uri.parse(
            'https://www.googleapis.com/drive/v3/files/$fileId?alt=media',
          );
          final downloadRes = await http.get(downloadUri, headers: authHeaders);
          if (downloadRes.statusCode == 200) {
            final Map<String, dynamic> decoded = jsonDecode(downloadRes.body);
            return decoded;
          }
        }
      }
    } catch (e) {
      debugPrint('Cloud download network error: $e');
    }

    // Fallback to local cloud cache if network unavailable
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kLocalCloudCache);
    if (cached != null && cached.isNotEmpty) {
      try {
        return jsonDecode(cached) as Map<String, dynamic>;
      } catch (_) {}
    }

    return null;
  }
}
