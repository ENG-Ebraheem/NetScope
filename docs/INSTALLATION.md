# NetScope Installation Guide

This guide details how to install, configure, and manage NetScope on Windows 10 and Windows 11.

---

## System Requirements

- **Operating System**: Windows 10 (Build 1809 or higher) or Windows 11 (64-bit).
- **Architecture**: x64 (64-bit).
- **RAM**: 200 MB available memory.
- **Disk Space**: 150 MB free disk space.
- **Network Interfaces**: Ethernet, Wi-Fi, or Cellular (LTE/5G) adapters.

---

## Method 1: Installing via `NetScope Setup.exe` (Recommended)

1. Download `NetScope Setup.exe` from the [GitHub Releases](https://github.com/ENG-Ebraheem/NetScope/releases) page (or locate it in the project root after building).
2. The Setup Wizard will guide you through:
   - Selecting the destination directory (`%LOCALAPPDATA%\Programs\NetScope` by default, or any custom directory).
   - Creating a Desktop shortcut.
   - Creating a Start Menu shortcut in `Start Menu\Programs\NetScope\`.
   - Enabling automatic Windows startup (`NetScopeService.exe`).
3. Click **Install Now**.
4. Once complete, NetScope will launch automatically if selected.

Silent installation is also supported:
```cmd
"NetScope Setup.exe" /S --dir="C:\Tools\NetScope"
```

---

## Method 2: Building & Running Portable Release (`NetScope.exe`)

1. From the repository root, run `python -m PyInstaller NetScope.spec --noconfirm`.
2. Open `dist\NetScope\`.
3. Double-click `NetScope.exe`.
4. NetScope launches immediately while `NetScopeService.exe` monitors traffic in the background.

---

## Configuring Automatic Windows Startup

You can toggle automatic startup at any time:
1. Open NetScope.
2. Navigate to **Settings** in the sidebar.
3. Under **Windows Integration**, toggle **Start with Windows**.

Or via command line:
```cmd
NetScope.exe --enable-startup
NetScope.exe --disable-startup
```

---

## Optional: Registering as a Windows System Service (`services.msc`)

Run `install_service.bat` as Administrator to install `NetScopeService.exe` into Windows Services (`services.msc`). Run `uninstall_service.bat` to remove it.

---

## Uninstallation

To completely uninstall NetScope:
1. Open Windows **Settings** > **Apps** > **Installed apps**.
2. Search for **NetScope** and click **Uninstall**.
3. Or run `uninstall.cmd` from the NetScope installation directory (or Start Menu > **Uninstall NetScope**).
4. All application files, registry startup keys, and shortcuts will be removed.
