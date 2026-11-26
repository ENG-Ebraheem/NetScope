# NetScope User Guide

Welcome to **NetScope**, the Windows internet usage monitor. This guide walks you through every screen and feature of the application.

---

## 1. Dashboard

The Dashboard is your primary mission control:
- **Live Speed Gauges**: Real-time meters for current Download and Upload speed (in Mbps/Kbps and B/s).
- **Connection Profile**: Shows the active network adapter name (e.g., your Wi-Fi SSID or Ethernet profile).
- **Today's Usage**: Total, Download, and Upload bytes consumed since midnight.
- **Top 5 Consuming Apps**: Top 5 bandwidth consumers today, showing download/upload split and relative usage bars (click any app to inspect details & active connections).
- **24-Hour Network Activity Chart**: Interactive curve showing hourly traffic distribution with hover tooltips.

---

## 2. Usage & Applications Tab

The Usage & Applications view combines historical trends and per-app inspection:
- **Period Selector**: Choose between `Today`, `Yesterday`, `Last 7 Days`, `This Week`, `This Month`, `Last Month`, `This Year`, or **Custom Range**.
- **Historical Consumption Chart**: Visualizes download/upload trends across the selected timeframe.
- **Category Filter**: Switch between `All`, `Apps` (user-installed software), and `System` (Windows OS services).
- **Search & Sorting**: Filter by application name or process, and sort by Total Usage, Download, Upload, or Alphabetical Name.
- **App Details Dialog**: Click any application row to view:
  - Exact executable location on disk.
  - Download, Upload, and Total breakdown.
  - First detected date and last active timestamp.
  - **Active Network Connections** (live TCP/UDP remote addresses, ports, and states).

---

## 3. Settings Tab

Customize NetScope to fit your workflow:
- **Windows Integration**:
  - *Start with Windows*: Automatically register/unregister NetScope startup in Windows Registry & Startup folder.
  - *Run in Background*: Closing the window minimizes NetScope to the Windows System Tray instead of shutting down monitoring.
  - *Launch Minimized*: Start directly in the System Tray without popping up the main window.
- **Appearance & Language**:
  - *Theme*: Switch between **Dark**, **Light**, and **System** (follows your Windows theme automatically).
  - *Language*: Switch seamlessly between **العربية (Arabic RTL)** and **English (LTR)**.
- **Notifications & Alerts**:
  - *Usage Notifications*: Master switch for in-app alerts.
  - *New Application Alert*: Notify when a previously unseen app accesses the network.
  - *Daily & Monthly Quota Alerts (MB)*: Configure thresholds (`0 = Off`) to be notified when usage crosses your data cap.
- **Storage Management**:
  - View total database size, record count, and tracked applications count.
  - *Clear Usage History*: Reset usage history while keeping application metadata and settings.

---

## 4. About Tab

Shows the NetScope version, color legend guide, privacy guarantee, and live engine status.

---

## 5. Keyboard Shortcuts & System Tray

- Press **Ctrl + R** anywhere in the app to refresh metrics immediately.
- Right-click the **NetScope System Tray icon** near the Windows clock to **Open NetScope**, **Pause / Resume Monitoring**, or **Exit**.
