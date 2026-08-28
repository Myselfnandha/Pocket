enum AppThemeMode { autoTime, manual }
enum ManualThemeStyle { light, dark, pureBlack }

class UserSettingsModel {
  final String userName;
  final String currencySymbol;
  final String currencyCode;
  final AppThemeMode themeMode;
  final ManualThemeStyle manualThemeStyle;
  final bool isPureBlackEnabled;
  final bool showCategoryTags;
  final bool isOnboarded;

  const UserSettingsModel({
    this.userName = 'Nandha',
    this.currencySymbol = '₹',
    this.currencyCode = 'INR',
    this.themeMode = AppThemeMode.autoTime,
    this.manualThemeStyle = ManualThemeStyle.pureBlack,
    this.isPureBlackEnabled = true,
    this.showCategoryTags = true,
    this.isOnboarded = false,
  });

  UserSettingsModel copyWith({
    String? userName,
    String? currencySymbol,
    String? currencyCode,
    AppThemeMode? themeMode,
    ManualThemeStyle? manualThemeStyle,
    bool? isPureBlackEnabled,
    bool? showCategoryTags,
    bool? isOnboarded,
  }) {
    return UserSettingsModel(
      userName: userName ?? this.userName,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      themeMode: themeMode ?? this.themeMode,
      manualThemeStyle: manualThemeStyle ?? this.manualThemeStyle,
      isPureBlackEnabled: isPureBlackEnabled ?? this.isPureBlackEnabled,
      showCategoryTags: showCategoryTags ?? this.showCategoryTags,
      isOnboarded: isOnboarded ?? this.isOnboarded,
    );
  }

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'currencySymbol': currencySymbol,
        'currencyCode': currencyCode,
        'themeMode': themeMode.name,
        'manualThemeStyle': manualThemeStyle.name,
        'isPureBlackEnabled': isPureBlackEnabled,
        'showCategoryTags': showCategoryTags,
        'isOnboarded': isOnboarded,
      };

  factory UserSettingsModel.fromJson(Map<String, dynamic> json) =>
      UserSettingsModel(
        userName: json['userName'] as String? ?? 'Nandha',
        currencySymbol: json['currencySymbol'] as String? ?? '₹',
        currencyCode: json['currencyCode'] as String? ?? 'INR',
        themeMode: AppThemeMode.values.byName(
          json['themeMode'] as String? ?? 'autoTime',
        ),
        manualThemeStyle: ManualThemeStyle.values.byName(
          json['manualThemeStyle'] as String? ?? 'pureBlack',
        ),
        isPureBlackEnabled: json['isPureBlackEnabled'] as bool? ?? true,
        showCategoryTags: json['showCategoryTags'] as bool? ?? true,
        isOnboarded: json['isOnboarded'] as bool? ?? false,
      );
}
