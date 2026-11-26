"""
NetScope Windows Desktop Application Entry Point
Clean Desktop Client with Edge WebView2 and System Tray support.
Opens directly in full size without intermediate popup windows.
"""

import sys
import os


class DualLogger:
    def __init__(self, log_path=None):
        self.file = None
        if log_path:
            try:
                os.makedirs(os.path.dirname(log_path), exist_ok=True)
                self.file = open(log_path, "a", encoding="utf-8", errors="replace")
            except Exception:
                self.file = None

    def write(self, s):
        if self.file:
            try:
                self.file.write(s)
                self.file.flush()
            except Exception:
                pass

    def flush(self):
        if self.file:
            try:
                self.file.flush()
            except Exception:
                pass

    def isatty(self):
        return False


local_app_data = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")
log_file_path = os.path.join(local_app_data, "NetScope", "logs", "netscope.log")

if sys.stdout is None:
    sys.stdout = DualLogger(log_file_path)
if sys.stderr is None:
    sys.stderr = DualLogger(log_file_path)

import json
import time
import winreg
import argparse
import threading
import subprocess
import urllib.request
import win32gui
import win32con
from PIL import Image, ImageDraw

API_URL = "http://127.0.0.1:58220"
APP_TITLE = "NetScope - Windows Internet Usage Monitor"


def is_service_responding() -> bool:
    try:
        with urllib.request.urlopen(f"{API_URL}/api/status", timeout=0.2) as resp:
            return resp.status == 200
    except Exception:
        return False


def is_windows_service_installed() -> bool:
    try:
        key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SYSTEM\CurrentControlSet\Services\NetScopeService")
        win32_close = winreg.CloseKey(key)
        return True
    except Exception:
        return False


def fetch_settings() -> dict:
    try:
        with urllib.request.urlopen(f"{API_URL}/api/settings", timeout=0.5) as resp:
            if resp.status == 200:
                return json.loads(resp.read().decode("utf-8"))
    except Exception:
        pass
    return {}


def post_api(endpoint: str) -> dict:
    try:
        req = urllib.request.Request(f"{API_URL}{endpoint}", method="POST", data=b"{}")
        req.add_header("Content-Type", "application/json")
        with urllib.request.urlopen(req, timeout=0.8) as resp:
            if resp.status == 200:
                return json.loads(resp.read().decode("utf-8"))
    except Exception:
        pass
    return {}


def ensure_background_service() -> bool:
    """Ensures the 24/7 background monitoring daemon or Windows Service is active."""
    if is_service_responding():
        return True

    if is_windows_service_installed():
        try:
            res = subprocess.run(["sc.exe", "start", "NetScopeService"], capture_output=True, creationflags=0x08000000)
            if res.returncode == 0:
                for _ in range(30):
                    time.sleep(0.05)
                    if is_service_responding():
                        return True
        except Exception:
            pass

    if getattr(sys, "frozen", False):
        exe_dir = os.path.dirname(sys.executable)
        service_exe = os.path.join(exe_dir, "NetScopeService.exe")
        cmd = [service_exe] if os.path.exists(service_exe) else [sys.executable, "--background"]
    else:
        cmd = [sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "service_main.py")]

    DETACHED_FLAGS = 0x00000008 | 0x00000200
    try:
        subprocess.Popen(
            cmd,
            creationflags=DETACHED_FLAGS,
            close_fds=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL,
        )
    except Exception as e:
        print(f"Error launching detached service: {e}")

    for _ in range(100):
        time.sleep(0.05)
        if is_service_responding():
            return True

    try:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from src.service import BackgroundService
        internal_svc = BackgroundService()
        threading.Thread(target=internal_svc.run, daemon=True).start()
        for _ in range(60):
            time.sleep(0.05)
            if is_service_responding():
                return True
    except Exception as e:
        print(f"In-process fallback failed: {e}")

    return False


def find_app_icon() -> str | None:
    icon_candidates = [
        os.path.join(os.path.dirname(sys.executable), "app_icon.ico") if getattr(sys, "frozen", False) else None,
        os.path.join(os.path.dirname(sys.executable), "_internal", "app_icon.ico") if getattr(sys, "frozen", False) else None,
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "app_icon.ico"),
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "_internal", "app_icon.ico"),
    ]
    return next((p for p in icon_candidates if p and os.path.exists(p)), None)


def load_tray_image(icon_path: str | None) -> Image.Image:
    if icon_path and os.path.exists(icon_path):
        try:
            return Image.open(icon_path).convert("RGBA").resize((64, 64))
        except Exception:
            pass
    img = Image.new("RGBA", (64, 64), (10, 14, 26, 255))
    draw = ImageDraw.Draw(img)
    draw.ellipse([8, 8, 56, 56], outline=(0, 229, 255, 255), width=4)
    draw.ellipse([22, 22, 42, 42], fill=(0, 229, 255, 255))
    return img


