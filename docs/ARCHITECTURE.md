# NetScope Architecture & System Design

## 1. System Overview

NetScope delivers real-time network traffic attribution for Windows desktop systems. It provides visibility into both total interface bandwidth consumption and per-process network attribution.

```
+-------------------------------------------------------------------------+
|                         NetScope Architecture                           |
+-------------------------------------------------------------------------+
|                                                                         |
|  +-----------------------+              +----------------------------+  |
|  |   Flutter Desktop UI  |  REST / WS   |  Windows Background Engine |  |
|  | - GlassWire Theme     |<------------>| - Python 3.11 + WinSDK     |  |
|  | - Bilingual (AR / EN) |  :58220      | - Named Pipe IPC           |  |
|  | - Live Charts & Gauges|              | - Mutex Lock & Service     |  |
|  +-----------------------+              +----------------------------+  |
|              ^                                         |                |
|              | Edge WebView2 + System Tray             v                |
|  +-----------------------+              +----------------------------+  |
|  | PyWebView + Pystray   |              | SQLite Database (WAL Mode) |  |
|  +-----------------------+              | - Applications metadata    |  |
|                                         | - Raw traffic logs         |  |
|                                         | - Hourly / Daily Rollups   |  |
|                                         | - Active Sockets Snapshot  |  |
|                                         +----------------------------+  |
|                                                        |                |
|                                                        v                |
|                                         +----------------------------+  |
|                                         | Windows Kernel Subsystems  |  |
|                                         | - NDIS Network Interfaces  |  |
|                                         | - Windows Connectivity API |  |
|                                         | - Active Socket Polling    |  |
|                                         +----------------------------+  |
+-------------------------------------------------------------------------+
```

---

## 2. Windows Network Attribution Strategy

NetScope uses a **hybrid multi-layer attribution engine**:
- **Layer 1: System Network I/O Telemetry (`psutil.net_io_counters`)**: Measures physical interface throughput (bytes sent and received per second).
- **Layer 2: Windows Native Connectivity (`winsdk.windows.networking.connectivity`)**: Queries all connected Windows Network Profiles (`get_connection_profiles` / `get_internet_connection_profile`) and attributed per-app usage over a monotonic session window.
- **Layer 3: Real-time Socket Telemetry (`psutil.net_connections`)**: Maps live TCP/UDP sockets to normalized application IDs to expose active remote endpoints and states.
- **Layer 4: Windows Win32 API Attribution (`win32api`, `win32gui`)**:
  - Queries `QueryDosDeviceW` to map NT volume identifiers (`\device\harddiskvolumeX\...`) to DOS drive letters (`C:\...`).
  - Reads `GetFileVersionInfo` string tables to obtain friendly application names.
  - Uses `ExtractIconEx` to extract 32x32 native application icons, saved as PNGs and cached locally.

---

## 3. High-Performance SQLite Database Design

NetScope persists network metrics using a specialized schema in local time:
- **`applications`**: Stores `app_id`, full path, friendly name, category (`app` vs `system` vs `unattributed`), icon path, first seen, and last seen.
- **`traffic_records`**: Streaming logs of bytes received/sent per interval.
- **`hourly_rollups`**: Aggregated bandwidth usage by app per hour.
- **`daily_rollups`**: Aggregated bandwidth usage by app per day.
- **`active_connections`**: Snapshot of active TCP/UDP sockets per application.
- **`app_settings`**: Key-value application configuration store (startup, tray, quotas, alerts, theme, language).

All operations execute in **WAL (Write-Ahead Logging)** mode with `PRAGMA synchronous = NORMAL`.

---

## 4. Dual-Mode Inter-Process Communication (IPC)

1. **Windows Named Pipe (`\\.\pipe\NetScopePipe`)**: Local JSON command pipeline (`status`, `dashboard`, `applications`, `connections`, `toggle`).
2. **Local HTTP REST & WebSocket Server (`http://127.0.0.1:58220`)**:
   - `GET /api/status`: Real-time system speeds, profile name, active app counts, and alert status.
   - `GET /api/dashboard`: Aggregated daily/monthly metrics and top 10 applications.
   - `GET /api/applications`: Filterable (`period`, `category`, `search`, `start`, `end`) and sortable app list.
   - `GET /api/history`: Timeframe-specific historical rollups.
   - `GET /api/connections`: Live TCP/UDP connections (all or filtered by `app_id`).
   - `GET /api/alerts` & `POST /api/alerts/clear`: Quota and new-app alert feed.
   - `GET /api/export`: Downloadable CSV or JSON usage report.
   - `GET /api/settings` & `POST /api/settings`: Configuration updates (including immediate Windows startup registry sync).
   - `GET /icons/{icon_file}`: Safely scoped process icon image streaming.
   - `WS /ws/live`: Real-time 1 Hz telemetry streaming over WebSocket.
   - `GET /`: Serves the compiled Flutter desktop client.
