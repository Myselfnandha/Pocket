# No Local Release Builds (Workspace Rule)

1. **Strict Invariant**: Never run release binary or APK compilation commands (`flutter build apk`, `assembleRelease`, `./gradlew bundleRelease`, etc.) locally on the host machine.
2. **CI-Only Builds**: All artifact generation, release packaging, and signing must only be executed by GitHub Actions CI workflows (`.github/workflows/build_apk.yml`).
3. **Allowed Local Operations**:
   - Static analysis: `flutter analyze`
   - Unit & widget testing: `flutter test`
   - Git operations: `git commit`, `git tag`, `git push`
4. **Triggering Builds**: To generate a new build or release APK, update `pubspec.yaml`, commit, tag if needed, and push to GitHub so CI handles compilation and distribution.
