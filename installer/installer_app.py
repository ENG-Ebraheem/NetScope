"""
NetScope Windows Setup Wizard & Silent Installer
Installs NetScope, registers Windows shortcuts, startup entry, and uninstaller.
"""

import os
import sys
import time
import zipfile
import shutil
import winreg
import argparse
import subprocess
import threading
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

APP_NAME = "NetScope"
DISPLAY_NAME = "NetScope Internet Usage Monitor"
VERSION = "1.0.0"
PUBLISHER = "NetScope"

def get_bundled_zip() -> str:
    """Locates the embedded or bundled netscope_dist.zip."""
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        p = os.path.join(sys._MEIPASS, "netscope_dist.zip")
        if os.path.exists(p):
            return p
    local_p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "netscope_dist.zip")
    if os.path.exists(local_p):
        return local_p
    raise FileNotFoundError("Could not find netscope_dist.zip archive.")

def get_default_install_dir() -> str:
    local_app_data = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")
    return os.path.join(local_app_data, "Programs", APP_NAME)

def create_windows_shortcut(target_exe: str, shortcut_path: str, description: str, icon_location: str = None):
    try:
        os.makedirs(os.path.dirname(shortcut_path), exist_ok=True)
        work_dir = os.path.dirname(target_exe)
        icon = icon_location or target_exe
        ps_script = f"""
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut('{shortcut_path}')
        $Shortcut.TargetPath = '{target_exe}'
        $Shortcut.Description = '{description}'
        $Shortcut.WorkingDirectory = '{work_dir}'
        $Shortcut.IconLocation = '{icon}'
        $Shortcut.Save()
        """
        subprocess.run(["powershell", "-NoProfile", "-Command", ps_script], check=False, creationflags=0x08000000)
    except Exception as e:
        print(f"Warning: Failed to create shortcut {shortcut_path}: {e}")

def register_uninstaller(install_dir: str, target_exe: str, uninstall_script: str):
    try:
        reg_path = rf"Software\Microsoft\Windows\CurrentVersion\Uninstall\{APP_NAME}"
        key = winreg.CreateKeyEx(winreg.HKEY_CURRENT_USER, reg_path, 0, winreg.KEY_SET_VALUE)
        winreg.SetValueEx(key, "DisplayName", 0, winreg.REG_SZ, DISPLAY_NAME)
        winreg.SetValueEx(key, "DisplayVersion", 0, winreg.REG_SZ, VERSION)
        winreg.SetValueEx(key, "Publisher", 0, winreg.REG_SZ, PUBLISHER)
        winreg.SetValueEx(key, "DisplayIcon", 0, winreg.REG_SZ, target_exe)
        winreg.SetValueEx(key, "InstallLocation", 0, winreg.REG_SZ, install_dir)
        winreg.SetValueEx(key, "UninstallString", 0, winreg.REG_SZ, f'"{uninstall_script}"')
        winreg.SetValueEx(key, "NoModify", 0, winreg.REG_DWORD, 1)
        winreg.SetValueEx(key, "NoRepair", 0, winreg.REG_DWORD, 1)
        winreg.CloseKey(key)
    except Exception as e:
        print(f"Warning: Failed to register uninstaller: {e}")

def register_startup(target_exe: str, enable: bool = True):
    is_service_exe = os.path.basename(target_exe).lower() == "netscopeservice.exe"
    reg_val = f'"{target_exe}"' if is_service_exe else f'"{target_exe}" --background'

    # 1. Registry HKCU\...\Run
    try:
        run_key = r"Software\Microsoft\Windows\CurrentVersion\Run"
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, run_key, 0, winreg.KEY_SET_VALUE)
        if enable:
            winreg.SetValueEx(key, "NetScopeMonitor", 0, winreg.REG_SZ, reg_val)
        else:
            try:
                winreg.DeleteValue(key, "NetScopeMonitor")
            except FileNotFoundError:
                pass
        winreg.CloseKey(key)
    except Exception as e:
        print(f"Warning: Failed to register startup registry: {e}")

    # 2. Startup folder shortcut
    try:
        startup_dir = os.path.join(os.environ.get("APPDATA", ""), r"Microsoft\Windows\Start Menu\Programs\Startup")
        if os.path.exists(startup_dir):
            lnk_path = os.path.join(startup_dir, "NetScopeService.lnk")
            if enable:
                create_windows_shortcut(target_exe, lnk_path, "NetScope Background Monitor")
            else:
                if os.path.exists(lnk_path):
                    os.remove(lnk_path)
    except Exception as e:
        print(f"Warning: Failed to configure startup folder: {e}")


