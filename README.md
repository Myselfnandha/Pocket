<div align="center">

# 🌿 Pocket

**Track every rupee. Master your money.**

A sleek, premium mobile transaction tracking application built with **Flutter**, **Material 3**, **Riverpod**, and **FLChart**.

[![Build Universal APK](https://github.com/Myselfnandha/Pocket/actions/workflows/build_apk.yml/badge.svg)](https://github.com/Myselfnandha/Pocket/actions/workflows/build_apk.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Material 3](https://img.shields.io/badge/Design-Material%203-7D5260?logo=materialdesign)](https://m3.material.io)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

</div>

## ✨ Key Features

- **⚡ Fast Calculator-Style Entry**: Log expenses with an embedded tactile calculator numpad, quick operators (`+`, `-`, `.`), and instant auto-save with a 3-second floating undo snackbar.
- **✨ Smart Category Auto-Suggestion**: Intelligently predicts categories based on transaction title history and smart keyword matching in real-time.
- **🎨 AMOLED Pure Black & Auto Theme**: Pure Black (`#000000`) for OLED displays and clean light mode, with automatic time-of-day switching (6 PM – 6 AM).
- **📊 Real-Time Analytics & Trends**: Interactive month navigator, savings rate percentage bar, and daily spending trend line curves powered by `fl_chart`.
- **💳 Multi-Wallet Management**: Track balances across multiple accounts (Cash, Bank, UPI, Savings) with live balance recalculation and visual allocation bars.
- **📑 Financial Reports Export**: Generate and share structured **CSV** and formatted **PDF** financial statements with one tap.
- **🔒 App Security**: Biometric (Fingerprint/Face) and PIN lock support.
- **🌟 Interactive Onboarding**: Streamlined 3-step setup to customize your name and currency (`₹ INR`, `$ USD`, `€ EUR`, etc.).

---

## 🛠️ Tech Stack & Architecture

| Layer | Technology |
|---|---|
| **Framework** | [Flutter](https://flutter.dev) (Dart 3.x) |
| **Design System** | Material 3 with Forest Green (`#2E7D32`) & Warm Orange (`#FF9800`) |
| **State Management** | [Flutter Riverpod](https://pub.dev/packages/flutter_riverpod) (2.6+) |
| **Navigation** | [GoRouter](https://pub.dev/packages/go_router) with StatefulShellRoute |
| **Charts** | [FL Chart](https://pub.dev/packages/fl_chart) |
| **Persistence** | [Shared Preferences](https://pub.dev/packages/shared_preferences) |
| **Exporting** | [CSV](https://pub.dev/packages/csv), [PDF](https://pub.dev/packages/pdf), [Printing](https://pub.dev/packages/printing), [Share Plus](https://pub.dev/packages/share_plus) |
| **Typography** | [Google Fonts](https://pub.dev/packages/google_fonts) (Inter) |

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`^3.11.3` or newer)
- Android Studio / VS Code / Antigravity IDE
- Android device or emulator (or Linux / macOS / Web desktop targets)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Myselfnandha/Pocket.git
   cd Pocket
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the test suite:**
   ```bash
   flutter test
   ```

4. **Launch the application:**
   ```bash
   flutter run
   ```

---

## 📦 Automated APK Builds & GitHub Actions

Pocket includes a GitHub Actions CI/CD pipeline (`.github/workflows/build_apk.yml`) that automatically builds and packages universal release APKs on push or version tag:

- **Build on Version Tag**: Push a git tag (e.g. `git tag -a v1.0.0 -m "Release v1.0.0" && git push origin --tags`) to automatically compile `Pocket-v1.0.0-universal.apk` and publish a GitHub Release with download assets.
- **Manual Trigger**: Run the workflow manually from the **Actions** tab in GitHub with customizable `version_name` and `build_number`.

---

## 📁 Project Structure

```
lib/
├── main.dart                   # App entry point & ProviderScope setup
├── models/                     # Data models (Transaction, Wallet, Category, Settings)
├── navigation/                 # GoRouter & 5-tab Material 3 AppScaffold
├── providers/                  # Riverpod state notifiers & derived selectors
├── screens/
│   ├── home/                   # Dashboard, balance cards, daily feed
│   ├── transactions/           # Calculator entry, full list, search & detail
│   ├── analytics/              # Monthly trends & CSV/PDF exports
│   ├── wallets/                # Account balances & wallet creator
│   ├── settings/               # Profile, theme selector & category manager
│   └── onboarding/             # First-launch setup & currency picker
├── services/                   # Local storage & auto-suggestion algorithms
├── theme/                      # AMOLED dark & light Material 3 design system
└── widgets/                    # Reusable components (BalanceCard, Numpad, etc.)
```

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
