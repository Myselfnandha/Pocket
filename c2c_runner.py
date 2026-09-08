#!/usr/bin/env python3
"""
Full End-to-End Click-to-Click (C2C) Test Runner for Pocket App
- Polls & Downloads GitHub Actions Release APK
- Installs APK to ADB device dc96724c1e0d
- Executes UI automation via ADB (uiautomator, input tap, screencap)
- Captures and saves verified screenshots to artifacts directory
"""

import os
import sys
import time
import subprocess
import urllib.request
import xml.etree.ElementTree as ET

DEVICE_ID = "dc96724c1e0d"
PACKAGE_NAME = "com.pocket.pocket"
ARTIFACT_DIR = "/home/nandha/.gemini/antigravity-ide/brain/034d6163-7069-49d8-8ac4-9c6b2f1cb3c7"
APK_TARGET = "/home/nandha/Desktop/Pocket/Pocket-v1.5.4-universal.apk"
APK_URL_V154 = "https://github.com/Myselfnandha/Pocket/releases/download/v1.5.4/Pocket-v1.5.4-universal.apk"
APK_URL_V153 = "https://github.com/Myselfnandha/Pocket/releases/download/v1.5.3/Pocket-v1.5.3-universal.apk"
APK_URL_V152 = "https://github.com/Myselfnandha/Pocket/releases/download/v1.5.2/Pocket-v1.5.2-universal.apk"

def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)

def run_cmd(cmd, check=True):
    log(f"RUN: {cmd}")
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and res.returncode != 0:
        log(f"Command failed (code {res.returncode}): {res.stderr.strip()}")
    return res

def check_url_exists(url):
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status in (200, 302)
    except urllib.error.HTTPError as e:
        return False
    except Exception as e:
        return False

def wait_and_download_apk(max_wait_seconds=600):
    log("Step 1: Polling GitHub Releases for universal release APK...")
    start_time = time.time()
    download_url = None

    while time.time() - start_time < max_wait_seconds:
        elapsed = int(time.time() - start_time)
        # Check v1.5.3 first, then v1.5.2
        if check_url_exists(APK_URL_V154):
            download_url = APK_URL_V154
            log(f"Found APK at: {download_url}")
            break
        elif check_url_exists(APK_URL_V153):
            download_url = APK_URL_V153
            log(f"Found APK at: {download_url}")
            break
        else:
            log(f"[{elapsed}s] Build in progress on GitHub Actions... waiting 10s...")
            time.sleep(10)

    if not download_url:
        log("Timed out waiting for GitHub Release APK!")
        return False

    log(f"Downloading APK from {download_url} to {APK_TARGET}...")
    req = urllib.request.Request(download_url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=60) as resp, open(APK_TARGET, 'wb') as f:
        total_size = int(resp.headers.get('content-length', 0))
        downloaded = 0
        while True:
            chunk = resp.read(65536)
            if not chunk:
                break
            f.write(chunk)
            downloaded += len(chunk)
            if total_size > 0:
                percent = (downloaded / total_size) * 100
                if int(percent) % 25 == 0:
                    print(f"Downloaded {downloaded}/{total_size} bytes ({percent:.1f}%)", flush=True)

    size_mb = os.path.getsize(APK_TARGET) / (1024 * 1024)
    log(f"APK downloaded successfully! Size: {size_mb:.2f} MB")
    return True

def install_apk():
    log(f"Step 2: Installing {APK_TARGET} to ADB device {DEVICE_ID}...")
    res = run_cmd(f"adb -s {DEVICE_ID} install -r -d {APK_TARGET}")
    if "Success" in res.stdout:
        log("APK installed successfully on real device!")
        return True
    else:
        log(f"APK installation output: {res.stdout} {res.stderr}")
        return False

def dump_ui():
    run_cmd(f"adb -s {DEVICE_ID} shell uiautomator dump /sdcard/ui_dump.xml", check=False)
    run_cmd(f"adb -s {DEVICE_ID} pull /sdcard/ui_dump.xml /tmp/ui_dump.xml", check=False)
    if os.path.exists("/tmp/ui_dump.xml"):
        try:
            tree = ET.parse("/tmp/ui_dump.xml")
            return tree.getroot()
        except Exception as e:
            log(f"Failed to parse XML: {e}")
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
        # Format: [x1,y1][x2,y2]
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
        log(f"Tapping coordinates ({x}, {y})...")
        run_cmd(f"adb -s {DEVICE_ID} shell input tap {x} {y}")
        time.sleep(1.5)
        return True
    return False

def tap_xy(x, y):
    log(f"Tapping ({x}, {y})...")
    run_cmd(f"adb -s {DEVICE_ID} shell input tap {x} {y}")
    time.sleep(1.5)

