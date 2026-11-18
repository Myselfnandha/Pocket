import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket/services/storage_service.dart';
import 'package:pocket/models/transaction_model.dart';
import 'package:pocket/models/category_model.dart';
import 'package:encrypt/encrypt.dart' as enc;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pocket Security & Cryptographic Integrity Audit Suite', () {
    late SharedPreferences prefs;
    late FlutterSecureStorage secureStorage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      FlutterSecureStorage.setMockInitialValues({});
      secureStorage = const FlutterSecureStorage();
    });

    test('Cryptographic Key Generation: master key is 256-bit AES key in secure enclave', () async {
      final storage = await StorageService.init(prefs: prefs, secureStorage: secureStorage);
      expect(storage, isNotNull);

      final keyBase64 = await secureStorage.read(key: 'pocket_storage_aes_key_v1');
      expect(keyBase64, isNotNull);
      final keyBytes = base64.decode(keyBase64!);
      expect(keyBytes.length, 32, reason: 'Master key must be exactly 256 bits (32 bytes)');
    });

    test('Ciphertext Format: uses authenticated enc:v2 format with IV, ciphertext, and HMAC', () async {
      final storage = await StorageService.init(prefs: prefs, secureStorage: secureStorage);
      const plaintext = 'Secret Financial Record: ₹50,000 to HDFC Bank';
      final ciphertext = storage.encryptForTest(plaintext);

      expect(ciphertext.startsWith('enc:v2:'), isTrue);
      final parts = ciphertext.split(':');
      expect(parts.length, 5, reason: 'Format must be enc:v2:<iv>:<ciphertext>:<mac>');

      final ivBytes = base64.decode(parts[2]);
      expect(ivBytes.length, 16, reason: 'AES IV must be 128-bit (16 bytes)');

      final macBytes = base64.decode(parts[4]);
      expect(macBytes.length, 32, reason: 'HMAC-SHA256 signature must be 256-bit (32 bytes)');

      final decrypted = storage.decryptForTest(ciphertext);
      expect(decrypted, equals(plaintext));
    });

    test('IV Uniqueness: successive encryptions of identical plaintext produce distinct IVs and ciphertexts', () async {
      final storage = await StorageService.init(prefs: prefs, secureStorage: secureStorage);
      const plaintext = 'Identical Payload';

      final cipher1 = storage.encryptForTest(plaintext);
      final cipher2 = storage.encryptForTest(plaintext);

      expect(cipher1, isNot(equals(cipher2)));
      final iv1 = cipher1.split(':')[2];
      final iv2 = cipher2.split(':')[2];
      expect(iv1, isNot(equals(iv2)), reason: 'Cryptographic IVs must never repeat (CPA security)');
    });

    test('Tamper Detection: modified ciphertext block triggers MAC check failure and is rejected', () async {
      final storage = await StorageService.init(prefs: prefs, secureStorage: secureStorage);
      const plaintext = 'Sensitive Ledger Entry: Salary ₹1,50,000';
      final ciphertext = storage.encryptForTest(plaintext);

      final parts = ciphertext.split(':');
      final rawCipherBytes = base64.decode(parts[3]);
      // Bit-flip the first byte of ciphertext
      rawCipherBytes[0] ^= 0x01;
      final tamperedCipher = 'enc:v2:${parts[2]}:${base64.encode(rawCipherBytes)}:${parts[4]}';

      final result = storage.decryptForTest(tamperedCipher);
      expect(result, isNull, reason: 'Tampered ciphertext must fail HMAC verification before decryption');
    });

    test('Tamper Detection: modified IV triggers MAC check failure and is rejected', () async {
      final storage = await StorageService.init(prefs: prefs, secureStorage: secureStorage);
      const plaintext = 'Sensitive Ledger Entry: Salary ₹1,50,000';
      final ciphertext = storage.encryptForTest(plaintext);

      final parts = ciphertext.split(':');
      final rawIvBytes = base64.decode(parts[2]);
      // Bit-flip the first byte of IV
      rawIvBytes[0] ^= 0xFF;
      final tamperedIv = 'enc:v2:${base64.encode(rawIvBytes)}:${parts[3]}:${parts[4]}';

      final result = storage.decryptForTest(tamperedIv);
      expect(result, isNull, reason: 'Tampered IV must fail HMAC verification');
    });

    test('Tamper Detection: forged MAC signature is rejected', () async {
      final storage = await StorageService.init(prefs: prefs, secureStorage: secureStorage);
      const plaintext = 'Sensitive Ledger Entry: Salary ₹1,50,000';
      final ciphertext = storage.encryptForTest(plaintext);

      final parts = ciphertext.split(':');
      final forgedMac = base64.encode(List<int>.filled(32, 0x42));
      final forgedPayload = 'enc:v2:${parts[2]}:${parts[3]}:$forgedMac';

      final result = storage.decryptForTest(forgedPayload);
      expect(result, isNull, reason: 'Forged MAC must fail verification in constant-time check');
    });

    test('Tamper Detection: truncated or malformed payloads are safely rejected without crash', () async {
      final storage = await StorageService.init(prefs: prefs, secureStorage: secureStorage);
      expect(storage.decryptForTest('enc:v2:truncated'), isNull);
      expect(storage.decryptForTest('enc:v2:bad:iv:format:mac'), isNull);
      expect(storage.decryptForTest('enc:v2:::'), isNull);
    });

    test('Fallback & Downgrade Protection: malformed enc: prefixes never fall back to plaintext', () async {
      final storage = await StorageService.init(prefs: prefs, secureStorage: secureStorage);
      expect(storage.decryptForTest('enc:v3:fake_payload'), isNull);
      expect(storage.decryptForTest('enc:corrupted_blob'), isNull);
      expect(storage.decryptForTest('enc:'), isNull);
      expect(storage.decryptForTest('enc:v1:malformed'), isNull);
    });

    test('Downgrade Attack Resistance: tampering v2 payload into v1 format fails decryption safely', () async {
      final storage = await StorageService.init(prefs: prefs, secureStorage: secureStorage);
      const plaintext = 'Critical Account Number: 1234-5678-9012';
      final v2Ciphertext = storage.encryptForTest(plaintext);

      final parts = v2Ciphertext.split(':');
      expect(parts.length, 5);

      // Attacker attempts downgrade attack by forging a v1 record from v2 ciphertext
      final downgradedV1Payload = 'enc:v1:${parts[2]}:${parts[3]}';
      final decrypted = storage.decryptForTest(downgradedV1Payload);

      // Decryption must fail because K_enc != MasterKey
      expect(decrypted, isNull, reason: 'Subkey separation must prevent ciphertext downgrade attacks');
    });

    test('Cryptographic Edge Cases: extra components, missing tags, and invalid Base64 are rejected', () async {
      final storage = await StorageService.init(prefs: prefs, secureStorage: secureStorage);
      final valid = storage.encryptForTest('Valid Plaintext');
      final parts = valid.split(':');

      // 1. Missing authentication tag (length = 4)
      final missingTag = 'enc:v2:${parts[2]}:${parts[3]}';
      expect(storage.decryptForTest(missingTag), isNull);

      // 2. Extra components (length = 6)
      final extraComponent = '$valid:malicious_extra_field';
      expect(storage.decryptForTest(extraComponent), isNull);

      // 3. Invalid Base64 in components
      final invalidBase64 = 'enc:v2:???not_b64???:???not_b64???:???not_b64???';
      expect(storage.decryptForTest(invalidBase64), isNull);
    });

    test('Key Isolation: data encrypted under Key A cannot be decrypted by Key B', () async {
      final storageA = await StorageService.init(prefs: prefs, secureStorage: secureStorage);
      final ciphertextA = storageA.encryptForTest('Confidential Data');

      // Reset secureStorage with a fresh random key
      final newKey = enc.Key.fromSecureRandom(32);
      await secureStorage.write(key: 'pocket_storage_aes_key_v1', value: newKey.base64);

      final storageB = await StorageService.init(prefs: prefs, secureStorage: secureStorage);
      final decryptedWithKeyB = storageB.decryptForTest(ciphertextA);

      expect(decryptedWithKeyB, isNull, reason: 'Decryption with different key must fail HMAC authentication');
    });

    test('Backward Compatibility: reads legacy enc:v1 format seamlessly', () async {
      // 1. Generate master key and legacy enc:v1 ciphertext
      final masterKey = enc.Key.fromSecureRandom(32);
      await secureStorage.write(key: 'pocket_storage_aes_key_v1', value: masterKey.base64);

      final legacyEncrypter = enc.Encrypter(enc.AES(masterKey, mode: enc.AESMode.cbc));
      final legacyIv = enc.IV.fromSecureRandom(16);
      const originalText = 'Legacy unauthenticated financial record from Pocket v1.4';
      final legacyEncrypted = legacyEncrypter.encrypt(originalText, iv: legacyIv);
      final legacyCiphertext = 'enc:v1:${legacyIv.base64}:${legacyEncrypted.base64}';

      final storage = await StorageService.init(prefs: prefs, secureStorage: secureStorage);
      final decrypted = storage.decryptForTest(legacyCiphertext);

      expect(decrypted, equals(originalText));
    });

    test('Backward Compatibility: reads legacy unencrypted plaintext', () async {
      final storage = await StorageService.init(prefs: prefs, secureStorage: secureStorage);
      const plaintextJson = '[{"id":"1","title":"Lunch"}]';
      final decrypted = storage.decryptForTest(plaintextJson);
      expect(decrypted, equals(plaintextJson));
    });

    test('Storage Migration: automatically migrates legacy enc:v1 and plaintext keys to enc:v2 on init', () async {
      // 1. Seed SharedPreferences with legacy enc:v1 transactions and plaintext wallets
      final masterKey = enc.Key.fromSecureRandom(32);
      await secureStorage.write(key: 'pocket_storage_aes_key_v1', value: masterKey.base64);

      final legacyEncrypter = enc.Encrypter(enc.AES(masterKey, mode: enc.AESMode.cbc));
      final legacyIv = enc.IV.fromSecureRandom(16);
      const txJson = '[{"id":"tx_legacy","title":"Old Coffee","amount":150.0,"type":"expense","categoryId":"food","walletId":"w_cash","date":"2026-01-01T12:00:00.000","createdAt":"2026-01-01T12:00:00.000"}]';
      final legacyEncrypted = legacyEncrypter.encrypt(txJson, iv: legacyIv);
      await prefs.setString('pocket_transactions', 'enc:v1:${legacyIv.base64}:${legacyEncrypted.base64}');

      const walletJson = '[{"id":"w_cash","name":"Cash Wallet","icon":"wallet","colorValue":4280391411,"walletType":"cash","currentBalance":5000.0,"isDefault":true}]';
      await prefs.setString('pocket_wallets', walletJson);

      // 2. Initialize StorageService (triggers migration)
      final storage = await StorageService.init(prefs: prefs, secureStorage: secureStorage);

      // 3. Verify that prefs now hold enc:v2 format
      final migratedTxCipher = prefs.getString('pocket_transactions');
      expect(migratedTxCipher, isNotNull);
      expect(migratedTxCipher!.startsWith('enc:v2:'), isTrue);

      final migratedWalletCipher = prefs.getString('pocket_wallets');
      expect(migratedWalletCipher, isNotNull);
      expect(migratedWalletCipher!.startsWith('enc:v2:'), isTrue);

      // 4. Verify data integrity after migration
      final txs = storage.getTransactions();
      expect(txs.length, 1);
      expect(txs.first.id, 'tx_legacy');
      expect(txs.first.title, 'Old Coffee');
      expect(txs.first.amount, 150.0);

      final wallets = storage.getWallets();
      expect(wallets.any((w) => w.id == 'w_cash'), isTrue);
    });

    test('Data Integrity: transaction persistence and recovery through full write/read lifecycle', () async {
      final storage = await StorageService.init(prefs: prefs, secureStorage: secureStorage);

      final testTx = TransactionModel(
        id: 'tx_sec_001',
        title: 'Security Audit Consulting Fee',
        amount: 45000.50,
        type: TransactionType.income,
        categoryId: 'salary',
        walletId: 'w_bank',
        date: DateTime(2026, 11, 18, 10, 30),
        note: 'Verified tamper-evident cryptographic storage',
        createdAt: DateTime.now(),
      );

      await storage.saveTransactions([testTx]);

      // Verify raw storage is encrypted with enc:v2
      final rawStored = prefs.getString('pocket_transactions');
      expect(rawStored, isNotNull);
      expect(rawStored!.startsWith('enc:v2:'), isTrue);
      expect(rawStored.contains('Security Audit Consulting Fee'), isFalse, reason: 'Plaintext must NEVER appear in SharedPreferences');

      // Create new storage instance (simulating cold app restart)
      final restartedStorage = await StorageService.init(prefs: prefs, secureStorage: secureStorage);
      final retrievedTxs = restartedStorage.getTransactions();

      expect(retrievedTxs.length, 1);
      expect(retrievedTxs.first.id, 'tx_sec_001');
      expect(retrievedTxs.first.title, 'Security Audit Consulting Fee');
      expect(retrievedTxs.first.amount, 45000.50);
      expect(retrievedTxs.first.type, TransactionType.income);
      expect(retrievedTxs.first.note, 'Verified tamper-evident cryptographic storage');
    });

    test('Master Key Loss Protection: StorageService.init fails closed when encrypted data exists but key is absent', () async {
      SharedPreferences.setMockInitialValues({
        'pocket_transactions': 'enc:v2:forgediv:forgedciphertext:forgedmac',
      });
      FlutterSecureStorage.setMockInitialValues({}); // Empty secure storage (lost key)

      final customPrefs = await SharedPreferences.getInstance();
      const customSecureStorage = FlutterSecureStorage();

      // Expect StateError when attempting to re-initialize with missing key while encrypted data exists
      expect(
        () async => await StorageService.init(prefs: customPrefs, secureStorage: customSecureStorage),
        throwsA(isA<StateError>()),
        reason: 'StorageService must refuse to generate a new key when encrypted data exists, preventing permanent data loss',
      );
    });

    test('Corrupted Encrypted Record Quarantine: Corrupted record is preserved in backup key and not destroyed on subsequent save', () async {
      const corruptedCiphertext = 'enc:v2:aW52YWxpZGl2:dGFtcGVyZWQ=:ZmFrZW1hYw==';
      SharedPreferences.setMockInitialValues({
        'pocket_transactions': corruptedCiphertext,
      });
      FlutterSecureStorage.setMockInitialValues({
        'pocket_storage_aes_key_v1': base64.encode(List<int>.generate(32, (i) => i + 1)),
      });

      final customPrefs = await SharedPreferences.getInstance();
      const customSecureStorage = FlutterSecureStorage();
      final storage = await StorageService.init(prefs: customPrefs, secureStorage: customSecureStorage);

      // 1. Reading corrupted transactions returns empty list and flags key as corrupted
      final txs = storage.getTransactions();
      expect(txs.isEmpty, isTrue);
      expect(storage.isKeyCorrupted('pocket_transactions'), isTrue);
      expect(storage.getQuarantinedBackup('pocket_transactions'), corruptedCiphertext);

      // 2. Saving a new transaction does not wipe the quarantined backup
      final validTx = TransactionModel(
        id: 'tx_safe_001',
        title: 'New Valid Transaction',
        amount: 250.0,
        type: TransactionType.expense,
        categoryId: 'food',
        walletId: 'w_cash',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await storage.saveTransactions([validTx]);

      // Verify the quarantined backup still exists in SharedPreferences
      final preservedBackup = customPrefs.getString('pocket_transactions_corrupted_backup');
      expect(preservedBackup, corruptedCiphertext,
          reason: 'Raw corrupted ciphertext must be preserved in backup key for forensic recovery');

      // Verify the new transaction was saved and can be read back cleanly
      final afterSaveTxs = storage.getTransactions();
      expect(afterSaveTxs.length, 1);
      expect(afterSaveTxs.first.title, 'New Valid Transaction');
    });
  });
}

