enum AppThemeMode { autoTime, manual }
enum ManualThemeStyle { light, dark, pureBlack }

enum AppThemePreset {
  emerald,
  cyberpunk,
  sapphire,
  sunset,
  rose,
  custom,
}

class UserSettingsModel {
  final String userName;
  final String? userPhoneNumber;
  final String currencySymbol;
  final String currencyCode;
  final AppThemeMode themeMode;
  final ManualThemeStyle manualThemeStyle;
  final bool isPureBlackEnabled;
  final bool showCategoryTags;
  final bool isOnboarded;

  // Custom Theming
  final AppThemePreset themePreset;
  final int customAccentColorValue;

  // Notification Preferences
  final bool notifyBudgetNearLimit;
  final bool notifyBudgetExceeded;
  final bool notifyRecurringDue;
  final bool dailyReminderEnabled;
  final int dailyReminderHour;
  final int dailyReminderMinute;
  final bool monthlySummaryEnabled;

  const UserSettingsModel({
    this.userName = '',
    this.userPhoneNumber,
    this.currencySymbol = '₹',
    this.currencyCode = 'INR',
    this.themeMode = AppThemeMode.autoTime,
    this.manualThemeStyle = ManualThemeStyle.pureBlack,
    this.isPureBlackEnabled = true,
    this.showCategoryTags = true,
    this.isOnboarded = false,
    this.themePreset = AppThemePreset.emerald,
    this.customAccentColorValue = 0xFF4CAF50,
    this.notifyBudgetNearLimit = true,
    this.notifyBudgetExceeded = true,
    this.notifyRecurringDue = true,
    this.dailyReminderEnabled = true,
    this.dailyReminderHour = 20,
    this.dailyReminderMinute = 0,
    this.monthlySummaryEnabled = true,
  });

  UserSettingsModel copyWith({
    String? userName,
    String? userPhoneNumber,
    String? currencySymbol,
    String? currencyCode,
    AppThemeMode? themeMode,
    ManualThemeStyle? manualThemeStyle,
    bool? isPureBlackEnabled,
    bool? showCategoryTags,
    bool? isOnboarded,
    AppThemePreset? themePreset,
    int? customAccentColorValue,
    bool? notifyBudgetNearLimit,
    bool? notifyBudgetExceeded,
    bool? notifyRecurringDue,
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    bool? monthlySummaryEnabled,
  }) {
    return UserSettingsModel(
      userName: userName ?? this.userName,
      userPhoneNumber: userPhoneNumber ?? this.userPhoneNumber,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      themeMode: themeMode ?? this.themeMode,
      manualThemeStyle: manualThemeStyle ?? this.manualThemeStyle,
      isPureBlackEnabled: isPureBlackEnabled ?? this.isPureBlackEnabled,
      showCategoryTags: showCategoryTags ?? this.showCategoryTags,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      themePreset: themePreset ?? this.themePreset,
      customAccentColorValue: customAccentColorValue ?? this.customAccentColorValue,
      notifyBudgetNearLimit: notifyBudgetNearLimit ?? this.notifyBudgetNearLimit,
      notifyBudgetExceeded: notifyBudgetExceeded ?? this.notifyBudgetExceeded,
      notifyRecurringDue: notifyRecurringDue ?? this.notifyRecurringDue,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
      monthlySummaryEnabled: monthlySummaryEnabled ?? this.monthlySummaryEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'userPhoneNumber': userPhoneNumber,
        'currencySymbol': currencySymbol,
        'currencyCode': currencyCode,
        'themeMode': themeMode.name,
        'manualThemeStyle': manualThemeStyle.name,
        'isPureBlackEnabled': isPureBlackEnabled,
        'showCategoryTags': showCategoryTags,
        'isOnboarded': isOnboarded,
        'themePreset': themePreset.name,
        'customAccentColorValue': customAccentColorValue,
        'notifyBudgetNearLimit': notifyBudgetNearLimit,
        'notifyBudgetExceeded': notifyBudgetExceeded,
        'notifyRecurringDue': notifyRecurringDue,
        'dailyReminderEnabled': dailyReminderEnabled,
        'dailyReminderHour': dailyReminderHour,
        'dailyReminderMinute': dailyReminderMinute,
        'monthlySummaryEnabled': monthlySummaryEnabled,
      };

  factory UserSettingsModel.fromJson(Map<String, dynamic> json) =>
      UserSettingsModel(
        userName: json['userName'] as String? ?? '',
        userPhoneNumber: json['userPhoneNumber'] as String?,
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
        themePreset: AppThemePreset.values.byName(
          json['themePreset'] as String? ?? 'emerald',
        ),
        customAccentColorValue: json['customAccentColorValue'] as int? ?? 0xFF4CAF50,
        notifyBudgetNearLimit: json['notifyBudgetNearLimit'] as bool? ?? true,
        notifyBudgetExceeded: json['notifyBudgetExceeded'] as bool? ?? true,
        notifyRecurringDue: json['notifyRecurringDue'] as bool? ?? true,
        dailyReminderEnabled: json['dailyReminderEnabled'] as bool? ?? true,
        dailyReminderHour: json['dailyReminderHour'] as int? ?? 20,
        dailyReminderMinute: json['dailyReminderMinute'] as int? ?? 0,
        monthlySummaryEnabled: json['monthlySummaryEnabled'] as bool? ?? true,
      );
}
