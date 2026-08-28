<div align="center">

```
  ____   ___   ____ _  _______ _____ 
 |  _ \ / _ \ / ___| |/ / ____|_   _|
 | |_) | | | | |   | ' /|  _|   | |  
 |  __/| |_| | |___| . \| |___  | |  
 |_|    \___/ \____|_|\_\_____| |_|  
```

### **The Intelligent, Privacy-First Personal Ledger**
*Autonomous Expense Tracking • Next-Gen Financial Clarity • 100% Offline & Private*

<br/>

[![Build Universal APK](https://github.com/Myselfnandha/Pocket/actions/workflows/build_apk.yml/badge.svg)](https://github.com/Myselfnandha/Pocket/actions/workflows/build_apk.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/State-Riverpod%202.6-00D2B8?style=for-the-badge&logo=dart&logoColor=white)](https://pub.dev/packages/flutter_riverpod)
[![Material 3](https://img.shields.io/badge/Design-Material%203-7D5260?style=for-the-badge&logo=materialdesign&logoColor=white)](https://m3.material.io)
[![AMOLED Ready](https://img.shields.io/badge/Theme-AMOLED%20Pure%20Black-000000?style=for-the-badge&logo=shadow&logoColor=white)](https://github.com/Myselfnandha/Pocket)
[![License](https://img.shields.io/badge/License-MIT-4CAF50?style=for-the-badge)](LICENSE)

<br/>

</div>

---

## 🌟 Executive Summary

**Pocket** is an ultra-modern, privacy-first personal finance tracking powerhouse engineered with Flutter and Dart. Designed with a pure dark AMOLED aesthetic and high-performance reactive architecture, Pocket eliminates bloated cloud dependencies and delivers lightning-fast transaction logging, automated recurring expense resolution, predictive category matching, and actionable financial analytics.

---

## ⚡ Core Innovations & Capabilities

### 1. ⚡ Tactile Fast-Entry & Predictive Numpad
- **Embedded Calculator Keyboard**: Instant calculation (`+`, `-`, `.`, `00`) with haptic feedback and dynamic show/hide transition when entering custom notes.
- **Smart Category Auto-Suggestion**: High-speed heuristic prediction engine that matches past spending patterns and title keywords to automatically select the optimal category.
- **4-Second Non-Blocking Undo**: Instant feedback on transaction recording with quick-rollback capability.

### 2. 🔄 Autonomous Recurring Expenses Subsystem
- **Automated Due Date Resolution**: Automatically evaluates and creates transactions on their due dates upon app launch with zero manual friction.
- **Preset Templates**: One-tap configuration for **Rent (`🏠`)**, **Loan EMI (`💳`)**, **OTT Streaming (`🎬`)**, **Electricity (`⚡`)**, **Phone & Internet (`📱`)**, **Insurance (`🛡️`)**, and **Subscriptions (`📦`)**.
- **Flexible Recurrence**: Full support for **Monthly**, **Weekly**, and **Yearly** cycles with automatic forward date calculation.
- **Dual Management**: Easily toggle recurrence inside the Add Transaction flow or manage rules via the dedicated **Recurring Rules Center** in Settings.

### 3. 🔔 Intelligent Notification & Alert Engine
- **In-App Notification Center**: Centralized alert drawer with real-time unread badges on the dashboard header.
- **Proactive Budget Warnings**: Automatic notifications at **80% wallet capacity** and instant alerts when spending exceeds **100% of limits**.
- **Automated Daily Spending Check-In**: Scheduled local system reminder (customizable time picker, e.g., 8:00 PM) to ensure consistency.
- **Monthly Summary Digest**: Proactive financial scorecards delivered on the 1st of every month.

### 4. 📊 Next-Gen Analytics & Day-of-Week Cash Outflow Matrix
- **Top Spending Category Hero**: Identifies and spotlights the #1 expense category of the month, its share percentage, and total outflow.
- **Day-of-Week Outflow Breakdown**: High-resolution bar chart analyzing spending behavior across **Mon, Tue, Wed, Thu, Fri, Sat, Sun** with peak spending day detection.
- **Category Donut Visualization**: Dynamic interactive pie chart distribution with custom color palettes.
- **Multi-Format Export**: One-tap export to structured **CSV** spreadsheets and formatted **PDF** financial ledger statements.

### 5. 💳 Dynamic Multi-Account / Wallet Architecture
- **Unified Net Balance**: Real-time aggregation of balances across **Cash, Bank, UPI, Credit Cards, and Savings accounts**.
- **Custom Spending Limits**: Set monthly spending limits per account with real-time depletion monitoring.
- **Custom Wallet Creation**: Interactive modal with custom icons, initial balances, and categorization.

### 6. 🔐 Zero-Knowledge Data & Complete Backup/Restore
- **100% Local Encrypted Storage**: All data stays strictly on your physical device — no external tracking or third-party servers.
- **Full JSON Database Backup**: Complete backup export containing all transactions, wallets, recurring rules, and preferences in an interoperable `.json` format.
- **One-Tap Database Restore**: Restore full state with automatic schema validation.
- **CSV Data Import/Export**: Seamlessly import external spreadsheets or export complete transaction history.

### 7. 🌌 AMOLED Pure Black & Auto Adaptive Theme
- **True AMOLED Black (`#000000`)**: Maximizes battery efficiency on OLED/AMOLED displays with minimal power consumption.
- **Time-Based Auto Theme**: Automatically transitions between crisp daylight mode (6:00 AM – 6:00 PM) and deep dark mode (6:00 PM – 6:00 AM).

---

## 🛠️ Architecture & Technology Matrix

```
                      ┌─────────────────────────────────────────┐
                      │            Flutter UI Layer             │
                      │  (Material 3 + AMOLED Pure Black Theme) │
                      └────────────────────┬────────────────────┘
                                           │
                      ┌────────────────────▼────────────────────┐
                      │         Riverpod 2.6 State Engine       │
                      │ (Reactive Notifiers & Derived Selectors)│
                      └────────────────────┬────────────────────┘
                                           │
         ┌─────────────────────────────────┼─────────────────────────────────┐
         │                                 │                                 │
┌────────▼────────┐               ┌────────▼────────┐               ┌────────▼────────┐
│ Recurring Engine│               │ Notification Hub│               │ Backup / Export │
│ (Auto Executor) │               │(System & In-App)│               │  (JSON / CSV)   │
└────────┬────────┘               └────────┬────────┘               └────────┬────────┘
         │                                 │                                 │
         └─────────────────────────────────┼─────────────────────────────────┘
                                           │
                      ┌────────────────────▼────────────────────┐
                      │    Local Encrypted Storage (SharedPreferences) │
                      └─────────────────────────────────────────┘
```

| Layer | Component | Specification |
|---|---|---|
| **Core Framework** | Flutter SDK | `>= 3.11.3` (Dart 3.x) |
| **State Management** | Flutter Riverpod | `^2.6.1` (StateNotifier + Providers) |
| **Routing & Navigation** | GoRouter | `^14.8.1` (StatefulShellRoute with Branching) |
| **Graphics & Charts** | FL Chart | `^0.70.2` (Custom Bar and Donut Charts) |
| **Notifications** | Flutter Local Notifications | `^18.0.1` + `timezone` |
| **File & Data Ops** | File Picker & Share Plus | `^8.1.7` / `^10.1.4` |
| **Document Generation** | PDF & Printing & CSV | `^3.11.2` / `^5.14.2` / `^6.0.0` |
| **Typography** | Google Fonts | Inter Typography Engine |

---

## 📁 Repository Structure

```
lib/
├── main.dart                             # Application bootstrap & background task initialization
├── models/
│   ├── category_model.dart               # Category definitions & transaction types
│   ├── wallet_model.dart                 # Multi-wallet account schemas
│   ├── transaction_model.dart            # Transaction entities & metadata
│   ├── recurring_model.dart              # Automated recurring rule models & presets
│   ├── notification_model.dart           # In-app notification entities & alert types
│   └── settings_model.dart               # User preferences & notification thresholds
├── navigation/
│   ├── app_router.dart                   # GoRouter navigation paths & deep routes
│   └── app_scaffold.dart                 # Double-tap back protection & 3-tab navigation shell
├── providers/
│   └── app_providers.dart                # Riverpod StateNotifiers & reactive selectors
├── screens/
│   ├── home/
│   │   └── home_screen.dart              # Dashboard, hero balance, quick stats & FAB
│   ├── transactions/
│   │   ├── add_transaction_screen.dart   # Centered entry modal, recurring toggle & calculator
│   │   ├── transactions_list_screen.dart # Filterable, searchable transaction history
│   │   └── transaction_detail_screen.dart# Transaction inspection & deletion
│   ├── analytics/
│   │   └── analytics_screen.dart         # Top spending category, day-of-week matrix & reports
│   ├── wallets/
│   │   └── wallets_screen.dart           # Multi-wallet balance manager & creator
│   ├── settings/
│   │   ├── settings_screen.dart          # Master settings & theme preferences
│   │   ├── recurring_rules_screen.dart   # Dedicated recurring expense manager
│   │   └── data_management_screen.dart   # Backup, restore, CSV import/export & database reset
│   ├── notifications/
│   │   └── notification_center_screen.dart # In-app notification center & alerts
│   └── onboarding/
│       └── onboarding_screen.dart        # 3-step setup, mandatory wallet & permission prompt
├── services/
│   ├── storage_service.dart              # Persistent local storage & recurring auto-processor
│   ├── backup_service.dart               # JSON database export/restore & CSV parser
│   └── notification_service.dart         # Local system notifications & threshold monitors
├── theme/
│   └── app_theme.dart                    # Material 3 Pure Black AMOLED & Light theme tokens
└── widgets/
    ├── balance_card.dart                 # Hero balance container with quick inflow/outflow
    ├── numpad.dart                       # Tight tactile calculator keypad
    └── transaction_tile.dart             # Responsive transaction list item
```

---

## 🚀 Installation & Local Development

### 1. Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`^3.11.3` or newer)
- Android Studio / VS Code / Antigravity IDE
- Android device or emulator with Developer Mode enabled

### 2. Quick Start
```bash
# Clone the repository
git clone https://github.com/Myselfnandha/Pocket.git
cd Pocket

# Install Flutter dependencies
flutter pub get

# Run the test suite
flutter test

# Launch in debug mode
flutter run
```

---

## 📦 Automated Release & CI/CD Pipeline

Pocket features a continuous delivery GitHub Actions pipeline ([`.github/workflows/build_apk.yml`](.github/workflows/build_apk.yml)) that compiles optimized universal APKs:

- **Automatic Releases on Version Tag**:
  ```bash
  git tag -a v1.0.3 -m "Release v1.0.3"
  git push origin v1.0.3
  ```
  Triggers automatic compilation of `Pocket-v1.0.3-universal.apk` and publishes a GitHub Release with download assets.
- **Manual Trigger**: Execute workflows on-demand via the **Actions** tab with custom version tags.

---

## 📄 License & Attribution

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for complete terms.

<div align="center">
  <sub>Built with ❤️ by <b>Nandha</b> & pair-programmed with <b>Google Antigravity</b></sub>
</div>
