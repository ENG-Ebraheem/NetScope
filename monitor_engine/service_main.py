"""
NetScope Windows Background Monitoring Service (Daemon & Windows Service)
Runs 24/7 in the background independently of the GUI.
Supports:
1. Windows Service (services.msc) under 'NetScopeService'
2. Standalone background daemon (via --background or direct execution)
"""

import sys
import os

# PyInstaller Windows GUI mode redirection
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
log_file_path = os.path.join(local_app_data, "NetScope", "logs", "service.log")

if sys.stdout is None:
    sys.stdout = DualLogger(log_file_path)
if sys.stderr is None:
    sys.stderr = DualLogger(log_file_path)

import logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.FileHandler(log_file_path, encoding="utf-8", errors="replace")] if log_file_path else []
)

# Setup sys.path for internal modules and win32
base_dir = os.path.dirname(os.path.abspath(__file__))
if base_dir not in sys.path:
    sys.path.insert(0, base_dir)

if getattr(sys, "frozen", False):
    exe_dir = os.path.dirname(sys.executable)
    for sub in ["_internal", os.path.join("_internal", "win32"), os.path.join("_internal", "win32", "lib")]:
        p = os.path.join(exe_dir, sub)
        if os.path.exists(p) and p not in sys.path:
            sys.path.insert(0, p)

import threading

HAS_WIN32_SERVICE = False
try:
    import win32service
    import win32serviceutil
    import win32event
    HAS_WIN32_SERVICE = True
except Exception as e:
    logging.info(f"pywin32 service framework not available: {e}; running in standalone daemon mode.")

from src.service import BackgroundService

if HAS_WIN32_SERVICE:
    class NetScopeWindowsService(win32serviceutil.ServiceFramework):
        _svc_name_ = "NetScopeService"
        _svc_display_name_ = "NetScope Internet Usage Monitor Service"
        _svc_description_ = "Monitors and attributes 24/7 internet and network bandwidth consumption on Windows with zero simulation."

        def __init__(self, args):
            win32serviceutil.ServiceFramework.__init__(self, args)
            self.hWaitStop = win32event.CreateEvent(None, 0, 0, None)
            self.service = None

        def SvcStop(self):
            self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
            if self.service:
                self.service.stop()
            win32event.SetEvent(self.hWaitStop)

        def SvcDoRun(self):
            self.ReportServiceStatus(win32service.SERVICE_RUNNING)
            self.service = BackgroundService()
            threading.Thread(target=self.service.run, daemon=True, name="NetScopeSvcRunThread").start()
            win32event.WaitForSingleObject(self.hWaitStop, win32event.INFINITE)

def main():
    if HAS_WIN32_SERVICE:
        # 1. Handle command-line service arguments: install, remove, start, stop, restart
        if len(sys.argv) > 1 and sys.argv[1].lower() in ("install", "remove", "start", "stop", "restart", "status"):
            win32serviceutil.HandleCommandLine(NetScopeWindowsService)
            return

        # 2. Check if started by Windows Service Control Manager (services.msc)
        try:
            import servicemanager
            servicemanager.Initialize()
            servicemanager.PrepareToHostSingle(NetScopeWindowsService)
            servicemanager.StartServiceCtrlDispatcher()
            return
        except Exception:
            # Not invoked by SCM: proceed to run as standalone background daemon
            pass

    # 3. Standalone 24/7 background daemon mode
    service = BackgroundService()
    settings = service.db.get_settings()
    if settings.get("start_with_windows", "true").lower() == "true":
        threading.Thread(target=service.configure_startup, args=(True,), daemon=True).start()
    service.run()

if __name__ == "__main__":
    main()
