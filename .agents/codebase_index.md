# Codebase Context: Pocket
> Auto-generated on 2026-10-17 22:36:53. 238 files, ~460,429 tokens.

## Directory Overview

### `./` (13 files)
- `.gitignore` — Miscellaneous .class (42 lines)
- `.metadata` — This file tracks properties of this Flutter project. Used by Flutter tool to assess cap... (40 lines)
- `LICENSE` — Text file: 17 lines
- `README.md` — 💳 Pocket — Next-Gen Personal Finance & Wealth Matrix (209 lines)
- `analysis_options.yaml` — YAML config: include, analyzer, linter
- `c2c_runner.py` — HTTP client; functions: log, run_cmd, check_url_exists, wait_and_download_apk +8 more
- `implementation_plan.md` — Pocket — Transaction Tracking App (326 lines)
- `live_c2c_device_test.py` — Tests: 10 test functions/methods
- `pocket_ui_prompts.md` — Pocket App — UI Generation Prompts (732 lines)
- `pubspec.lock` — Lockfile manifest: 140 resolved dependencies
- `pubspec.yaml` — YAML config: name, description, publish_to, version, environment
- `run_calibrated_c2c.py` — functions: log, run_cmd, tap_xy, key_back +5 more
- ... and 1 more files

### `.github/` (1 files)
- `.github/workflows/build_apk.yml` — GitHub Actions workflow

### `android/` (54 files)
- `android/.gitignore` — Remember to never publicly share your keystore. (13 lines)
- `android/app/build.gradle.kts` — KTS file: 66 lines
- `android/app/src/debug/AndroidManifest.xml` — > (7 lines)
- `android/app/src/main/AndroidManifest.xml` — XML file: 185 lines
- `android/app/src/main/kotlin/com/pocket/pocket/MainActivity.kt` — KT file: 297 lines
- `android/app/src/main/kotlin/com/pocket/pocket/NotificationDismissReceiver.kt` — KT file: 11 lines
- `android/app/src/main/kotlin/com/pocket/pocket/PocketAccessibilityService.kt` — KT file: 127 lines
- `android/app/src/main/kotlin/com/pocket/pocket/PocketBarWidgetProvider.kt` — KT file: 56 lines
- `android/app/src/main/kotlin/com/pocket/pocket/PocketCardWidgetProvider.kt` — KT file: 62 lines
- `android/app/src/main/kotlin/com/pocket/pocket/PocketNotificationListener.kt` — KT file: 181 lines
- `android/app/src/main/kotlin/com/pocket/pocket/PocketRunwayWidgetProvider.kt` — KT file: 47 lines
- `android/app/src/main/kotlin/com/pocket/pocket/PocketScreenshotObserver.kt` — KT file: 71 lines
- ... and 42 more files

### `assets/` (6 files)
- `assets/avatars/cosmic_vault.svg` — SVG file: 84 lines
- `assets/avatars/emerald_growth.svg` — SVG file: 81 lines
- `assets/avatars/quantum_flow.svg` — SVG file: 85 lines
- `assets/avatars/solar_wealth.svg` — SVG file: 80 lines
- `assets/icons/pocket_app_icon.svg` — SVG file: 37 lines
- `assets/icons/pocket_logo.svg` — SVG file: 14 lines

### `integration_test/` (1 files)
- `integration_test/sms_auto_import_test.dart` — 1 functions

### `ios/` (22 files)
- `ios/.gitignore` — /dgph .mode1v3 (33 lines)
- `ios/Flutter/AppFrameworkInfo.plist` — PLIST file: 24 lines
- `ios/Flutter/Debug.xcconfig` — include "Generated.xcconfig" (1 lines)
- `ios/Flutter/Release.xcconfig` — include "Generated.xcconfig" (1 lines)
- `ios/Runner.xcodeproj/project.pbxproj` — Begin PBXBuildFile section (605 lines)
- `ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata` — XCWORKSPACEDATA file: 7 lines
- `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` — PLIST file: 8 lines
- `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` — XCSETTINGS file: 8 lines
- `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` — XCSCHEME file: 101 lines
- `ios/Runner.xcworkspace/contents.xcworkspacedata` — XCWORKSPACEDATA file: 7 lines
- `ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` — PLIST file: 8 lines
- `ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` — XCSETTINGS file: 8 lines
- ... and 10 more files

### `lib/` (78 files)
- `lib/main.dart` — Dart classes: PocketApp, _PocketAppState; 12 functions
- `lib/models/budget_model.dart` — Dart classes: CategoryBudgetModel; 7 functions
- `lib/models/category_model.dart` — Dart classes: CategoryModel; 20 functions
- `lib/models/debt_model.dart` — Dart classes: DebtPaymentModel, DebtModel; 8 functions
- `lib/models/goal_model.dart` — Dart classes: GoalModel; 4 functions
- `lib/models/notification_model.dart` — Dart classes: AppNotificationModel; 4 functions
- `lib/models/pending_transaction_model.dart` — Dart classes: PendingTransactionModel, UniqueKey; 6 functions
- `lib/models/recurring_model.dart` — Dart classes: RecurringRuleModel; 7 functions
- `lib/models/settings_model.dart` — Dart classes: UserSettingsModel; 6 functions
- `lib/models/transaction_model.dart` — Dart classes: TransactionModel; 4 functions
- `lib/models/wallet_model.dart` — Dart classes: WalletModel; 7 functions
- `lib/navigation/app_router.dart` — 6 functions
- ... and 66 more files

