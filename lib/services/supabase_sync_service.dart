// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_service.dart';

class SupabaseSyncService {
  static const _kSupabaseUrl = 'pocket_supabase_url';
  static const _kSupabaseAnonKey = 'pocket_supabase_anon_key';
  static const _kLastSyncTime = 'pocket_supabase_last_sync';
  static const _kUserEmail = 'pocket_user_email';
  static const _kUserName = 'pocket_user_name';

  static final SupabaseSyncService _instance = SupabaseSyncService._internal();
  factory SupabaseSyncService() => _instance;
  SupabaseSyncService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  User? get currentUser {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isSignedIn => currentUser != null;

  Future<bool> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString(_kSupabaseUrl);
      final anonKey = prefs.getString(_kSupabaseAnonKey);

      if (url != null && url.isNotEmpty && anonKey != null && anonKey.isNotEmpty) {
        await Supabase.initialize(
          url: url.trim(),
          anonKey: anonKey.trim(),
        );
        _isInitialized = true;
        return true;
      }
    } catch (_) {
      _isInitialized = false;
    }
    return false;
  }

  Future<bool> connect({required String url, required String anonKey}) async {
    try {
      final cleanUrl = url.trim();
      final cleanKey = anonKey.trim();

      if (cleanUrl.isEmpty || cleanKey.isEmpty) {
        return false;
      }

      await Supabase.initialize(
        url: cleanUrl,
        anonKey: cleanKey,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSupabaseUrl, cleanUrl);
      await prefs.setString(_kSupabaseAnonKey, cleanKey);
      _isInitialized = true;
      return true;
    } catch (_) {
      _isInitialized = false;
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    if (!_isInitialized) return false;
    try {
      final response = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'pocket://auth-callback',
      );
      return response;
    } catch (e) {
      debugPrint('Google OAuth error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    if (_isInitialized) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserEmail);
    await prefs.remove(_kUserName);
  }

  Future<void> disconnect() async {
    await signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSupabaseUrl);
    await prefs.remove(_kSupabaseAnonKey);
    await prefs.remove(_kLastSyncTime);
    _isInitialized = false;
  }

  Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastSyncTime);
  }

  Future<String?> getSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSupabaseUrl);
  }

  String _getBackupId() {
    final user = currentUser;
    if (user != null && user.id.isNotEmpty) {
      return 'user_${user.id}';
    }
    return 'pocket_latest_backup';
  }

  /// 1-Tap Cloud Backup: Uploads all local database tables into Supabase
  Future<bool> backupToCloud(StorageService storage) async {
    if (!_isInitialized) return false;

    try {
      final client = Supabase.instance.client;
      final payload = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'transactions': storage.getTransactions().map((e) => e.toJson()).toList(),
        'wallets': storage.getWallets().map((e) => e.toJson()).toList(),
        'categories': storage.getCategories().map((e) => e.toJson()).toList(),
        'debts': storage.getDebts().map((e) => e.toJson()).toList(),
        'budgets': storage.getCategoryBudgets().map((e) => e.toJson()).toList(),
      };

      final backupId = _getBackupId();

      // Upsert into pocket_backups table with auto-bootstrapping
      await client.from('pocket_backups').upsert({
        'id': backupId,
        'user_id': currentUser?.id,
        'backup_data': payload,
        'updated_at': DateTime.now().toIso8601String(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastSyncTime, DateTime.now().toIso8601String());
      return true;
    } catch (e) {
      debugPrint('Cloud backup error: $e');
      return false;
    }
  }

  /// 1-Tap Cloud Restore: Fetches latest backup from Supabase and restores locally
  Future<bool> restoreFromCloud(StorageService storage) async {
    if (!_isInitialized) return false;

    try {
      final client = Supabase.instance.client;
      final backupId = _getBackupId();

      final response = await client
          .from('pocket_backups')
          .select('backup_data')
          .eq('id', backupId)
          .maybeSingle();

      if (response == null || response['backup_data'] == null) {
        // Fallback check for global latest backup
        final fallback = await client
            .from('pocket_backups')
            .select('backup_data')
            .eq('id', 'pocket_latest_backup')
            .maybeSingle();

        if (fallback == null || fallback['backup_data'] == null) {
          return false;
        }

        final Map<String, dynamic> data = fallback['backup_data'] is String
            ? jsonDecode(fallback['backup_data'])
            : fallback['backup_data'];

        await storage.restoreDatabase(data);
        return true;
      }

      final Map<String, dynamic> data = response['backup_data'] is String
          ? jsonDecode(response['backup_data'])
          : response['backup_data'];

      // Restore data safely
      await storage.restoreDatabase(data);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastSyncTime, DateTime.now().toIso8601String());
      return true;
    } catch (e) {
      debugPrint('Cloud restore error: $e');
      return false;
    }
  }
}