def _stop_existing_instances():
    """Gracefully and forcefully stops any running NetScope processes before upgrade."""
    try:
        import urllib.request
        req = urllib.request.Request("http://127.0.0.1:58220/api/service/shutdown", method="POST", data=b"{}")
        urllib.request.urlopen(req, timeout=0.6).close()
    except Exception:
        pass
    try:
        subprocess.run(["sc.exe", "stop", "NetScopeService"], capture_output=True, creationflags=0x08000000)
    except Exception:
        pass
    for _ in range(2):
        subprocess.run(
            ["powershell", "-NoProfile", "-Command", "Get-Process NetScope,NetScopeService -ErrorAction SilentlyContinue | Stop-Process -Force"],
            capture_output=True,
            creationflags=0x08000000,
        )
        subprocess.run(["taskkill", "/F", "/T", "/IM", "NetScope.exe"], capture_output=True, creationflags=0x08000000)
        subprocess.run(["taskkill", "/F", "/T", "/IM", "NetScopeService.exe"], capture_output=True, creationflags=0x08000000)
        time.sleep(0.4)


def perform_install(target_dir: str, create_desktop: bool, create_startmenu: bool, enable_startup: bool, progress_callback=None) -> str:
    """Extracts files and sets up shortcuts and registry."""
    _stop_existing_instances()

    # Remove stale _internal, binaries, and old webview cache so upgrades always render fresh UI
    old_internal = os.path.join(target_dir, "_internal")
    if os.path.exists(old_internal):
        shutil.rmtree(old_internal, ignore_errors=True)
    for exe_name in ("NetScope.exe", "NetScopeService.exe"):
        old_exe = os.path.join(target_dir, exe_name)
        if os.path.exists(old_exe):
            try:
                os.remove(old_exe)
            except Exception:
                pass
    local_app_data = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")
    eb_default = os.path.join(local_app_data, "NetScope", "webview", "EBWebView", "Default")
    for cache_dir in ("Service Worker", "Cache", "Code Cache"):
        p = os.path.join(eb_default, cache_dir)
        if os.path.exists(p):
            shutil.rmtree(p, ignore_errors=True)

    zip_path = get_bundled_zip()
    os.makedirs(target_dir, exist_ok=True)

    with zipfile.ZipFile(zip_path, 'r') as zf:
        members = zf.infolist()
        total = len(members)
        for idx, member in enumerate(members):
            last_err = None
            for attempt in range(8):
                try:
                    zf.extract(member, target_dir)
                    last_err = None
                    break
                except Exception as exc:
                    last_err = exc
                    time.sleep(0.3)
            if last_err is not None:
                raise RuntimeError(f"Failed extracting {member.filename}: {last_err}")
            if progress_callback and total > 0:
                progress_callback(int((idx + 1) / total * 80))

    target_exe = os.path.join(target_dir, f"{APP_NAME}.exe")
    target_service = os.path.join(target_dir, "NetScopeService.exe")
    if not os.path.exists(target_service):
        target_service = target_exe

    # Create uninstaller script
    uninstall_cmd = os.path.join(target_dir, "uninstall.cmd")
    with open(uninstall_cmd, "w", encoding="utf-8") as f:
        f.write(f"""@echo off
title NetScope Uninstaller
echo Stopping running NetScope processes and services...
sc.exe stop NetScopeService >nul 2>&1
taskkill /F /IM NetScope.exe >nul 2>&1
taskkill /F /IM NetScopeService.exe >nul 2>&1
sc.exe delete NetScopeService >nul 2>&1
echo Removing registry configuration...
reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" /v "NetScopeMonitor" /f >nul 2>&1
reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{APP_NAME}" /f >nul 2>&1
echo Removing shortcuts...
del "%USERPROFILE%\\Desktop\\{APP_NAME}.lnk" >nul 2>&1
del "%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\NetScopeService.lnk" >nul 2>&1
rmdir /S /Q "%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\{APP_NAME}" >nul 2>&1
echo NetScope has been successfully uninstalled.
timeout /t 2 >nul
(goto) 2>nul & rmdir /S /Q "%~dp0"
""")

    if progress_callback:
        progress_callback(88)

    # Shortcuts
    if create_desktop:
        desktop_dir = os.path.join(os.environ["USERPROFILE"], "Desktop")
        create_windows_shortcut(target_exe, os.path.join(desktop_dir, f"{APP_NAME}.lnk"), DISPLAY_NAME)

    if create_startmenu:
        start_menu_dir = os.path.join(os.environ["APPDATA"], r"Microsoft\Windows\Start Menu\Programs", APP_NAME)
        create_windows_shortcut(target_exe, os.path.join(start_menu_dir, f"{APP_NAME}.lnk"), DISPLAY_NAME)
        create_windows_shortcut(uninstall_cmd, os.path.join(start_menu_dir, "Uninstall NetScope.lnk"), "Uninstall NetScope")

    if progress_callback:
        progress_callback(94)

    # Registry & Startup
    register_uninstaller(target_dir, target_exe, uninstall_cmd)
    register_startup(target_service, enable_startup)

    # Immediately start the background monitoring service detached
    if enable_startup:
        try:
            DETACHED_FLAGS = 0x00000008 | 0x00000200
            subprocess.Popen(
                [target_service],
                creationflags=DETACHED_FLAGS,
                close_fds=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                stdin=subprocess.DEVNULL
            )
        except Exception:
            pass

    if progress_callback:
        progress_callback(100)

    return target_exe

class InstallerGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("NetScope Setup - Windows Internet Usage Monitor")
        self.root.geometry("640x500")
        self.root.resizable(False, False)
        self.root.configure(bg="#0b0f19")

        # Set window icon if available
        try:
            ico_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "app_icon.ico")
            if os.path.exists(ico_path):
                self.root.iconbitmap(ico_path)
        except Exception:
            pass

        self.target_dir_var = tk.StringVar(value=get_default_install_dir())
        self.desktop_var = tk.BooleanVar(value=True)
        self.startmenu_var = tk.BooleanVar(value=True)
        self.startup_var = tk.BooleanVar(value=True)
        self.launch_var = tk.BooleanVar(value=True)

        self._build_ui()

    def _build_ui(self):
        # Header Banner
        header = tk.Frame(self.root, bg="#131b2e", height=90)
        header.pack(fill="x", side="top")
        header.pack_propagate(False)

        title_lbl = tk.Label(header, text="NetScope", font=("Segoe UI", 20, "bold"), fg="#00e5ff", bg="#131b2e")
        title_lbl.pack(anchor="w", padx=28, pady=(16, 2))

        subtitle_lbl = tk.Label(header, text="Windows Internet Usage Monitor v1.0.0 Setup Wizard", font=("Segoe UI", 10), fg="#94a3b8", bg="#131b2e")
        subtitle_lbl.pack(anchor="w", padx=28)

        # Body Container
        body = tk.Frame(self.root, bg="#0b0f19")
        body.pack(fill="both", expand=True, padx=28, pady=20)

        # Destination Label
        tk.Label(body, text="Installation Directory:", font=("Segoe UI", 10, "bold"), fg="#ffffff", bg="#0b0f19").pack(anchor="w")

        dir_frame = tk.Frame(body, bg="#0b0f19")
        dir_frame.pack(fill="x", pady=(6, 18))

        dir_entry = tk.Entry(dir_frame, textvariable=self.target_dir_var, font=("Segoe UI", 10), bg="#1e293b", fg="#ffffff", insertbackground="#00e5ff", relief="flat")
        dir_entry.pack(side="left", fill="x", expand=True, ipady=6, padx=(0, 8))

        browse_btn = tk.Button(dir_frame, text="Browse...", font=("Segoe UI", 9), bg="#334155", fg="#ffffff", activebackground="#475569", activeforeground="#ffffff", relief="flat", padx=12, command=self._browse_dir)
        browse_btn.pack(side="right")

        # Options Box
        tk.Label(body, text="Installation Options:", font=("Segoe UI", 10, "bold"), fg="#ffffff", bg="#0b0f19").pack(anchor="w")

        opts_frame = tk.Frame(body, bg="#131b2e", padx=14, pady=10, relief="flat")
        opts_frame.pack(fill="x", pady=(6, 18))

        def make_cb(parent, text, var):
            cb = tk.Checkbutton(parent, text=text, variable=var, font=("Segoe UI", 9), fg="#e2e8f0", bg="#131b2e", selectcolor="#0b0f19", activebackground="#131b2e", activeforeground="#00e5ff")
            cb.pack(anchor="w", pady=3)
            return cb

        make_cb(opts_frame, "Create a Desktop shortcut", self.desktop_var)
        make_cb(opts_frame, "Create a Start Menu shortcut", self.startmenu_var)
        make_cb(opts_frame, "Start NetScope on Windows boot (Background Monitor)", self.startup_var)
        make_cb(opts_frame, "Launch NetScope after setup completes", self.launch_var)

        # Progress bar
        self.progress = ttk.Progressbar(body, orient="horizontal", mode="determinate")
        self.progress.pack(fill="x", pady=(4, 6))

        self.status_lbl = tk.Label(body, text="Ready to install.", font=("Segoe UI", 9), fg="#94a3b8", bg="#0b0f19")
        self.status_lbl.pack(anchor="w")

        # Footer Actions
        footer = tk.Frame(self.root, bg="#0b0f19", height=60)
        footer.pack(fill="x", side="bottom", padx=28, pady=(0, 20))

        cancel_btn = tk.Button(footer, text="Cancel", font=("Segoe UI", 10), bg="#1e293b", fg="#94a3b8", activebackground="#334155", activeforeground="#ffffff", relief="flat", width=10, command=self.root.quit)
        cancel_btn.pack(side="right", padx=(10, 0))

        self.install_btn = tk.Button(footer, text="Install Now", font=("Segoe UI", 10, "bold"), bg="#00e5ff", fg="#0b0f19", activebackground="#38bdf8", activeforeground="#0b0f19", relief="flat", width=14, command=self._start_install)
        self.install_btn.pack(side="right")

    def _browse_dir(self):
        chosen = filedialog.askdirectory(initialdir=self.target_dir_var.get(), title="Select NetScope Installation Folder")
        if chosen:
            self.target_dir_var.set(os.path.join(chosen, APP_NAME))

    def _start_install(self):
        self.install_btn.config(state="disabled")
        self.status_lbl.config(text="Extracting NetScope files...", fg="#00e5ff")
        threading.Thread(target=self._worker_install, daemon=True).start()

    def _worker_install(self):
        try:
            target_dir = self.target_dir_var.get()
            target_exe = perform_install(
                target_dir=target_dir,
                create_desktop=self.desktop_var.get(),
                create_startmenu=self.startmenu_var.get(),
                enable_startup=self.startup_var.get(),
                progress_callback=self._update_progress
            )
            self.root.after(0, self._on_success, target_exe)
        except Exception as e:
            self.root.after(0, self._on_error, str(e))

    def _update_progress(self, val):
        self.root.after(0, lambda: self.progress.config(value=val))

    def _on_success(self, target_exe):
        self.status_lbl.config(text="NetScope installed successfully!", fg="#10b981")
        if self.launch_var.get() and os.path.exists(target_exe):
            subprocess.Popen([target_exe], creationflags=0x08000000)
        messagebox.showinfo("NetScope Setup", "NetScope has been installed successfully!\n\nYou can access it from your Desktop or Start Menu.")
        self.root.destroy()

    def _on_error(self, err_msg):
        self.status_lbl.config(text=f"Error: {err_msg}", fg="#ef4444")
        messagebox.showerror("Installation Error", f"Installation failed:\n{err_msg}")
        self.install_btn.config(state="normal")

def main():
    is_silent = False
    custom_dir = None

    args = sys.argv[1:]
    idx = 0
    while idx < len(args):
        arg = args[idx]
        if arg.upper() in ("/S", "-S", "--SILENT"):
            is_silent = True
        elif arg in ("--dir", "-d") and idx + 1 < len(args):
            idx += 1
            custom_dir = args[idx]
        elif arg.startswith("--dir="):
            custom_dir = arg.split("=", 1)[1]
        idx += 1

    if is_silent:
        target_dir = custom_dir or get_default_install_dir()
        target_exe = perform_install(
            target_dir=target_dir,
            create_desktop=True,
            create_startmenu=True,
            enable_startup=True
        )
        print(f"NetScope installed silently to {target_dir}")
        return

    root = tk.Tk()
    app = InstallerGUI(root)
    root.mainloop()

if __name__ == "__main__":
    main()
