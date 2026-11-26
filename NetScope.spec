# -*- mode: python ; coding: utf-8 -*-
import os
import sys
from PyInstaller.utils.hooks import collect_all

block_cipher = None

project_dir = os.path.dirname(os.path.abspath(SPEC))
engine_dir = os.path.join(project_dir, "monitor_engine")
web_dir = os.path.join(project_dir, "app", "build", "web")
icons_dir = os.path.join(engine_dir, "icons")
icon_ico = os.path.join(engine_dir, "app_icon.ico")
os.makedirs(icons_dir, exist_ok=True)

webview_datas, webview_binaries, webview_hidden = collect_all("webview")
pythonnet_datas, pythonnet_binaries, pythonnet_hidden = collect_all("pythonnet")
clr_loader_datas, clr_loader_binaries, clr_loader_hidden = collect_all("clr_loader")
pystray_datas, pystray_binaries, pystray_hidden = collect_all("pystray")

# Only include slim web assets in GUI; service serves web from _internal/web
shared_datas = [
    (web_dir, "web"),
    (icons_dir, "icons"),
    (icon_ico, "."),
]

gui_datas = shared_datas + webview_datas + pythonnet_datas + clr_loader_datas + pystray_datas
gui_binaries = webview_binaries + pythonnet_binaries + clr_loader_binaries + pystray_binaries

srv_hidden = [
    "uvicorn",
    "uvicorn.logging",
    "uvicorn.loops",
    "uvicorn.loops.auto",
    "uvicorn.protocols",
    "uvicorn.protocols.http",
    "uvicorn.protocols.http.auto",
    "uvicorn.protocols.http.h11_impl",
    "uvicorn.protocols.websockets",
    "uvicorn.protocols.websockets.auto",
    "uvicorn.protocols.websockets.wsproto_impl",
    "uvicorn.lifespans",
    "uvicorn.lifespans.on",
    "uvicorn.lifespans.off",
    "fastapi",
    "fastapi.staticfiles",
    "starlette",
    "starlette.staticfiles",
    "starlette.responses",
    "starlette.routing",
    "starlette.middleware",
    "starlette.middleware.cors",
    "pydantic",
    "websockets",
    "websockets.legacy",
    "websockets.legacy.server",
    "winsdk",
    "winsdk.windows.networking.connectivity",
    "win32gui",
    "win32ui",
    "win32con",
    "win32api",
    "win32pipe",
    "win32file",
    "win32event",
    "winerror",
    "winreg",
    "win32service",
    "win32serviceutil",
    "servicemanager",
    "psutil",
    "PIL",
    "PIL.Image",
    "PIL.ImageDraw",
]

gui_hidden = list(set(srv_hidden + [
    "clr",
    "pythonnet",
    "clr_loader",
    "pystray",
    "pystray._win32",
    "webview",
    "webview.platforms",
    "webview.platforms.winforms",
    "webview.platforms.edgechromium",
] + webview_hidden + pythonnet_hidden + clr_loader_hidden + pystray_hidden))

site_packages = os.path.join(sys.prefix, "Lib", "site-packages")
win32_dir = os.path.join(site_packages, "win32")
win32_lib_dir = os.path.join(win32_dir, "lib")
search_paths = [engine_dir, project_dir, win32_dir, win32_lib_dir]

common_excludes = [
    "cryptography",
    "watchfiles",
    "yaml",
    "tkinter",
    "matplotlib",
    "numpy",
    "pandas",
    "scipy",
    "tensorflow",
    "torch",
    "cv2",
    "PIL.AvifImagePlugin",
    "PIL.WebPImagePlugin",
    "PIL.TiffImagePlugin",
    "PIL.Jpeg2KImagePlugin",
    "PIL.ImageCms",
    "PIL.ImageTk",
]

srv_excludes = common_excludes + [
    "webview",
    "pythonnet",
    "clr_loader",
    "clr",
    "pystray",
]

UNNEEDED_PIL_BINS = ("_avif", "_webp", "_imagingcms", "_imagingft", "_imagingmath", "_imagingmorph")

def filter_binaries(bins):
    return [b for b in bins if not any(tok in b[0].lower() for tok in UNNEEDED_PIL_BINS)]


# 1. NetScope GUI Application Analysis
a_gui = Analysis(
    [os.path.join(engine_dir, "main.py")],
    pathex=search_paths,
    binaries=gui_binaries,
    datas=gui_datas,
    hiddenimports=gui_hidden,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=common_excludes,
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)
a_gui.binaries = filter_binaries(a_gui.binaries)

# 2. NetScopeService Background Daemon Analysis (without WebView/CLR/Pystray)
a_srv = Analysis(
    [os.path.join(engine_dir, "service_main.py")],
    pathex=search_paths,
    binaries=[],
    datas=shared_datas,
    hiddenimports=srv_hidden,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=srv_excludes,
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)
a_srv.binaries = filter_binaries(a_srv.binaries)

pyz_gui = PYZ(a_gui.pure, a_gui.zipped_data, cipher=block_cipher)
exe_gui = EXE(
    pyz_gui,
    a_gui.scripts,
    [],
    exclude_binaries=True,
    name="NetScope",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=icon_ico if os.path.exists(icon_ico) else None,
)

pyz_srv = PYZ(a_srv.pure, a_srv.zipped_data, cipher=block_cipher)
exe_srv = EXE(
    pyz_srv,
    a_srv.scripts,
    [],
    exclude_binaries=True,
    name="NetScopeService",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=icon_ico if os.path.exists(icon_ico) else None,
)

coll = COLLECT(
    exe_gui,
    a_gui.binaries,
    a_gui.zipfiles,
    a_gui.datas,
    exe_srv,
    a_srv.binaries,
    a_srv.zipfiles,
    a_srv.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name="NetScope",
)