### `linux/` (10 files)
- `linux/.gitignore` — Text file: 1 lines
- `linux/CMakeLists.txt` — Project-level configuration. (104 lines)
- `linux/flutter/CMakeLists.txt` — This file controls Flutter-level build steps. It should not be edited. (79 lines)
- `linux/flutter/generated_plugin_registrant.cc` — Generated file. Do not edit. (23 lines)
- `linux/flutter/generated_plugin_registrant.h` — 1 functions
- `linux/flutter/generated_plugins.cmake` — Generated file, do not edit. (23 lines)
- `linux/runner/CMakeLists.txt` — Define the application target. To change its name, change BINARY_NAME in the top-level ... (21 lines)
- `linux/runner/main.cc` — include "my_application.h" (5 lines)
- `linux/runner/my_application.cc` — include "my_application.h" (120 lines)
- `linux/runner/my_application.h` — 1 functions

### `macos/` (21 files)
- `macos/.gitignore` — Flutter-related /Flutter/ephemeral/ (6 lines)
- `macos/Flutter/Flutter-Debug.xcconfig` — include "ephemeral/Flutter-Generated.xcconfig" (1 lines)
- `macos/Flutter/Flutter-Release.xcconfig` — include "ephemeral/Flutter-Generated.xcconfig" (1 lines)
- `macos/Flutter/GeneratedPluginRegistrant.swift` — Generated file. Do not edit. (23 lines)
- `macos/Runner.xcodeproj/project.pbxproj` — Begin PBXAggregateTarget section (689 lines)
- `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` — PLIST file: 8 lines
- `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` — XCSCHEME file: 99 lines
- `macos/Runner.xcworkspace/contents.xcworkspacedata` — XCWORKSPACEDATA file: 7 lines
- `macos/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` — PLIST file: 8 lines
- `macos/Runner/AppDelegate.swift` — SWIFT file: 11 lines
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` — JSON data
- `macos/Runner/Base.lproj/MainMenu.xib` — XIB file: 343 lines
- ... and 9 more files

### `scripts/` (1 files)
- `scripts/run_e2e_sms_test.py` — Tests: 1 test functions/methods

### `supabase/` (1 files)
- `supabase/migrations/20260830134500_create_pocket_backups.sql` — creates tables: public; alters: public; 1 indexes

### `test/` (11 files)
- `test/ai_intelligence_test.dart` — 3 functions
- `test/app_test.dart` — 1 functions
- `test/auto_import_service_test.dart` — 1 functions
- `test/avatar_test.dart` — 2 functions
- `test/balance_and_wallet_edit_test.dart` — 1 functions
- `test/e2e_flow_test.dart` — 1 functions
- `test/home_screen_widget_suite_test.dart` — 1 functions
- `test/pending_transactions_widget_test.dart` — 1 functions
- `test/sms_auto_read_test.dart` — Dart classes: FakeStorageService; 4 functions
- `test/upi_screenshot_parser_test.dart` — 1 functions
- `test/widget_test.dart` — 1 functions

### `web/` (2 files)
- `web/index.html` — HTML file: 38 lines
- `web/manifest.json` — package.json

### `windows/` (17 files)
- `windows/.gitignore` — Visual Studio user-specific files. .suo (14 lines)
- `windows/CMakeLists.txt` — Project-level configuration. (89 lines)
- `windows/flutter/CMakeLists.txt` — This file controls Flutter-level build steps. It should not be edited. (98 lines)
- `windows/flutter/generated_plugin_registrant.cc` — Generated file. Do not edit. (22 lines)
- `windows/flutter/generated_plugin_registrant.h` — 1 functions
- `windows/flutter/generated_plugins.cmake` — Generated file, do not edit. (24 lines)
- `windows/runner/CMakeLists.txt` — Define the application target. To change its name, change BINARY_NAME in the top-level ... (34 lines)
- `windows/runner/Runner.rc` — Microsoft Visual C++ generated resource script. pragma code_page(65001) (98 lines)
- `windows/runner/flutter_window.cpp` — include "flutter_window.h" (56 lines)
- `windows/runner/flutter_window.h` — classes: FlutterWindow
- `windows/runner/main.cpp` — 1 functions
- `windows/runner/resource.h` — {{NO_DEPENDENCIES}} Microsoft Visual C++ generated include file. (15 lines)
- ... and 5 more files