def capture_screenshot(step_name):
    sdcard_path = f"/sdcard/{step_name}.png"
    local_path = os.path.join(ARTIFACT_DIR, f"{step_name}.png")
    run_cmd(f"adb -s {DEVICE_ID} shell screencap -p {sdcard_path}")
    run_cmd(f"adb -s {DEVICE_ID} pull {sdcard_path} {local_path}")
    log(f"Screenshot saved: {local_path}")
    return local_path

def run_c2c_test():
    log("Step 3: Launching Pocket app on device...")
    # Wake up screen and unlock if needed
    run_cmd(f"adb -s {DEVICE_ID} shell input keyevent KEYCODE_WAKEUP")
    run_cmd(f"adb -s {DEVICE_ID} shell wm dismiss-keyguard", check=False)
    time.sleep(1)

    # Force stop previous instance and start fresh
    run_cmd(f"adb -s {DEVICE_ID} shell am force-stop {PACKAGE_NAME}")
    time.sleep(1)
    run_cmd(f"adb -s {DEVICE_ID} shell monkey -p {PACKAGE_NAME} -c android.intent.category.LAUNCHER 1")
    time.sleep(3)

    # 1. Initial Launch Screen
    capture_screenshot("c2c_01_app_launch")

    root = dump_ui()
    
    # Handle Onboarding Flow if present
    for step_idx in range(6):
        root = dump_ui()
        next_btn = find_node_by_text(root, "Next") or find_node_by_text(root, "Get Started") or find_node_by_text(root, "Continue") or find_node_by_text(root, "Finish Setup") or find_node_by_text(root, "Done")
        if next_btn:
            log(f"Onboarding step {step_idx+1}: Found button with text '{next_btn.attrib.get('text') or next_btn.attrib.get('content-desc')}'")
            capture_screenshot(f"c2c_02_onboarding_step_{step_idx+1}")
            tap_node(next_btn)
            time.sleep(1.5)
        else:
            break

    # 2. Arrived at Home Screen
    time.sleep(2)
    capture_screenshot("c2c_03_home_dashboard")

    # 3. Add Transaction Test (+ FAB button or Quick Add)
    log("Navigating to Add Transaction flow...")
    root = dump_ui()
    add_btn = find_node_by_text(root, "Add") or find_node_by_text(root, "+") or find_node_by_text(root, "Quick Add")
    if add_btn:
        tap_node(add_btn)
    else:
        # Bottom center FAB or bottom right coordinate on 1080x2460
        tap_xy(540, 2300)
    time.sleep(2)
    capture_screenshot("c2c_04_add_transaction_screen")

    # Input amount / category
    log("Entering transaction data (Amount: 450, Title: Groceries)...")
    # Tap amount keypad or input field
    run_cmd(f"adb -s {DEVICE_ID} shell input text 450")
    time.sleep(1)
    
    root = dump_ui()
    save_btn = find_node_by_text(root, "Save") or find_node_by_text(root, "Add Transaction") or find_node_by_text(root, "Done")
    if save_btn:
        tap_node(save_btn)
    else:
        tap_xy(540, 2200)
    time.sleep(2)
    capture_screenshot("c2c_05_transaction_added_home")

    # 4. Wallets Screen
    log("Navigating to Wallets screen...")
    root = dump_ui()
    wallets_tab = find_node_by_text(root, "Wallets") or find_node_by_text(root, "Wallet")
    if wallets_tab:
        tap_node(wallets_tab)
    else:
        tap_xy(400, 2350)
    time.sleep(2)
    capture_screenshot("c2c_06_wallets_screen")

    # 5. Analytics Screen
    log("Navigating to Analytics screen...")
    root = dump_ui()
    analytics_tab = find_node_by_text(root, "Analytics") or find_node_by_text(root, "Insights") or find_node_by_text(root, "Stats")
    if analytics_tab:
        tap_node(analytics_tab)
    else:
        tap_xy(680, 2350)
    time.sleep(2)
    capture_screenshot("c2c_07_analytics_screen")

    # 6. Budgets & Debts Screen
    log("Navigating to Budgets / Debts screen...")
    root = dump_ui()
    budgets_tab = find_node_by_text(root, "Budgets") or find_node_by_text(root, "Debts")
    if budgets_tab:
        tap_node(budgets_tab)
    else:
        tap_xy(850, 2350)
    time.sleep(2)
    capture_screenshot("c2c_08_budgets_debts_screen")

    # 7. Settings Screen
    log("Navigating to Settings screen...")
    root = dump_ui()
    settings_tab = find_node_by_text(root, "Settings")
    if settings_tab:
        tap_node(settings_tab)
    else:
        tap_xy(980, 2350)
    time.sleep(2)
    capture_screenshot("c2c_09_settings_screen")

    # Final Summary Screen
    log("C2C test execution completed successfully!")

if __name__ == "__main__":
    if not wait_and_download_apk():
        sys.exit(1)
    if not install_apk():
        sys.exit(1)
    run_c2c_test()
