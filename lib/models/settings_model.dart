enum AppThemePreference { autoTime, darkAmoled, light }

class UserSettingsModel {
  final String userName;
  final String currencySymbol;
  final String currencyCode;
  final AppThemePreference themePreference;
  final bool biometricEnabled;
  final bool pinLockEnabled;
  final String? pinCode;
  final bool isOnboarded;

  const UserSettingsModel({
    this.userName = 'Nandha',
    this.currencySymbol = '₹',
    this.currencyCode = 'INR',
    this.themePreference = AppThemePreference.autoTime,
    this.biometricEnabled = false,
    this.pinLockEnabled = false,
    this.pinCode,
    this.isOnboarded = false,
  });

  UserSettingsModel copyWith({
    String? userName,
    String? currencySymbol,
    String? currencyCode,
    AppThemePreference? themePreference,
    bool? biometricEnabled,
    bool? pinLockEnabled,
    String? pinCode,
    bool? isOnboarded,
  }) {
    return UserSettingsModel(
      userName: userName ?? this.userName,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      themePreference: themePreference ?? this.themePreference,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      pinLockEnabled: pinLockEnabled ?? this.pinLockEnabled,
      pinCode: pinCode ?? this.pinCode,
      isOnboarded: isOnboarded ?? this.isOnboarded,
    );
  }

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'currencySymbol': currencySymbol,
        'currencyCode': currencyCode,
        'themePreference': themePreference.name,
        'biometricEnabled': biometricEnabled,
        'pinLockEnabled': pinLockEnabled,
        'pinCode': pinCode,
        'isOnboarded': isOnboarded,
      };

  factory UserSettingsModel.fromJson(Map<String, dynamic> json) =>
      UserSettingsModel(
        userName: json['userName'] as String? ?? 'Nandha',
        currencySymbol: json['currencySymbol'] as String? ?? '₹',
        currencyCode: json['currencyCode'] as String? ?? 'INR',
        themePreference: AppThemePreference.values.byName(
          json['themePreference'] as String? ?? 'autoTime',
        ),
        biometricEnabled: json['biometricEnabled'] as bool? ?? false,
        pinLockEnabled: json['pinLockEnabled'] as bool? ?? false,
        pinCode: json['pinCode'] as String?,
        isOnboarded: json['isOnboarded'] as bool? ?? false,
      );
}
