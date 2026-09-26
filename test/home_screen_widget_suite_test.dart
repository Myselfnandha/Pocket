import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/models/settings_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home Screen Widget Suite Tests', () {
    test('UserSettingsModel widget settings defaults and copyWith', () {
      const settings = UserSettingsModel();
      expect(settings.widgetPrivacyMode, false);
      expect(settings.widgetSelectedWalletId, isNull);
      expect(settings.widgetSecondaryAction, 'scan');

      // Toggle privacy mode
      final withPrivacy = settings.copyWith(widgetPrivacyMode: true);
      expect(withPrivacy.widgetPrivacyMode, true);

      // Select specific wallet and secondary action
      final withWallet = withPrivacy.copyWith(
        widgetSelectedWalletId: 'wallet_hdfc_123',
        widgetSecondaryAction: 'voice',
      );
      expect(withWallet.widgetSelectedWalletId, 'wallet_hdfc_123');
      expect(withWallet.widgetSecondaryAction, 'voice');

      // Clear wallet selection
      final clearedWallet = withWallet.copyWith(clearWidgetSelectedWalletId: true);
      expect(clearedWallet.widgetSelectedWalletId, isNull);
      expect(clearedWallet.widgetPrivacyMode, true);
    });

    test('UserSettingsModel JSON serialization roundtrip for widget configs', () {
      final model = const UserSettingsModel().copyWith(
        widgetPrivacyMode: true,
        widgetSelectedWalletId: 'bank_axis_456',
        widgetSecondaryAction: 'voice',
      );

      final json = model.toJson();
      expect(json['widgetPrivacyMode'], true);
      expect(json['widgetSelectedWalletId'], 'bank_axis_456');
      expect(json['widgetSecondaryAction'], 'voice');

      final deserialized = UserSettingsModel.fromJson(json);
      expect(deserialized.widgetPrivacyMode, true);
      expect(deserialized.widgetSelectedWalletId, 'bank_axis_456');
      expect(deserialized.widgetSecondaryAction, 'voice');
    });
  });
}
