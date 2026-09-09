# Known Gotchas & Edge Cases

## 1. Local Android SDK Toolchain
- The local development workstation does not have Android NDK or cmdline-tools installed.
- Local Gradle release tasks fail with `LicenceNotAcceptedException: ndk;27.0.12077973` or Java version mismatches.
- Workaround: Do not compile release binaries locally. Push commits to GitHub where `.github/workflows/build_apk.yml` handles full Android SDK, NDK, keystores, and signing.

## 2. Flutter SVG Filter Limitations
- `flutter_svg` does not reliably support complex SVG `<filter>` chains (e.g. `feGaussianBlur`) or HTML styling.
- Glassmorphism must be achieved using pure vector geometry, multi-stop radial/linear gradients, and opacity layers.
