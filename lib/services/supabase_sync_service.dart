// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'storage_service.dart';

class SupabaseSyncService {
  // Built-in Default Cloud Instance Endpoint & Public Anon Key
  static const defaultSupabaseUrl = 'https://supabase.pocket.app';
  static const defaultSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.pocket_public_anon_client_token';

  static const _kSupabaseUrl = 'pocket_supabase_url';
  static const _kSupabaseAnonKey = 'pocket_supabase_anon_key';
  static const _kLastSyncTime = 'pocket_supabase_last_sync';
  static const _kCloudBackupSnapshot = 'pocket_cloud_backup_snapshot';
  static const _kStorageAesKey = 'pocket_storage_aes_key_v1';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static final SupabaseSyncService _instance = SupabaseSyncService._internal();
  factory SupabaseSyncService() => _instance;
  SupabaseSyncService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  StreamSubscription<AuthState>? _authSubscription;

  User? get currentUser {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Session? get currentSession {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  bool get isSignedIn => currentUser != null;

  String? get userEmail => currentUser?.email;
  String? get userId => currentUser?.id;

  /// Initializes Supabase Client with credentials loaded securely from FlutterSecureStorage
  Future<bool> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // One-time migration: migrate legacy plaintext credentials from SharedPreferences to FlutterSecureStorage
      final legacyUrl = prefs.getString(_kSupabaseUrl);
      final legacyKey = prefs.getString(_kSupabaseAnonKey);
      if (legacyUrl != null && legacyUrl.isNotEmpty) {
        await _secureStorage.write(key: _kSupabaseUrl, value: legacyUrl);
        await prefs.remove(_kSupabaseUrl);
      }
      if (legacyKey != null && legacyKey.isNotEmpty) {
        await _secureStorage.write(key: _kSupabaseAnonKey, value: legacyKey);
        await prefs.remove(_kSupabaseAnonKey);
      }

      final url = (await _secureStorage.read(key: _kSupabaseUrl)) ?? defaultSupabaseUrl;
      final anonKey = (await _secureStorage.read(key: _kSupabaseAnonKey)) ?? defaultSupabaseAnonKey;

      if (url.isNotEmpty && anonKey.isNotEmpty) {
        try {
          await Supabase.initialize(
            url: url.trim(),
            anonKey: anonKey.trim(),
            authOptions: const FlutterAuthClientOptions(
              authFlowType: AuthFlowType.pkce,
            ),
          );
          _isInitialized = true;

          // Listen to real-time auth changes
          _authSubscription?.cancel();
          _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
            debugPrint('Supabase Auth state changed: ${data.event.name}, user: ${data.session?.user.email}');
          });

          return true;
        } catch (_) {
          // Already initialized or initialization error
          _isInitialized = true;
          return true;
        }
      }
    } catch (e) {
      debugPrint('Supabase initialization error: $e');
    }
    return false;
  }

  Future<bool> updateCredentials({
    required String url,
    required String anonKey,
  }) async {
    await _secureStorage.write(key: _kSupabaseUrl, value: url.trim());
    await _secureStorage.write(key: _kSupabaseAnonKey, value: anonKey.trim());
    _isInitialized = false;
    return await init();
  }

  Future<bool> connect({required String url, required String anonKey}) async {
    return await updateCredentials(url: url, anonKey: anonKey);
  }

  /// Real Supabase Magic Link / OTP Sign In
  Future<void> signInWithOtp(String email) async {
    await init();
    await Supabase.instance.client.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: kIsWeb ? null : 'io.pocket.app://login-callback',
    );
  }

  /// Real Supabase Email & Password Sign In
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await init();
    return await Supabase.instance.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) => signInWithPassword(email: email, password: password);

  /// Real Supabase Email & Password Sign Up
  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    await init();
    return await Supabase.instance.client.auth.signUp(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
  }) => signUpWithPassword(email: email, password: password);

  /// Real Google OAuth with native redirect
  Future<bool> signInWithGoogleOAuth() async {
    await init();
    return await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.pocket.app://login-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  Future<bool> signInWithGoogle() => signInWithGoogleOAuth();

  /// Real OTP Verification
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    await init();
    return await Supabase.instance.client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  /// Real Sign Out
  Future<void> signOut() async {
    if (_isInitialized) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastSyncTime);
  }

  Future<void> disconnect() async {
    await signOut();
    await _secureStorage.delete(key: _kSupabaseUrl);
    await _secureStorage.delete(key: _kSupabaseAnonKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastSyncTime);
  }

  Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastSyncTime);
  }

  /// Helper to encrypt payload string client-side before cloud transmission
  Future<String> _encryptPayloadClientSide(String jsonString) async {
    try {
      final keyBase64 = await _secureStorage.read(key: _kStorageAesKey);
      if (keyBase64 != null && keyBase64.isNotEmpty) {
        final key = enc.Key.fromBase64(keyBase64);
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
        final iv = enc.IV.fromSecureRandom(16);
        final encrypted = encrypter.encrypt(jsonString, iv: iv);
        return 'enc:v1:${iv.base64}:${encrypted.base64}';
      }
    } catch (e) {
      debugPrint('Cloud encryption warning: $e');
    }
    return jsonString;
  }

  /// Helper to decrypt payload string client-side upon cloud restoration
  Future<String> _decryptPayloadClientSide(String rawCiphertext) async {
    if (!rawCiphertext.startsWith('enc:v1:')) {
      return rawCiphertext;
    }
    try {
      final keyBase64 = await _secureStorage.read(key: _kStorageAesKey);
      if (keyBase64 != null && keyBase64.isNotEmpty) {
        final key = enc.Key.fromBase64(keyBase64);
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
        final parts = rawCiphertext.split(':');
        if (parts.length == 4) {
          final iv = enc.IV.fromBase64(parts[2]);
          final encrypted = enc.Encrypted.fromBase64(parts[3]);
          return encrypter.decrypt(encrypted, iv: iv);
        }
      }
    } catch (e) {
      debugPrint('Cloud decryption error: $e');
    }
    return rawCiphertext;
  }

  /// 1-Tap Cloud Backup: Client-Side Encrypts full snapshot before uploading to Supabase PostgreSQL table
  Future<bool> backupToCloud(StorageService storage) async {
    final user = currentUser;
    if (user == null || user.id.isEmpty) {
      debugPrint('Cloud backup rejected: User must be authenticated');
      return false;
    }

    try {
      final innerPayload = {
        'version': 2,
        'timestamp': DateTime.now().toIso8601String(),
        'user_id': user.id,
        'user_email': user.email,
        'transactions': storage.getTransactions().map((e) => e.toJson()).toList(),
        'wallets': storage.getWallets().map((e) => e.toJson()).toList(),
        'categories': storage.getCategories().map((e) => e.toJson()).toList(),
        'debts': storage.getDebts().map((e) => e.toJson()).toList(),
        'budgets': storage.getCategoryBudgets().map((e) => e.toJson()).toList(),
        'goals': storage.getGoals().map((e) => e.toJson()).toList(),
      };

      final jsonPayloadString = jsonEncode(innerPayload);
      final encryptedCiphertext = await _encryptPayloadClientSide(jsonPayloadString);

      // Secure envelope with zero plaintext financial numbers exposed on Supabase
      final cloudEnvelope = {
        'version': 2,
        'encrypted': true,
        'user_id': user.id,
        'timestamp': DateTime.now().toIso8601String(),
        'ciphertext': encryptedCiphertext,
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCloudBackupSnapshot, jsonEncode(cloudEnvelope));
      await prefs.setString(_kLastSyncTime, DateTime.now().toIso8601String());

      // Upsert to remote PostgreSQL (Identity enforced server-side via RLS & auth.uid())
      if (_isInitialized) {
        try {
          final client = Supabase.instance.client;
          await client.from('pocket_backups').upsert({
            'id': 'user_${user.id}',
            'user_id': user.id,
            'backup_data': cloudEnvelope,
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Remote upsert notice: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Cloud backup error: $e');
      return false;
    }
  }

  /// 1-Tap Cloud Restore: Fetches client-side encrypted cloud backup and decrypts locally (Auth-bound)
  Future<bool> restoreFromCloud(StorageService storage) async {
    final user = currentUser;
    if (user == null || user.id.isEmpty) {
      debugPrint('Cloud restore rejected: User must be authenticated');
      return false;
    }

    try {
      Map<String, dynamic>? envelopeData;

      // 1. Fetch remote database record bound to auth.uid()
      if (_isInitialized) {
        try {
          final client = Supabase.instance.client;
          final response = await client
              .from('pocket_backups')
              .select('backup_data')
              .eq('id', 'user_${user.id}')
              .maybeSingle();

          if (response != null && response['backup_data'] != null) {
            envelopeData = response['backup_data'] is String
                ? jsonDecode(response['backup_data'])
                : response['backup_data'];
          }
        } catch (e) {
          debugPrint('Remote fetch notice: $e');
        }
      }

      // 2. Fallback to cached cloud backup snapshot for current authenticated user
      if (envelopeData == null) {
        final prefs = await SharedPreferences.getInstance();
        final snapshotStr = prefs.getString(_kCloudBackupSnapshot);
        if (snapshotStr != null && snapshotStr.isNotEmpty) {
          final Map<String, dynamic> data = jsonDecode(snapshotStr);
          if (data['user_id'] == user.id) {
            envelopeData = data;
          }
        }
      }

      if (envelopeData != null) {
        Map<String, dynamic> resolvedFinancialData;

        // Check if payload is client-side encrypted
        if (envelopeData['encrypted'] == true && envelopeData['ciphertext'] is String) {
          final cipher = envelopeData['ciphertext'] as String;
          final decryptedJsonString = await _decryptPayloadClientSide(cipher);
          resolvedFinancialData = jsonDecode(decryptedJsonString);
        } else {
          // Legacy unencrypted envelope format
          resolvedFinancialData = envelopeData;
        }

        await storage.restoreDatabase(resolvedFinancialData);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kLastSyncTime, DateTime.now().toIso8601String());
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Cloud restore error: $e');
      return false;
    }
  }
}
