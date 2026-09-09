import 'package:intl/intl.dart';

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

enum HomeScreenWidgetStat {
  balanceAndTodaySpend,
  netWorth,
  monthlySavings,
  budgetRemaining,
  debtsSummary,
  forecastTrajectory,
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

  // Profile Avatar
  final String selectedAvatarId;

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

  // Widget Customization
  final HomeScreenWidgetStat homeScreenWidgetStat;

  const UserSettingsModel({
    this.userName = '',
    this.userPhoneNumber,
    this.currencySymbol = '₹',
    this.currencyCode = 'INR',
    this.selectedAvatarId = 'solar_wealth',
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
    this.homeScreenWidgetStat = HomeScreenWidgetStat.balanceAndTodaySpend,
  });

  /// Smart currency-aware formatting: INR uses Indian numbering (₹1,20,000.00), others use international ($120,000.00)
  String formatCurrency(double amount, {bool includeSymbol = true}) {
    final isIndian = currencyCode.toUpperCase() == 'INR' || currencySymbol == '₹';
    final formatter = NumberFormat.currency(
      locale: isIndian ? 'en_IN' : 'en_US',
      symbol: includeSymbol ? currencySymbol : '',
      decimalDigits: 2,
    );
    return formatter.format(amount).trim();
  }

  /// Compact currency format with proper grouping (e.g. ₹1.2L or $120K)
  String formatCompact(double amount, {bool includeSymbol = true}) {
    final isIndian = currencyCode.toUpperCase() == 'INR' || currencySymbol == '₹';
    final formatter = NumberFormat.compactCurrency(
      locale: isIndian ? 'en_IN' : 'en_US',
      symbol: includeSymbol ? currencySymbol : '',
    );
    return formatter.format(amount).trim();
  }

  UserSettingsModel copyWith({
    String? userName,
    String? userPhoneNumber,
    String? currencySymbol,
    String? currencyCode,
    String? selectedAvatarId,
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
    HomeScreenWidgetStat? homeScreenWidgetStat,
  }) {
    return UserSettingsModel(
      userName: userName ?? this.userName,
      userPhoneNumber: userPhoneNumber ?? this.userPhoneNumber,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      selectedAvatarId: selectedAvatarId ?? this.selectedAvatarId,
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
      homeScreenWidgetStat: homeScreenWidgetStat ?? this.homeScreenWidgetStat,
    );
  }

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'userPhoneNumber': userPhoneNumber,
        'currencySymbol': currencySymbol,
        'currencyCode': currencyCode,
        'selectedAvatarId': selectedAvatarId,
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
        'homeScreenWidgetStat': homeScreenWidgetStat.name,
      };

  factory UserSettingsModel.fromJson(Map<String, dynamic> json) =>
      UserSettingsModel(
        userName: json['userName'] as String? ?? '',
        userPhoneNumber: json['userPhoneNumber'] as String?,
        currencySymbol: json['currencySymbol'] as String? ?? '₹',
        currencyCode: json['currencyCode'] as String? ?? 'INR',
        selectedAvatarId: json['selectedAvatarId'] as String? ?? 'solar_wealth',
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
        homeScreenWidgetStat: HomeScreenWidgetStat.values.byName(
          json['homeScreenWidgetStat'] as String? ?? 'balanceAndTodaySpend',
        ),
      );
}
