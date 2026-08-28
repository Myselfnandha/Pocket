# 💳 Pocket — Next-Gen Personal Finance & Wealth Matrix

<div align="center">

```
  ██████╗  ██████╗  ██████╗██╗  ██╗███████╗████████╗
  ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝╚══██╔══╝
  ██████╔╝██║   ██║██║     █████╔╝ █████╗     ██║   
  ██╔═══╝ ██║   ██║██║     ██╔═██╗ ██╔══╝     ██║   
  ██║     ╚██████╔╝╚██████╗██║  ██╗███████╗   ██║   
  ╚═╝      ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝   ╚═╝   
```

**An intelligent, offline-first personal financial management suite engineered with Flutter, Material 3, and AMOLED Pure Black aesthetics.**

---

[![CI/CD Release](https://github.com/Myselfnandha/Pocket/actions/workflows/build_apk.yml/badge.svg)](https://github.com/Myselfnandha/Pocket/actions)
[![Latest Release](https://img.shields.io/github/v/release/Myselfnandha/Pocket?color=00D09C&label=Version)](https://github.com/Myselfnandha/Pocket/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/State-Riverpod%202.6-blueviolet)](https://riverpod.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Theme](https://img.shields.io/badge/Theme-AMOLED%20Pure%20Black-000000)](https://material.io)

</div>

---

## ⚡ Core Capabilities & Intelligent Modules

### 1. ⌨️ Tactile Fast-Entry & Predictive Numpad
- **Integrated Calculator Numpad**: Perform real-time math operations (`+`, `-`, `.`) directly inside the transaction amount display.
- **Smart Dynamic Focus**: Automatically hides the numpad when typing custom notes/tags and restores seamlessly when tapping amounts or blank space.
- **Context-Aware Category Auto-Suggester**: Learns from transaction descriptions and auto-selects categories via heuristics and past habits.

### 2. 📸 Private Receipt & Bill Photo Attachments
- **Zero-Leak Sandboxed Storage**: All receipt photos taken with the camera or selected from files are saved strictly inside the app's internal documents directory with a `.nomedia` file to prevent device gallery indexing.
- **Interactive Zoom Viewer**: Inspect captured receipts with multi-touch pinch-to-zoom (`InteractiveViewer`) and full-screen preview.

### 3. 🤝 Lend & Borrow / Personal Debt Tracker
- **Ledger Cards**: Visual split between **"You are owed" (Lent - Green)** and **"You owe" (Borrowed - Red)** with net position indicator.
- **Phonebook Contact Picker**: Select contacts directly from your device address book (`flutter_contacts`) or use instant name autocomplete.
- **Settlements & Partial Payments**: Record repayments with progress bars and one-tap **"Settle Up"** with optional automatic wallet synchronization.

### 4. 🔄 Autonomous Recurring Expenses Subsystem
- **Automated Lifecycle Processing**: Automatically evaluates and executes due recurring commitments on app startup.
- **Preset Domain Templates**: Instant configuration for **Rent (`🏠`)**, **Loan EMI (`💳`)**, **OTT Subscriptions (`🎬`)**, **Electricity (`⚡`)**, **Phone Bill (`📱`)**, **Insurance (`🛡️`)**, and **Subscriptions (`📦`)**.
- **Configurable Cadence**: Supports `Monthly`, `Weekly`, and `Yearly` execution cycles with custom due-day offsets.

### 5. 🔔 Intelligent Notification & Alert Center
- **In-App Notification Hub**: Real-time unread counter badge on the Home AppBar leading to an in-app alert drawer.
- **Proactive Budget Threshold Warnings**: System notifications trigger automatically at 80% (approaching limit) and 100% (exceeded limit).
- **Daily Spending Check-in**: Scheduled daily reminder at user-selected times.

### 6. 📊 Next-Gen Analytics & Outflow Breakdown
- **Top Spending Category Hero**: Dynamic badge highlighting top monthly outflow category, total spent, and share percentage.
- **Day-of-Week Cash Outflow Matrix**: Mon–Sun cash outflow bar chart highlighting peak spending days in vibrant amber.
- **Monthly Savings Rate**: Live tracking of net savings and savings efficiency percentage.

### 7. 💳 Dynamic Multi-Account & Wallet Architecture
- **Multi-Wallet Support**: Manage Cash, Bank Accounts, Digital Wallets, and Credit Lines.
- **Real-Time Reactive Balances**: Instant calculation across all accounts with custom icons and color tokens.

### 8. 🔐 Zero-Knowledge Data & Local Database Backup
- **Offline-First Security**: Zero telemetry, zero analytics tracking, and zero remote cloud dependencies.
- **Full JSON Schema Backup & Restore**: One-tap export and restore of the entire database.
- **CSV Import & Export**: Import spreadsheet transaction records and export CSV files.

### 9. 🌌 AMOLED Pure Black & Auto Adaptive Theme
- **True AMOLED Black (`#000000`)**: Maximizes battery efficiency on OLED/AMOLED displays.
- **Time-Based Auto Theme**: Transitions smoothly between daylight mode (6:00 AM – 6:00 PM) and deep dark mode (6:00 PM – 6:00 AM).

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
         ┌──────────────────┬──────────────┴───────┬──────────────────┐
         │                  │                      │                  │
┌────────▼────────┐┌────────▼────────┐   ┌─────────▼────────┐┌────────▼────────┐
│ Recurring Engine││ Notification Hub│   │   Debt Ledger    ││ Private Receipts│
│ (Auto Executor) ││(System & In-App)│   │ (Lend & Borrow)  ││   (.nomedia)    │
└────────┬────────┘└────────┬────────┘   └─────────┬────────┘└────────┬────────┘
         │                  │                      │                  │
         └──────────────────┴──────────────┬───────┴──────────────────┘
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
| **Contacts & Media** | Flutter Contacts & Image Picker | `^1.1.9+2` / `^1.1.2` |
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
│   ├── transaction_model.dart            # Transaction entities & receipt paths
│   ├── recurring_model.dart              # Automated recurring rule models & presets
│   ├── notification_model.dart           # In-app notification entities & alert types
│   ├── debt_model.dart                   # Lend & Borrow debt ledger schemas & payments
│   └── settings_model.dart               # User preferences & notification thresholds
├── navigation/
│   ├── app_router.dart                   # GoRouter navigation paths & deep routes
│   └── app_scaffold.dart                 # Double-tap back protection & 3-tab navigation shell
├── providers/
│   └── app_providers.dart                # Riverpod StateNotifiers & reactive selectors
├── screens/
│   ├── home/
│   │   └── home_screen.dart              # Dashboard, hero balance, quick stats & Quick Hub
│   ├── transactions/
│   │   ├── add_transaction_screen.dart   # Centered entry modal, receipt capture & calculator
│   │   ├── transactions_list_screen.dart # Filterable, searchable transaction history
│   │   └── transaction_detail_screen.dart# Transaction inspection, receipt zoom & deletion
│   ├── debts/
│   │   └── debts_screen.dart             # Lend & Borrow tracker, contact picker & settlements
│   ├── analytics/
│   │   └── analytics_screen.dart         # Category breakdown & day-of-week outflow chart
│   ├── wallets/
│   │   └── wallets_screen.dart           # Account balances, wallet creation & limits
│   ├── notifications/
│   │   └── notification_center_screen.dart # In-app notification drawer & action center
│   ├── settings/
│   │   ├── settings_screen.dart          # Master preferences & configuration hub
│   │   ├── recurring_rules_screen.dart   # Recurring expense rule manager
│   │   └── data_management_screen.dart   # Full JSON backup, restore, CSV & database reset
│   └── onboarding/
│       └── onboarding_screen.dart        # Clean 3-step setup, wallet creation & permissions
├── services/
│   ├── storage_service.dart              # Local JSON serialization & state persistence
│   ├── notification_service.dart         # System local notifications & threshold dispatcher
│   ├── backup_service.dart               # Database backup, restore, and CSV parser
│   └── receipt_service.dart              # Sandboxed receipt photo capture & .nomedia privacy
└── theme/
    └── app_theme.dart                    # Material 3 color system & AMOLED Pure Black styles
```

---

## 🚀 Quick Start Guide

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.11.3`)
- Android Studio / VS Code with Flutter Extension
- Android SDK (API 34 / Java 17)

### Local Setup
```bash
# Clone the repository
git clone https://github.com/Myselfnandha/Pocket.git
cd Pocket

# Install dependencies
flutter pub get

# Run static analysis and unit tests
flutter analyze
flutter test

# Launch on connected device / emulator
flutter run
```

---

## 🔄 Automated CI/CD Release Pipeline

Pocket uses GitHub Actions to build and distribute standalone Universal Release APKs on version tag pushes:

```bash
# To trigger an automated release build:
git tag -a v1.0.5 -m "Release v1.0.5"
git push origin v1.0.5
```

The GitHub Actions workflow will:
1. Validate code via `flutter analyze` & `flutter test`.
2. Compile universal release APK (`flutter build apk --release`).
3. Publish a new GitHub Release with the downloadable asset `Pocket-v1.0.5-universal.apk`.
