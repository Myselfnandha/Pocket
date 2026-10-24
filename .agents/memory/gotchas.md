# Gotchas & Anti-Patterns - Pocket Mobile

## G-001: Modal Dialog Dismissal on Keyevent 111 (ESC/BACK)
- **Symptom:** Sending `adb shell input keyevent 111` to close the soft keyboard inadvertently dismisses the entire active modal dialog/bottom sheet.
- **Solution:** Use keyboard-down arrow tap or specific touch coordinates rather than generic ESC/BACK keyevents when interacting with open modals in automated testing.

## G-002: Flutter Search TextField State vs Widget Sync
- **Symptom:** Pressing a clear ('✕') button in `suffixIcon` clears the string state in `setState(() => _searchQuery = '')`, but the native onscreen input continues to show the typed characters and triggers unintended filter states.
- **Solution:** Always bind `controller: _searchController` and invoke `_searchController.clear()` when clearing.

## G-003: Sandbox Network / Unix Domain Socket Reset
- **Symptom:** Running adb or external CLI tools in standard sandbox mode can encounter `connection reset by peer` when opening local unix sockets.
- **Solution:** Use `BypassSandbox: true` while preserving identical `toolAction` and `toolSummary`.

## G-004: Status Bar & AppBar Coordinate Scaling on 1080x2400 Viewports
- **Symptom:** Blindly assuming standard 56dp AppBar height at y=100-200 can miss action icons on hole-punch displays where the status bar is 24-48dp and AppBar actions sit at y ~ 210.
- **Solution:** Use `adb shell uiautomator dump` to extract precise pixel bounding boxes `bounds="[x1,y1][x2,y2]"` before automated taps.
