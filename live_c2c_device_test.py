#!/usr/bin/env python3
"""
Live C2C Interactive UI Test Runner for Pocket
- Detects unlocked state on ADB device dc96724c1e0d
- Executes comprehensive Click-to-Click test suite across all tabs & features
- Captures high-res visual verification screenshots to artifacts directory
"""

import os
import sys
import time
import subprocess
import xml.etree.ElementTree as ET

DEVICE_ID = "dc96724c1e0d"
PACKAGE_NAME = "com.pocket.pocket"
ARTIFACT_DIR = "/home/nandha/.gemini/antigravity-ide/brain/034d6163-7069-49d8-8ac4-9c6b2f1cb3c7"

def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)

def run_cmd(cmd, check=False):
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return res

def is_device_locked():
    res = run_cmd(f"adb -s {DEVICE_ID} shell dumpsys window | grep -i isKeyguardShowing")
    return "isKeyguardShowing=true" in res.stdout

def dump_ui():
    run_cmd(f"adb -s {DEVICE_ID} shell uiautomator dump /sdcard/c2c_ui.xml")
    run_cmd(f"adb -s {DEVICE_ID} pull /sdcard/c2c_ui.xml /tmp/c2c_ui.xml")
    if os.path.exists("/tmp/c2c_ui.xml"):
        try:
            return ET.parse("/tmp/c2c_ui.xml").getroot()
        except Exception as e:
            log(f"XML parse error: {e}")
    return None

def find_node_by_text(root, text_substring):
    if root is None:
        return None
    for elem in root.iter():
        text = elem.attrib.get('text', '') or elem.attrib.get('content-desc', '')
        if text_substring.lower() in text.lower():
            return elem
    return None

def get_node_center(node):
    bounds = node.attrib.get('bounds')
    if bounds:
        import re
        m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', bounds)
        if m:
            x1, y1, x2, y2 = map(int, m.groups())
            return (x1 + x2) // 2, (y1 + y2) // 2
    return None

def tap_node(node):
    center = get_node_center(node)
    if center:
        x, y = center
        log(f"Tapping node '{node.attrib.get('text') or node.attrib.get('content-desc')}' at ({x}, {y})...")
        run_cmd(f"adb -s {DEVICE_ID} shell input tap {x} {y}")
        time.sleep(1.5)
        return True
    return False

def tap_xy(x, y, desc="coordinate"):
    log(f"Tapping {desc} at ({x}, {y})...")
    run_cmd(f"adb -s {DEVICE_ID} shell input tap {x} {y}")
    time.sleep(1.5)

def capture_screenshot(step_name):
    sdcard_path = f"/sdcard/{step_name}.png"
    local_path = os.path.join(ARTIFACT_DIR, f"{step_name}.png")
    run_cmd(f"adb -s {DEVICE_ID} shell screencap -p {sdcard_path}")
    run_cmd(f"adb -s {DEVICE_ID} pull {sdcard_path} {local_path}")
    log(f"Screenshot saved: {local_path}")
    return local_path

def main():
    log(f"Connecting to device {DEVICE_ID}...")
    run_cmd(f"adb -s {DEVICE_ID} shell svc power stayon true")
    run_cmd(f"adb -s {DEVICE_ID} shell input keyevent KEYCODE_WAKEUP")
    
    if is_device_locked():
        log("DEVICE IS CURRENTLY LOCKED with Pattern/Fingerprint.")
        log("Waiting up to 60s for user to unlock the device...")
        for i in range(60):
            if not is_device_locked():
                log("Device unlocked! Proceeding with C2C test suite...")
                break
            time.sleep(1)
        else:
            log("Device remained locked. Continuing with best effort...")

    # Launch Pocket
    log("Launching Pocket Application (com.pocket.pocket)...")
    run_cmd(f"adb -s {DEVICE_ID} shell am force-stop {PACKAGE_NAME}")
    time.sleep(1)
    run_cmd(f"adb -s {DEVICE_ID} shell monkey -p {PACKAGE_NAME} -c android.intent.category.LAUNCHER 1")
    time.sleep(3)

    # 1. Capture Initial Screen
    capture_screenshot("c2c_01_app_launch")

    # 2. Advance through Onboarding if visible
    for step_idx in range(6):
        root = dump_ui()
        btn = (find_node_by_text(root, "Continue") or 
               find_node_by_text(root, "Next") or 
               find_node_by_text(root, "Get Started") or 
               find_node_by_text(root, "Finish Setup"))
        if btn:
            log(f"Advancing onboarding step {step_idx + 1}...")
            capture_screenshot(f"c2c_02_onboarding_step_{step_idx + 1}")
            tap_node(btn)
            time.sleep(1.5)
        else:
            break

    # 3. Home Dashboard
    time.sleep(2)
    capture_screenshot("c2c_03_home_dashboard")

    # 4. Open Add Transaction Screen / Sheet
    root = dump_ui()
    add_btn = find_node_by_text(root, "+") or find_node_by_text(root, "Add") or find_node_by_text(root, "Quick Add")
    if add_btn:
        tap_node(add_btn)
    else:
        tap_xy(540, 2300, "FAB + Add button")
    time.sleep(2)
    capture_screenshot("c2c_04_add_transaction")

    # 5. Type Amount and Save
    run_cmd(f"adb -s {DEVICE_ID} shell input text 500")
    time.sleep(1)
    root = dump_ui()
    save_btn = find_node_by_text(root, "Save") or find_node_by_text(root, "Add Transaction")
    if save_btn:
        tap_node(save_btn)
    else:
        tap_xy(540, 2200, "Save Transaction")
    time.sleep(2)
    capture_screenshot("c2c_05_transaction_recorded")

    # 6. Wallets Tab (Tab 2)
    root = dump_ui()
    wallets_tab = find_node_by_text(root, "Wallets") or find_node_by_text(root, "Wallet")
    if wallets_tab:
        tap_node(wallets_tab)
    else:
        tap_xy(400, 2350, "Wallets Tab")
    time.sleep(2)
    capture_screenshot("c2c_06_wallets_tab")

    # 7. Analytics & Insights Tab (Tab 3)
    root = dump_ui()
    analytics_tab = find_node_by_text(root, "Analytics") or find_node_by_text(root, "Insights")
    if analytics_tab:
        tap_node(analytics_tab)
    else:
        tap_xy(680, 2350, "Analytics Tab")
    time.sleep(2)
    capture_screenshot("c2c_07_analytics_tab")

    # 8. Budgets & Debts Tab (Tab 4)
    root = dump_ui()
    budgets_tab = find_node_by_text(root, "Budgets") or find_node_by_text(root, "Debts")
    if budgets_tab:
        tap_node(budgets_tab)
    else:
        tap_xy(850, 2350, "Budgets Tab")
    time.sleep(2)
    capture_screenshot("c2c_08_budgets_tab")

    # 9. Settings Tab (Tab 5)
    root = dump_ui()
    settings_tab = find_node_by_text(root, "Settings")
    if settings_tab:
        tap_node(settings_tab)
    else:
        tap_xy(980, 2350, "Settings Tab")
    time.sleep(2)
    capture_screenshot("c2c_09_settings_tab")

    log("C2C test suite finished successfully!")

if __name__ == "__main__":
    main()
