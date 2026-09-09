import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/models/settings_model.dart';
import 'package:pocket/widgets/user_avatar_widget.dart';

void main() {
  group('Glassmorphic Orbs Avatar Pack Tests', () {
    test('kAvatarGallery contains the 4 new Glassmorphic Orb avatars', () {
      expect(kAvatarGallery.length, 4);
      final ids = kAvatarGallery.map((a) => a.id).toList();
      expect(ids, containsAll([
        'solar_wealth',
        'emerald_growth',
        'quantum_flow',
        'cosmic_vault',
      ]));
    });

    test('All avatar asset files exist on disk', () {
      for (final item in kAvatarGallery) {
        final file = File(item.assetPath);
        expect(file.existsSync(), isTrue, reason: 'Asset not found: ${item.assetPath}');
        expect(file.lengthSync(), greaterThan(500), reason: 'Asset too small: ${item.assetPath}');
      }
    });

    test('Legacy avatar IDs correctly map to Glassmorphic Orbs', () {
      expect(kLegacyAvatarMap['cyber_hacker'], 'quantum_flow');
      expect(kLegacyAvatarMap['wealth_architect'], 'solar_wealth');
      expect(kLegacyAvatarMap['neon_nomad'], 'emerald_growth');
      expect(kLegacyAvatarMap['crypto_vault'], 'cosmic_vault');
    });

    test('UserSettingsModel defaults to solar_wealth', () {
      const settings = UserSettingsModel();
      expect(settings.selectedAvatarId, 'solar_wealth');

      final fromJson = UserSettingsModel.fromJson({});
      expect(fromJson.selectedAvatarId, 'solar_wealth');
    });

    testWidgets('UserAvatarWidget renders with legacy and new IDs without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                UserAvatarWidget(avatarId: 'solar_wealth'),
                UserAvatarWidget(avatarId: 'cyber_hacker'), // legacy mapped
                UserAvatarWidget(avatarId: 'unknown_avatar_id'), // fallback
              ],
            ),
          ),
        ),
      );

      expect(find.byType(UserAvatarWidget), findsNWidgets(3));
    });
  });
}
