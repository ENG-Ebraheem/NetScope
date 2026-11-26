# -*- mode: python ; coding: utf-8 -*-
import os

block_cipher = None

installer_dir = os.path.dirname(os.path.abspath(SPEC))
project_dir = os.path.dirname(installer_dir)
zip_data = os.path.join(installer_dir, "netscope_dist.zip")
icon_ico = os.path.join(project_dir, "monitor_engine", "app_icon.ico")

added_datas = [
    (zip_data, "."),
]
if os.path.exists(icon_ico):
    added_datas.append((icon_ico, "."))

a = Analysis(
    [os.path.join(installer_dir, "installer_app.py")],
    pathex=[installer_dir],
    binaries=[],
    datas=added_datas,
    hiddenimports=["tkinter", "tkinter.ttk", "tkinter.filedialog", "tkinter.messagebox", "lzma"],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["numpy", "scipy", "pandas", "matplotlib", "tensorflow", "torch", "cv2"],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name="NetScope Setup",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,  # Clean setup wizard GUI, no command prompt
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=icon_ico if os.path.exists(icon_ico) else None,
)
