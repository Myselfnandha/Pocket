# Architectural Decisions & Invariants

## 1. Release Artifacts via CI Only
- All release APK builds, bundle packaging, and GitHub releases are performed exclusively by GitHub Actions (`.github/workflows/build_apk.yml`).
- Never run `flutter build apk --release` or `./gradlew assembleRelease` on the local machine.
- Local verification is strictly limited to static analysis (`flutter analyze`), unit/widget tests (`flutter test`), and development runners.

## 2. Avatar System Strategy
- Avatars use pure vector SVG without external font or filter dependencies for cross-platform compatibility in `flutter_svg`.
- The active pack uses the Glassmorphic Orbs theme: `solar_wealth`, `emerald_growth`, `quantum_flow`, `cosmic_vault`.
- `kLegacyAvatarMap` in `UserAvatarWidget` guarantees backward compatibility for any existing user profile selections.
