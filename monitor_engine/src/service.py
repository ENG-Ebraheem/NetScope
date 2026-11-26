"""
NetScope Windows Background Service & Startup Management
Manages continuous background execution, Windows startup registry persistence,
single-instance mutex locking, and system shutdown signals.
"""

import os
import sys
import time
import winreg
import logging
import subprocess
import win32event
import win32api
import winerror

from .monitor import NetworkMonitor
from .ipc_server import IPCServer
from .database import DatabaseManager

logger = logging.getLogger("NetScopeService")

MUTEX_NAME = "Global\\NetScopeMonitorServiceMutex"
STARTUP_REG_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
APP_NAME = "NetScopeMonitor"


class BackgroundService:
    def __init__(self, db_path: str = None):
        self.db = DatabaseManager(db_path)
        self.monitor = NetworkMonitor(self.db)
        self.ipc = IPCServer(self.monitor, service=self)
        self._mutex = None
        self._running = False

    def acquire_single_instance(self) -> bool:
        """Acquires a named Windows Mutex to ensure only one monitor instance runs."""
        try:
            self._mutex = win32event.CreateMutex(None, False, MUTEX_NAME)
            if win32api.GetLastError() == winerror.ERROR_ALREADY_EXISTS:
                logger.warning("Another instance of NetScope Monitor Service is already running.")
                return False
            return True
        except Exception as e:
            logger.error(f"Failed to acquire mutex: {e}")
            return True

    def get_startup_command(self, target_path: str = None) -> tuple[str, str]:
        """Resolves executable path and arguments for Windows boot startup."""
        if target_path:
            exe = os.path.abspath(target_path)
        elif getattr(sys, "frozen", False):
            exe_dir = os.path.dirname(sys.executable)
            svc_exe = os.path.join(exe_dir, "NetScopeService.exe")
            exe = svc_exe if os.path.exists(svc_exe) else sys.executable
        else:
            engine_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            svc_script = os.path.join(engine_dir, "service_main.py")
            exe = svc_script if os.path.exists(svc_script) else os.path.abspath(sys.argv[0])

        if exe.lower().endswith(".py"):
            return sys.executable, f'"{exe}"'
        if os.path.basename(exe).lower() == "netscopeservice.exe":
            return exe, ""
        return exe, "--background"

    def configure_startup(self, enable: bool = True, target_path: str = None) -> bool:
        """Configures or removes the Windows CurrentVersion\\Run startup registry entry and Startup folder shortcut."""
        target_exe, target_args = self.get_startup_command(target_path)
        reg_cmd = f'"{target_exe}" {target_args}'.strip() if target_args else f'"{target_exe}"'
        success = True

        # 1. Windows Registry HKCU\...\Run
        try:
            key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, STARTUP_REG_KEY, 0, winreg.KEY_SET_VALUE)
            if enable:
                winreg.SetValueEx(key, APP_NAME, 0, winreg.REG_SZ, reg_cmd)
                logger.info(f"Enabled Windows startup in registry: {reg_cmd}")
            else:
                try:
                    winreg.DeleteValue(key, APP_NAME)
                    logger.info("Removed Windows startup entry from registry.")
                except FileNotFoundError:
                    pass
            winreg.CloseKey(key)
        except Exception as e:
            logger.error(f"Failed to configure startup registry: {e}")
            success = False

        # 2. Windows Startup Folder (%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup)
        try:
            startup_dir = os.path.join(os.environ.get("APPDATA", ""), r"Microsoft\Windows\Start Menu\Programs\Startup")
            if os.path.exists(startup_dir):
                shortcut_file = os.path.join(startup_dir, "NetScopeService.lnk")
                if enable:
                    # Skip slow PowerShell invocation if shortcut already exists
                    if not os.path.exists(shortcut_file):
                        ps_cmd = (
                            "$WshShell = New-Object -ComObject WScript.Shell; "
                            f"$Shortcut = $WshShell.CreateShortcut('{shortcut_file}'); "
                            f"$Shortcut.TargetPath = '{target_exe}'; "
                            f"$Shortcut.Arguments = '{target_args}'; "
                            f"$Shortcut.WorkingDirectory = '{os.path.dirname(target_exe)}'; "
                            "$Shortcut.Save()"
                        )
                        subprocess.run(["powershell", "-NoProfile", "-Command", ps_cmd], check=False, creationflags=0x08000000)
                        logger.info(f"Created startup shortcut in: {shortcut_file}")
                else:
                    if os.path.exists(shortcut_file):
                        os.remove(shortcut_file)
                        logger.info("Removed startup shortcut.")
        except Exception as e:
            logger.warning(f"Could not configure startup folder shortcut: {e}")

        return success

    def is_startup_enabled(self) -> bool:
        """Checks if startup entry exists in Windows registry."""
        try:
            key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, STARTUP_REG_KEY, 0, winreg.KEY_READ)
            val, _ = winreg.QueryValueEx(key, APP_NAME)
            winreg.CloseKey(key)
            return bool(val)
        except FileNotFoundError:
            return False
        except Exception:
            return False

    def is_server_active(self) -> bool:
        """Checks if NetScope IPC REST server is responding."""
        try:
            import urllib.request
            with urllib.request.urlopen("http://127.0.0.1:58220/api/status", timeout=0.3) as resp:
                return resp.status == 200
        except Exception:
            return False

    def start_service(self) -> bool:
        """Starts monitor and IPC server without blocking main thread."""
        if self.is_server_active():
            logger.info("NetScope IPC server is already active and responding.")
            return False

        if not self.acquire_single_instance():
            logger.warning("Mutex detected; verifying if server is actually active...")
            if self.is_server_active():
                return False
            logger.info("Server not responding, proceeding to start service.")

        self._running = True
        logger.info("Starting NetScope Monitoring Engine and IPC Server in background...")
        self.monitor.start(respect_saved_pause=True)
        self.ipc.start()
        return True

    def run(self):
        """Starts monitoring and IPC server and keeps process running continuously."""
        if not self.acquire_single_instance():
            logger.info("Exiting because monitor service is already active.")
            return

        self._running = True
        logger.info("Starting NetScope Monitoring Engine and IPC Server...")
        self.monitor.start(respect_saved_pause=True)
        self.ipc.start()

        def on_exit(signal_type):
            logger.info(f"Received system exit signal {signal_type}, shutting down cleanly...")
            self.stop()
            return True

        win32api.SetConsoleCtrlHandler(on_exit, True)

        try:
            while self._running:
                time.sleep(1.0)
                if self.monitor and not self.monitor.is_alive():
                    if not self.monitor.paused and self._running:
                        logger.warning("Monitoring thread died unexpectedly; reviving...")
                        self.monitor.running = False
                        self.monitor.start(respect_saved_pause=True)
        except (KeyboardInterrupt, SystemExit):
            self.stop()
        except Exception as e:
            logger.error(f"Error in background service loop: {e}", exc_info=True)
            self.stop()

    def stop(self):
        """Clean shutdown."""
        self._running = False
        self.ipc.stop()
        self.monitor.stop()
        if self._mutex:
            win32api.CloseHandle(self._mutex)
            self._mutex = None
        logger.info("NetScope Background Service stopped cleanly.")