def main():
    parser = argparse.ArgumentParser(description="NetScope Windows Internet Monitoring Desktop Client")
    parser.add_argument("--background", action="store_true", help="Run in background daemon mode")
    parser.add_argument("--minimized", action="store_true", help="Start minimized in system tray")
    parser.add_argument("--show", action="store_true", help="Force showing main window on launch")
    parser.add_argument("--test", action="store_true", help="Run 5-second test and print collected traffic")
    parser.add_argument("--clear-db", action="store_true", help="Reset and clear database history")
    parser.add_argument("--enable-startup", action="store_true", help="Register NetScope to start automatically on Windows boot")
    parser.add_argument("--disable-startup", action="store_true", help="Remove NetScope from Windows boot startup")
    args = parser.parse_args()

    if args.background or args.test or args.clear_db or args.enable_startup or args.disable_startup:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from src.service import BackgroundService

        service = BackgroundService()
        if args.enable_startup:
            service.db.set_setting("start_with_windows", "true")
            ok = service.configure_startup(True)
            print("NetScope startup enabled successfully." if ok else "Failed to enable NetScope startup.")
            return

        if args.disable_startup:
            service.db.set_setting("start_with_windows", "false")
            ok = service.configure_startup(False)
            print("NetScope startup disabled successfully." if ok else "Failed to disable NetScope startup.")
            return

        if args.clear_db:
            service.db.clear_history()
            print("NetScope history cleared successfully.")
            return

        if args.test:
            print("Running NetScope 5-second real-time network attribution test...")
            service.monitor.start()
            for i in range(5):
                time.sleep(1.0)
                status = service.monitor.get_live_status()
                print(
                    f"[{i+1}/5s] Profile: {status['profile_name']} | "
                    f"Download: {status['download_speed_formatted']} | "
                    f"Upload: {status['upload_speed_formatted']} | "
                    f"Active apps: {status['active_apps_count']}"
                )
            service.monitor.stop()
            print("\nTop detected applications in database:")
            apps = service.db.get_applications("today")
            for a in apps[:10]:
                print(f" - {a['display_name']} ({a['process_name']}) | Download: {a['rx']} B | Upload: {a['tx']} B | Total: {a['total']} B")
            print("\nTest completed successfully.")
            return

        if args.background:
            print("Starting NetScope 24/7 Background Service...")
            service.run()
            return

    # 1. Single-instance restore
    try:
        existing_hwnd = win32gui.FindWindow(None, APP_TITLE)
        if existing_hwnd:
            win32gui.ShowWindow(existing_hwnd, win32con.SW_SHOW)
            win32gui.ShowWindow(existing_hwnd, win32con.SW_RESTORE)
            win32gui.SetForegroundWindow(existing_hwnd)
            sys.exit(0)
    except Exception:
        pass

    # 2. Boot service in parallel with importing webview (no small splash popup)
    service_ready = threading.Event()

    def _boot_service():
        ensure_background_service()
        service_ready.set()

    threading.Thread(target=_boot_service, daemon=True, name="NetScopeServiceBoot").start()

    webview_storage = os.path.join(local_app_data, "NetScope", "webview")
    os.makedirs(webview_storage, exist_ok=True)

    import webview
    webview.settings["OPEN_EXTERNAL_LINKS_IN_BROWSER"] = True
    icon_path = find_app_icon()

    service_ready.wait(timeout=5.0)
    settings = fetch_settings()
    launch_minimized = args.minimized or (
        settings.get("launch_minimized", "false").lower() == "true" and not args.show
    )

    window = webview.create_window(
        title=APP_TITLE,
        url=API_URL,
        width=1280,
        height=820,
        min_size=(960, 640),
        background_color="#0b0f19",
        hidden=launch_minimized,
    )

    force_exit = {"value": False}
    tray_holder = {"icon": None}

    def show_main_window():
        try:
            window.show()
            hwnd = win32gui.FindWindow(None, APP_TITLE)
            if hwnd:
                win32gui.ShowWindow(hwnd, win32con.SW_SHOW)
                win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)
                win32gui.SetForegroundWindow(hwnd)
        except Exception:
            pass

    def toggle_monitoring_from_tray():
        post_api("/api/monitor/toggle")

    def exit_completely():
        force_exit["value"] = True
        latest_settings = fetch_settings()
        run_bg = latest_settings.get("run_in_background", "true").lower() == "true"
        if not run_bg:
            post_api("/api/service/shutdown")
        if tray_holder["icon"] is not None:
            try:
                tray_holder["icon"].stop()
            except Exception:
                pass
        try:
            window.destroy()
        except Exception:
            pass

    def on_closing():
        if force_exit["value"]:
            return True
        latest_settings = fetch_settings()
        run_bg = latest_settings.get("run_in_background", "true").lower() == "true"
        if run_bg:
            window.hide()
            return False
        if tray_holder["icon"] is not None:
            try:
                tray_holder["icon"].stop()
            except Exception:
                pass
        post_api("/api/service/shutdown")
        return True

    window.events.closing += on_closing

    def start_tray():
        try:
            import pystray
            tray_img = load_tray_image(icon_path)
            menu = pystray.Menu(
                pystray.MenuItem("Open NetScope", lambda icon, item: show_main_window(), default=True),
                pystray.MenuItem("Pause / Resume Monitoring", lambda icon, item: toggle_monitoring_from_tray()),
                pystray.Menu.SEPARATOR,
                pystray.MenuItem("Exit", lambda icon, item: exit_completely()),
            )
            tray_icon = pystray.Icon("NetScope", tray_img, "NetScope - Internet Usage Monitor", menu)
            tray_holder["icon"] = tray_icon
            tray_icon.run()
        except Exception as e:
            print(f"System tray unavailable: {e}")

    threading.Thread(target=start_tray, daemon=True, name="NetScopeTrayThread").start()

    webview.start(
        storage_path=webview_storage,
        private_mode=False,
        icon=icon_path if (icon_path and os.path.exists(icon_path)) else None,
    )


if __name__ == "__main__":
    main()
