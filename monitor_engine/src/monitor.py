"""
NetScope Real-Time Windows Network Monitor Engine
Combines Windows Native Network Attribution (SRUM / Windows.Networking.Connectivity),
exact-1s physical interface speed telemetry, and live socket telemetry with ZERO simulation.
"""

import os
import sys
import time
import uuid
import ctypes
import hashlib
import asyncio
import logging
import datetime
import threading
from collections import deque
from typing import Dict, List, Any, Optional, Tuple

import psutil
import win32gui
import win32ui
import win32con
import win32api
from PIL import Image

HAS_WINSDK = False
try:
    from winsdk.windows.networking.connectivity import (
        NetworkInformation,
        NetworkUsageStates,
        NetworkConnectivityLevel,
        TriStates,
    )
    HAS_WINSDK = True
except Exception as e:
    logging.warning(f"winsdk connectivity module not available ({e}); falling back to system socket telemetry.")
    NetworkInformation = None
    NetworkUsageStates = None
    NetworkConnectivityLevel = None
    TriStates = None

from .database import DatabaseManager

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("NetScopeMonitor")


class NetworkMonitor:
    def __init__(self, db: Optional[DatabaseManager] = None):
        self.db = db or DatabaseManager()
        self.running = False
        self._thread: Optional[threading.Thread] = None
        self._speed_thread: Optional[threading.Thread] = None
        self._lock = threading.Lock()

        settings = self.db.get_settings()
        self.paused = settings.get("monitoring_enabled", "true").lower() == "false"

        if getattr(sys, "frozen", False):
            local_app_data = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")
            self.icons_dir = os.path.join(local_app_data, "NetScope", "icons")
        else:
            self.icons_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "icons")
        os.makedirs(self.icons_dir, exist_ok=True)

        self.device_map = self._get_drive_device_map()

        # Telemetry state (updated on dedicated exact-1s speed sampler thread)
        self.current_download_speed = 0.0  # bytes/sec
        self.current_upload_speed = 0.0    # bytes/sec
        self.peak_download_speed = 0.0     # bytes/sec
        self.peak_upload_speed = 0.0       # bytes/sec
        self.link_speed_mbps = 0           # Mbps physical adapter link speed
        self.active_profile_name = "Detecting..."

        # App-level live tracking
        self.app_live_metrics: Dict[str, Dict[str, Any]] = {}

        # Per-(profile, app_id) baseline inside fixed monotonic WinSDK window
        self._app_baselines: Dict[Tuple[str, str], Dict[str, int]] = {}
        self._known_app_ids: set = set()
        self._window_start_utc: Optional[datetime.datetime] = None
        self._baseline_initialized = False

        # Live socket tracking
        self._pid_exe_cache: Dict[Tuple[int, float], str] = {}
        self._app_connections: Dict[str, List[Dict[str, Any]]] = {}
        self._last_conn_scan = 0.0

        # Notifications / Alerts
        self._usage_notifications_enabled = True
        self._daily_quota_bytes = 0
        self._monthly_quota_bytes = 0
        self._alert_on_new_app = False
        self._daily_alert_sent_date: Optional[str] = None
        self._monthly_alert_sent_month: Optional[str] = None
        self._last_quota_check = 0.0
        self.recent_alerts: List[Dict[str, Any]] = []
        self.reload_settings()

        # Pending batch for SQLite writes
        self._pending_traffic_batch: List[Tuple[str, int, int, datetime.datetime]] = []
        self._last_db_flush = time.time()

        self._last_nic_io, self.link_speed_mbps = self._read_physical_nic_totals()
        self._last_io_perf = time.perf_counter()

    @staticmethod
    def _is_ignored_adapter(name: str) -> bool:
        low = name.lower()
        return (
            "loopback" in low
            or "pseudo-interface" in low
            or "isatap" in low
            or "teredo" in low
            or "bluetooth" in low
        )

    def _read_physical_nic_totals(self) -> Tuple[Tuple[int, int], int]:
        """Sums bytes_recv/bytes_sent across active non-loopback network adapters."""
        try:
            per_nic = psutil.net_io_counters(pernic=True, nowrap=True)
            if_stats = psutil.net_if_stats()
        except Exception:
            io = psutil.net_io_counters()
            return (io.bytes_recv, io.bytes_sent), 0

        rx_total = 0
        tx_total = 0
        max_link = 0
        found_up = False

        for name, counters in per_nic.items():
            if self._is_ignored_adapter(name):
                continue
            st = if_stats.get(name)
            if st is not None and not st.isup:
                continue
            found_up = True
            rx_total += int(counters.bytes_recv)
            tx_total += int(counters.bytes_sent)
            if st is not None and st.speed > max_link:
                # Ignore virtual 10Gbps/1Gbps VMware adapters when a real Wi-Fi/Ethernet adapter has traffic or link
                if "vmware" not in name.lower() and "virtualbox" not in name.lower():
                    max_link = int(st.speed)

        if not found_up:
            io = psutil.net_io_counters()
            return (int(io.bytes_recv), int(io.bytes_sent)), 0

        return (rx_total, tx_total), max_link

    def _speed_loop(self):
        """Dedicated 0.5s sampler with a 2.0s sliding window for accurate, non-flickering throughput."""
        self._last_nic_io, self.link_speed_mbps = self._read_physical_nic_totals()
        self._last_io_perf = time.perf_counter()
        window = deque(maxlen=4)  # 4 * 0.5s = 2.0s smooth window

        while self.running:
            time.sleep(0.5)
            if not self.running:
                break
            now_perf = time.perf_counter()
            curr_io, link_mbps = self._read_physical_nic_totals()
            dt = max(0.05, now_perf - self._last_io_perf)

            if self.paused:
                window.clear()
                self.current_download_speed = 0.0
                self.current_upload_speed = 0.0
            else:
                rx_diff = max(0, curr_io[0] - self._last_nic_io[0])
                tx_diff = max(0, curr_io[1] - self._last_nic_io[1])
                window.append((dt, rx_diff, tx_diff))

                total_dt = max(0.1, sum(item[0] for item in window))
                total_rx = sum(item[1] for item in window)
                total_tx = sum(item[2] for item in window)

                dl_speed = total_rx / total_dt
                ul_speed = total_tx / total_dt
                self.current_download_speed = dl_speed
                self.current_upload_speed = ul_speed

                # Track peak speed from instantaneous 0.5s or smoothed window
                inst_dl = rx_diff / dt
                inst_ul = tx_diff / dt
                if max(dl_speed, inst_dl) > self.peak_download_speed:
                    self.peak_download_speed = max(dl_speed, inst_dl)
                if max(ul_speed, inst_ul) > self.peak_upload_speed:
                    self.peak_upload_speed = max(ul_speed, inst_ul)
                if link_mbps > 0:
                    self.link_speed_mbps = link_mbps

            self._last_nic_io = curr_io
            self._last_io_perf = now_perf

    def reload_settings(self):
        """Reloads notification and quota settings from database."""
        settings = self.db.get_settings()
        with self._lock:
            self._usage_notifications_enabled = settings.get("usage_notifications", "true").lower() == "true"
            self._alert_on_new_app = settings.get("alert_on_new_app", "false").lower() == "true"
            try:
                daily_mb = float(settings.get("daily_quota_mb", "0") or 0)
            except ValueError:
                daily_mb = 0.0
            try:
                monthly_mb = float(settings.get("monthly_quota_mb", "0") or 0)
            except ValueError:
                monthly_mb = 0.0
            self._daily_quota_bytes = int(max(0.0, daily_mb) * 1024 * 1024)
            self._monthly_quota_bytes = int(max(0.0, monthly_mb) * 1024 * 1024)

    def _push_alert(self, alert_type: str, title: str, message: str):
        alert = {
            "id": str(uuid.uuid4()),
            "type": alert_type,
            "title": title,
            "message": message,
            "timestamp": datetime.datetime.now().isoformat(),
        }
        with self._lock:
            self.recent_alerts.insert(0, alert)
            if len(self.recent_alerts) > 50:
                self.recent_alerts = self.recent_alerts[:50]

    def get_alerts(self) -> List[Dict[str, Any]]:
        with self._lock:
            return list(self.recent_alerts)

    def clear_alerts(self):
        with self._lock:
            self.recent_alerts.clear()

    def _get_drive_device_map(self) -> Dict[str, str]:
        """Maps NT device names (e.g. \\device\\harddiskvolume2) to DOS drive letters (e.g. C:)."""
        mapping = {}
        kernel32 = ctypes.windll.kernel32
        target_buf = ctypes.create_unicode_buffer(512)
        for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
            drive = f"{letter}:"
            res = kernel32.QueryDosDeviceW(drive, target_buf, 512)
            if res > 0:
                mapping[target_buf.value.lower()] = drive
        return mapping

    def resolve_app_path(self, raw_id: str) -> Tuple[str, str, str, str, str]:
        """
        Resolves raw attribution id to:
        (normalized_app_id, executable_path, process_name, display_name, category)
        """
        raw_clean = (raw_id or "").strip()
        if not raw_clean:
            return ("unattributed", "", "Unattributed", "Unattributed System Traffic", "unattributed")

        raw_lower = raw_clean.lower()
        if raw_lower == "system" or raw_lower.startswith("system\\") or raw_lower == "system idle process":
            return ("system", "", "System", "Windows NT Kernel & System", "system")

        resolved_path = raw_clean
        for dev, drive in self.device_map.items():
            if raw_lower.startswith(dev):
                resolved_path = drive + raw_clean[len(dev):]
                break

        process_name = os.path.basename(resolved_path) or raw_clean
        display_name = process_name

        if os.path.exists(resolved_path):
            try:
                lang, codepage = win32api.GetFileVersionInfo(resolved_path, "\\VarFileInfo\\Translation")[0]
                string_path = f"\\StringFileInfo\\{lang:04x}{codepage:04x}\\FileDescription"
                desc = win32api.GetFileVersionInfo(resolved_path, string_path)
                if desc and desc.strip():
                    display_name = desc.strip()
            except Exception:
                base_no_ext = os.path.splitext(process_name)[0]
                display_name = base_no_ext.replace("-", " ").replace("_", " ").title()

        category = "app"
        res_lower = resolved_path.lower()
        if (
            "\\windows\\system32\\" in res_lower
            or "\\windows\\syswow64\\" in res_lower
            or process_name.lower() in ("lsass.exe", "svchost.exe", "services.exe", "csrss.exe", "smss.exe", "wininit.exe", "system")
        ):
            category = "system"

        normalized_id = resolved_path.lower() if os.path.exists(resolved_path) else raw_lower
        return (normalized_id, resolved_path, process_name, display_name, category)

    def extract_app_icon(self, exe_path: str) -> Optional[str]:
        """Extracts 32x32 icon from executable and saves as PNG."""
        if not exe_path or not os.path.exists(exe_path):
            return None

        app_hash = hashlib.md5(exe_path.lower().encode()).hexdigest()
        out_file = os.path.join(self.icons_dir, f"{app_hash}.png")
        if os.path.exists(out_file):
            return out_file

        hdc_screen = 0
        hdc = None
        hdc_mem = None
        hbmp = None
        try:
            large, small = win32gui.ExtractIconEx(exe_path, 0)
            hicon = large[0] if large else (small[0] if small else None)
            if not hicon:
                return None

            hdc_screen = win32gui.GetDC(0)
            hdc = win32ui.CreateDCFromHandle(hdc_screen)
            hbmp = win32ui.CreateBitmap()
            hbmp.CreateCompatibleBitmap(hdc, 32, 32)
            hdc_mem = hdc.CreateCompatibleDC()
            hdc_mem.SelectObject(hbmp)
            win32gui.DrawIconEx(hdc_mem.GetSafeHdc(), 0, 0, hicon, 32, 32, 0, 0, win32con.DI_NORMAL)

            bmpinfo = hbmp.GetInfo()
            bmpstr = hbmp.GetBitmapBits(True)
            img = Image.frombuffer("RGBA", (bmpinfo["bmWidth"], bmpinfo["bmHeight"]), bmpstr, "raw", "BGRA", 0, 1)
            img.save(out_file, "PNG")

            for h in large + small:
                win32gui.DestroyIcon(h)
            return out_file
        except Exception:
            return None
        finally:
            try:
                if hdc_mem:
                    hdc_mem.DeleteDC()
                if hdc:
                    hdc.DeleteDC()
                if hbmp:
                    win32gui.DeleteObject(hbmp.GetHandle())
                if hdc_screen:
                    win32gui.ReleaseDC(0, hdc_screen)
            except Exception:
                pass

    def is_alive(self) -> bool:
        """Returns True if the background monitor thread is active and running."""
        with self._lock:
            return self.running and self._thread is not None and self._thread.is_alive()

    def start(self, respect_saved_pause: bool = False):
        """Starts the background network monitoring and exact-1s speed threads."""
        with self._lock:
            if self.running:
                return
            self.running = True
            if not respect_saved_pause:
                self.paused = False
            self._window_start_utc = None
            self._baseline_initialized = False
            self._app_baselines.clear()
            self._speed_thread = threading.Thread(target=self._speed_loop, daemon=True, name="NetScopeSpeedThread")
            self._speed_thread.start()
            self._thread = threading.Thread(target=self._run_loop, daemon=True, name="NetScopeMonitorThread")
            self._thread.start()
            logger.info("NetScope Monitoring Engine started successfully.")

    def stop(self):
        """Stops the monitoring threads and flushes remaining data."""
        with self._lock:
            self.running = False
        if self._speed_thread and self._speed_thread.is_alive():
            self._speed_thread.join(timeout=2.0)
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=3.0)
        self._flush_batch_to_db()
        logger.info("NetScope Monitoring Engine stopped.")

    def toggle_pause(self) -> bool:
        """Toggles between paused and running states."""
        with self._lock:
            self.paused = not self.paused
            if self.paused:
                self.current_download_speed = 0.0
                self.current_upload_speed = 0.0
                for m in self.app_live_metrics.values():
                    m["rx_speed"] = 0.0
                    m["tx_speed"] = 0.0
                    m["active"] = False
            status = "paused" if self.paused else "resumed"
            logger.info(f"NetScope Monitoring {status}.")
            return not self.paused

    def set_paused(self, paused: bool):
        with self._lock:
            self.paused = paused

    def _run_loop(self):
        """Main asynchronous event loop for sampling per-app attribution."""
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(self._monitor_task())
        finally:
            loop.close()

    async def _monitor_task(self):
        """Core attribution loop running approximately every 1 second."""
        while self.running:
            if not self.paused:
                try:
                    await self._sample_network_activity()
                except Exception as e:
                    logger.error(f"Error sampling network activity: {e}", exc_info=True)
            await asyncio.sleep(1.0)

    def _scan_active_sockets(self):
        """Captures live TCP/UDP sockets mapped to normalized app_ids."""
        app_conns: Dict[str, List[Dict[str, Any]]] = {}
        db_rows: List[Tuple[str, str, int, str, int, str, str]] = []
        seen_pid_cache: Dict[int, str] = {}

        try:
            conns = psutil.net_connections(kind="inet")
        except Exception:
            return

        for c in conns:
            pid = c.pid
            if not pid:
                continue

            if pid in seen_pid_cache:
                app_id = seen_pid_cache[pid]
            else:
                exe = ""
                try:
                    proc = psutil.Process(pid)
                    ctime = proc.create_time()
                    cache_key = (pid, ctime)
                    if cache_key in self._pid_exe_cache:
                        exe = self._pid_exe_cache[cache_key]
                    else:
                        exe = proc.exe() or proc.name()
                        self._pid_exe_cache[cache_key] = exe
                except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                    exe = "System" if pid <= 4 else ""
                if not exe:
                    continue
                app_id, _, _, _, _ = self.resolve_app_path(exe)
                seen_pid_cache[pid] = app_id

            laddr = c.laddr.ip if c.laddr else ""
            lport = c.laddr.port if c.laddr else 0
            raddr = c.raddr.ip if c.raddr else ""
            rport = c.raddr.port if c.raddr else 0
            proto = "TCP" if c.type == 1 else "UDP"
            status = getattr(c, "status", "") or "-"

            entry = {
                "app_id": app_id,
                "local_address": laddr,
                "local_port": lport,
                "remote_address": raddr,
                "remote_port": rport,
                "protocol": proto,
                "state": status,
            }
            app_conns.setdefault(app_id, []).append(entry)
            if raddr or status == "ESTABLISHED":
                db_rows.append((app_id, laddr, lport, raddr, rport, proto, status))

        if len(self._pid_exe_cache) > 1024:
            self._pid_exe_cache.clear()

        with self._lock:
            self._app_connections = app_conns

        try:
            self.db.sync_active_connections(db_rows[:250])
        except Exception as e:
            logger.debug(f"Could not sync active connections snapshot: {e}")

    def get_active_connections(self, app_id: Optional[str] = None) -> List[Dict[str, Any]]:
        with self._lock:
            if app_id:
                return list(self._app_connections.get(app_id, []))
            flat: List[Dict[str, Any]] = []
            for items in self._app_connections.values():
                flat.extend(items)
            return flat

    def _get_active_profiles(self) -> List[Any]:
        """Returns all connected Windows network profiles, starting with the internet profile."""
        profiles = []
        seen_names = set()

        try:
            inet_profile = NetworkInformation.get_internet_connection_profile()
            if inet_profile:
                profiles.append(inet_profile)
                seen_names.add(inet_profile.profile_name or "Primary")
        except Exception as e:
            logger.warning(f"Error checking internet connection profile: {e}")

        try:
            for p in NetworkInformation.get_connection_profiles():
                level = p.get_network_connectivity_level()
                if NetworkConnectivityLevel and level == NetworkConnectivityLevel.NONE:
                    continue
                pname = p.profile_name or "Local Network"
                if pname not in seen_names:
                    profiles.append(p)
                    seen_names.add(pname)
        except Exception:
            pass

        return profiles

    def _check_usage_quotas(self):
        if not self._usage_notifications_enabled:
            return
        if self._daily_quota_bytes <= 0 and self._monthly_quota_bytes <= 0:
            return

        summary = self.db.get_dashboard_summary(top_limit=1)
        today_str = datetime.date.today().strftime("%Y-%m-%d")
        month_str = datetime.date.today().strftime("%Y-%m")

        if self._daily_quota_bytes > 0 and self._daily_alert_sent_date != today_str:
            if summary["today_total"] >= self._daily_quota_bytes:
                self._daily_alert_sent_date = today_str
                self._push_alert(
                    "quota_daily",
                    "Daily Data Quota Reached",
                    f"Today's usage reached {self.format_bytes(summary['today_total'])}.",
                )

        if self._monthly_quota_bytes > 0 and self._monthly_alert_sent_month != month_str:
            if summary["month_total"] >= self._monthly_quota_bytes:
                self._monthly_alert_sent_month = month_str
                self._push_alert(
                    "quota_monthly",
                    "Monthly Data Quota Reached",
                    f"Monthly usage reached {self.format_bytes(summary['month_total'])}.",
                )

    async def _sample_network_activity(self):
        """Samples active sockets and Windows process-level attributed usage."""
        now_time = time.time()
        now_dt = datetime.datetime.now()
        dt = 1.0

        # Periodically capture live socket connections every 3s
        if now_time - self._last_conn_scan >= 3.0:
            self._scan_active_sockets()
            self._last_conn_scan = now_time

        if not HAS_WINSDK or not NetworkInformation:
            self.active_profile_name = "Socket Telemetry"
            return

        profiles = self._get_active_profiles()
        if not profiles:
            self.active_profile_name = "Offline / Disconnected"
            return

        profile_names = [p.profile_name or "Local Network" for p in profiles]
        self.active_profile_name = profile_names[0] if len(profile_names) == 1 else f"{profile_names[0]} (+{len(profile_names) - 1})"

        now_utc = datetime.datetime.now(datetime.timezone.utc)
        if self._window_start_utc is None:
            self._window_start_utc = (now_utc - datetime.timedelta(hours=1)).replace(minute=0, second=0, microsecond=0)

        need_rollover = (now_utc - self._window_start_utc) >= datetime.timedelta(hours=6)

        states = NetworkUsageStates()
        states.roaming = TriStates.DO_NOT_CARE
        states.shared = TriStates.DO_NOT_CARE

        app_deltas: Dict[str, Tuple[int, int]] = {}
        is_initial_pass = not self._baseline_initialized

        for profile in profiles:
            p_key = profile.profile_name or "Local"
            try:
                usage_list = await profile.get_attributed_network_usage_async(self._window_start_utc, now_utc, states)
            except Exception as e:
                logger.warning(f"Failed to query attributed network usage for {p_key}: {e}")
                continue

            for item in usage_list:
                raw_id = item.attribution_id
                curr_rx = int(item.bytes_received)
                curr_tx = int(item.bytes_sent)

                app_id, exe_path, proc_name, display_name, category = self.resolve_app_path(raw_id)

                if app_id not in self._known_app_ids:
                    existed = self.db.has_application(app_id)
                    icon_path = self.extract_app_icon(exe_path)
                    self.db.upsert_application(app_id, exe_path, proc_name, display_name, category, icon_path)
                    self._known_app_ids.add(app_id)
                    if not existed and not is_initial_pass and self._usage_notifications_enabled and self._alert_on_new_app:
                        self._push_alert(
                            "new_app",
                            "New Application Detected",
                            f"{display_name} ({proc_name}) accessed the network.",
                        )

                b_key = (p_key, app_id)
                if b_key not in self._app_baselines:
                    self._app_baselines[b_key] = {"rx": curr_rx, "tx": curr_tx}
                    if is_initial_pass:
                        self.app_live_metrics.setdefault(app_id, {"rx_speed": 0.0, "tx_speed": 0.0, "active": False})
                        continue
                    delta_rx = max(0, curr_rx)
                    delta_tx = max(0, curr_tx)
                else:
                    prev = self._app_baselines[b_key]
                    delta_rx = max(0, curr_rx - prev["rx"])
                    delta_tx = max(0, curr_tx - prev["tx"])
                    if delta_rx > 0 or delta_tx > 0:
                        self._app_baselines[b_key] = {"rx": curr_rx, "tx": curr_tx}

                prev_rx_sum, prev_tx_sum = app_deltas.get(app_id, (0, 0))
                app_deltas[app_id] = (prev_rx_sum + delta_rx, prev_tx_sum + delta_tx)

        self._baseline_initialized = True

        if need_rollover:
            new_start = (now_utc - datetime.timedelta(hours=1)).replace(minute=0, second=0, microsecond=0)
            self._window_start_utc = new_start
            self._app_baselines.clear()
            for profile in profiles:
                p_key = profile.profile_name or "Local"
                try:
                    roll_list = await profile.get_attributed_network_usage_async(new_start, now_utc, states)
                    for item in roll_list:
                        app_id, _, _, _, _ = self.resolve_app_path(item.attribution_id)
                        self._app_baselines[(p_key, app_id)] = {
                            "rx": int(item.bytes_received),
                            "tx": int(item.bytes_sent),
                        }
                except Exception:
                    pass

        for app_id, metrics in self.app_live_metrics.items():
            if app_id not in app_deltas:
                metrics["rx_speed"] = 0.0
                metrics["tx_speed"] = 0.0
                metrics["active"] = False

        for app_id, (d_rx, d_tx) in app_deltas.items():
            is_active = d_rx > 0 or d_tx > 0
            self.app_live_metrics[app_id] = {
                "rx_speed": d_rx / dt,
                "tx_speed": d_tx / dt,
                "active": is_active,
            }
            if is_active:
                self._pending_traffic_batch.append((app_id, d_rx, d_tx, now_dt))

        if (now_time - self._last_db_flush >= 5.0) or len(self._pending_traffic_batch) >= 20:
            self._flush_batch_to_db()
            self._last_db_flush = now_time

        if now_time - self._last_quota_check >= 10.0:
            self._check_usage_quotas()
            self._last_quota_check = now_time

    def _flush_batch_to_db(self):
        """Writes accumulated traffic deltas to SQLite database."""
        if not self._pending_traffic_batch:
            return

        batch_to_write = list(self._pending_traffic_batch)
        self._pending_traffic_batch.clear()

        try:
            self.db.record_traffic_batch(batch_to_write)
        except Exception as e:
            logger.error(f"Failed to write traffic batch to SQLite: {e}")

    def get_live_status(self) -> Dict[str, Any]:
        """Returns real-time telemetry snapshot for UI/IPC clients."""
        with self._lock:
            alerts_count = len(self.recent_alerts)
            latest_alert = self.recent_alerts[0] if self.recent_alerts else None
        return {
            "monitoring_active": self.running and not self.paused,
            "paused": self.paused,
            "profile_name": self.active_profile_name,
            "download_speed": self.current_download_speed,
            "upload_speed": self.current_upload_speed,
            "peak_download_speed": self.peak_download_speed,
            "peak_upload_speed": self.peak_upload_speed,
            "link_speed_mbps": self.link_speed_mbps,
            "download_speed_formatted": self.format_bytes(self.current_download_speed) + "/s",
            "upload_speed_formatted": self.format_bytes(self.current_upload_speed) + "/s",
            "active_apps_count": sum(1 for m in self.app_live_metrics.values() if m.get("active")),
            "total_apps_monitored": len(self._known_app_ids) or len(self._app_baselines),
            "alerts_count": alerts_count,
            "latest_alert": latest_alert,
            "timestamp": datetime.datetime.now().isoformat(),
        }

    @staticmethod
    def format_bytes(b: float) -> str:
        """Helper to format raw bytes into human readable string."""
        if b < 1024:
            return f"{b:.0f} B"
        elif b < 1024 * 1024:
            return f"{b / 1024:.1f} KB"
        elif b < 1024 * 1024 * 1024:
            return f"{b / (1024 * 1024):.2f} MB"
        else:
            return f"{b / (1024 * 1024 * 1024):.2f} GB"
