"""
NetScope SQLite Database Manager
Handles persistent storage of application metadata, traffic logs,
hourly/daily aggregations, active connections snapshot, and user settings.
"""

import io
import os
import csv
import sys
import sqlite3
import datetime
import threading
from typing import Dict, List, Any, Optional, Tuple


def get_default_db_path() -> str:
    if "NETSCOPE_DB_PATH" in os.environ:
        return os.environ["NETSCOPE_DB_PATH"]
    if getattr(sys, "frozen", False):
        local_app_data = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")
        return os.path.join(local_app_data, "NetScope", "database", "netscope.db")
    dev_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "database", "netscope.db")
    try:
        os.makedirs(os.path.dirname(dev_path), exist_ok=True)
        return dev_path
    except Exception:
        local_app_data = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")
        return os.path.join(local_app_data, "NetScope", "database", "netscope.db")


class DatabaseManager:
    _instance = None
    _lock = threading.Lock()

    def __init__(self, db_path: Optional[str] = None):
        self.db_path = db_path or get_default_db_path()
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        self._init_db()

    @staticmethod
    def _now_str() -> str:
        return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, timeout=30.0)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("PRAGMA synchronous=NORMAL;")
        conn.execute("PRAGMA foreign_keys=ON;")
        return conn

    def _init_db(self):
        with self._get_connection() as conn:
            conn.executescript("""
                CREATE TABLE IF NOT EXISTS applications (
                    app_id TEXT PRIMARY KEY,
                    executable_path TEXT,
                    process_name TEXT NOT NULL,
                    display_name TEXT NOT NULL,
                    category TEXT NOT NULL DEFAULT 'app',
                    icon_path TEXT,
                    first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );

                CREATE TABLE IF NOT EXISTS traffic_records (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    app_id TEXT NOT NULL,
                    bytes_received INTEGER NOT NULL,
                    bytes_sent INTEGER NOT NULL,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (app_id) REFERENCES applications (app_id) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS hourly_rollups (
                    app_id TEXT NOT NULL,
                    hour_timestamp TEXT NOT NULL,
                    bytes_received INTEGER NOT NULL DEFAULT 0,
                    bytes_sent INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (app_id, hour_timestamp),
                    FOREIGN KEY (app_id) REFERENCES applications (app_id) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS daily_rollups (
                    app_id TEXT NOT NULL,
                    date TEXT NOT NULL,
                    bytes_received INTEGER NOT NULL DEFAULT 0,
                    bytes_sent INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (app_id, date),
                    FOREIGN KEY (app_id) REFERENCES applications (app_id) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS app_settings (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS active_connections (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    app_id TEXT NOT NULL,
                    local_address TEXT,
                    local_port INTEGER,
                    remote_address TEXT,
                    remote_port INTEGER,
                    protocol TEXT,
                    state TEXT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );

                CREATE INDEX IF NOT EXISTS idx_traffic_app_time ON traffic_records(app_id, timestamp);
                CREATE INDEX IF NOT EXISTS idx_traffic_timestamp ON traffic_records(timestamp);
                CREATE INDEX IF NOT EXISTS idx_hourly_timestamp ON hourly_rollups(hour_timestamp);
                CREATE INDEX IF NOT EXISTS idx_daily_date ON daily_rollups(date);
                CREATE INDEX IF NOT EXISTS idx_conn_app ON active_connections(app_id);
            """)

            defaults = {
                "start_with_windows": "true",
                "run_in_background": "true",
                "launch_minimized": "false",
                "theme_mode": "dark",
                "language": "en",
                "usage_notifications": "true",
                "daily_quota_mb": "0",
                "monthly_quota_mb": "0",
                "alert_on_new_app": "false",
                "monitoring_enabled": "true",
            }
            for k, v in defaults.items():
                conn.execute("INSERT OR IGNORE INTO app_settings (key, value) VALUES (?, ?);", (k, v))
            conn.commit()

    def upsert_application(
        self,
        app_id: str,
        executable_path: str,
        process_name: str,
        display_name: str,
        category: str = "app",
        icon_path: Optional[str] = None,
    ):
        now_str = self._now_str()
        with self._get_connection() as conn:
            conn.execute("""
                INSERT INTO applications (app_id, executable_path, process_name, display_name, category, icon_path, first_seen, last_seen)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(app_id) DO UPDATE SET
                    executable_path=excluded.executable_path,
                    process_name=excluded.process_name,
                    display_name=excluded.display_name,
                    category=excluded.category,
                    icon_path=coalesce(excluded.icon_path, applications.icon_path),
                    last_seen=excluded.last_seen;
            """, (app_id, executable_path, process_name, display_name, category, icon_path, now_str, now_str))
            conn.commit()

    def has_application(self, app_id: str) -> bool:
        with self._get_connection() as conn:
            row = conn.execute("SELECT 1 FROM applications WHERE app_id = ? LIMIT 1;", (app_id,)).fetchone()
            return row is not None

    def record_traffic_batch(self, entries: List[Tuple[str, int, int, datetime.datetime]]):
        """
        Records a batch of traffic readings and updates rollups in a single transaction.
        entry: (app_id, bytes_in, bytes_out, timestamp)
        """
        if not entries:
            return

        with self._get_connection() as conn:
            cursor = conn.cursor()
            for app_id, bytes_in, bytes_out, dt in entries:
                if bytes_in <= 0 and bytes_out <= 0:
                    continue

                ts_str = dt.strftime("%Y-%m-%d %H:%M:%S")
                hour_str = dt.strftime("%Y-%m-%d %H:00:00")
                date_str = dt.strftime("%Y-%m-%d")

                cursor.execute("""
                    INSERT INTO traffic_records (app_id, bytes_received, bytes_sent, timestamp)
                    VALUES (?, ?, ?, ?);
                """, (app_id, bytes_in, bytes_out, ts_str))

                cursor.execute("""
                    INSERT INTO hourly_rollups (app_id, hour_timestamp, bytes_received, bytes_sent)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(app_id, hour_timestamp) DO UPDATE SET
                        bytes_received = bytes_received + excluded.bytes_received,
                        bytes_sent = bytes_sent + excluded.bytes_sent;
                """, (app_id, hour_str, bytes_in, bytes_out))

                cursor.execute("""
                    INSERT INTO daily_rollups (app_id, date, bytes_received, bytes_sent)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(app_id, date) DO UPDATE SET
                        bytes_received = bytes_received + excluded.bytes_received,
                        bytes_sent = bytes_sent + excluded.bytes_sent;
                """, (app_id, date_str, bytes_in, bytes_out))

                cursor.execute("""
                    UPDATE applications SET last_seen = ? WHERE app_id = ?;
                """, (ts_str, app_id))

            conn.commit()

    def sync_active_connections(self, connections: List[Tuple[str, str, int, str, int, str, str]]):
        """Replaces the active_connections snapshot table with the current socket list."""
        now_str = self._now_str()
        with self._get_connection() as conn:
            conn.execute("DELETE FROM active_connections;")
            if connections:
                conn.executemany("""
                    INSERT INTO active_connections
                        (app_id, local_address, local_port, remote_address, remote_port, protocol, state, timestamp)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?);
                """, [(a, la, lp, ra, rp, proto, st, now_str) for (a, la, lp, ra, rp, proto, st) in connections])
            conn.commit()

    def get_active_connections(self, app_id: Optional[str] = None) -> List[Dict[str, Any]]:
        with self._get_connection() as conn:
            if app_id:
                rows = conn.execute("""
                    SELECT app_id, local_address, local_port, remote_address, remote_port, protocol, state, timestamp
                    FROM active_connections WHERE app_id = ?
                    ORDER BY protocol, remote_address, remote_port;
                """, (app_id,)).fetchall()
            else:
                rows = conn.execute("""
                    SELECT app_id, local_address, local_port, remote_address, remote_port, protocol, state, timestamp
                    FROM active_connections
                    ORDER BY app_id, protocol, remote_address;
                """).fetchall()
            return [dict(r) for r in rows]

    def get_dashboard_summary(self, top_limit: int = 5) -> Dict[str, Any]:
        """Returns metrics for the Dashboard page."""
        today_str = datetime.date.today().strftime("%Y-%m-%d")
        month_str = datetime.date.today().strftime("%Y-%m")
        safe_limit = max(1, min(int(top_limit), 50))

        with self._get_connection() as conn:
            row_today = conn.execute("""
                SELECT coalesce(sum(bytes_received), 0) as rx, coalesce(sum(bytes_sent), 0) as tx
                FROM daily_rollups WHERE date = ?;
            """, (today_str,)).fetchone()
            today_rx = row_today["rx"] if row_today else 0
            today_tx = row_today["tx"] if row_today else 0

            row_month = conn.execute("""
                SELECT coalesce(sum(bytes_received), 0) as rx, coalesce(sum(bytes_sent), 0) as tx
                FROM daily_rollups WHERE date LIKE ?;
            """, (f"{month_str}%",)).fetchone()
            month_rx = row_month["rx"] if row_month else 0
            month_tx = row_month["tx"] if row_month else 0

            top_apps = conn.execute("""
                SELECT a.app_id, a.executable_path, a.display_name, a.process_name, a.category, a.icon_path,
                       a.first_seen, a.last_seen,
                       sum(d.bytes_received) as rx, sum(d.bytes_sent) as tx,
                       (sum(d.bytes_received) + sum(d.bytes_sent)) as total
                FROM daily_rollups d
                JOIN applications a ON a.app_id = d.app_id
                WHERE d.date = ?
                GROUP BY a.app_id
                ORDER BY total DESC
                LIMIT ?;
            """, (today_str, safe_limit)).fetchall()

            hourly_rows = conn.execute("""
                SELECT hour_timestamp, coalesce(sum(bytes_received), 0) as rx, coalesce(sum(bytes_sent), 0) as tx
                FROM hourly_rollups
                WHERE hour_timestamp LIKE ?
                GROUP BY hour_timestamp;
            """, (f"{today_str}%",)).fetchall()
            hourly_map = {r["hour_timestamp"]: (r["rx"], r["tx"]) for r in hourly_rows}

            hourly_points = []
            for h in range(24):
                h_str = f"{today_str} {h:02d}:00:00"
                rx, tx = hourly_map.get(h_str, (0, 0))
                hourly_points.append({
                    "hour": h,
                    "label": f"{h:02d}:00",
                    "rx": rx,
                    "tx": tx,
                })

            return {
                "today_rx": today_rx,
                "today_tx": today_tx,
                "today_total": today_rx + today_tx,
                "month_rx": month_rx,
                "month_tx": month_tx,
                "month_total": month_rx + month_tx,
                "top_apps": [
                    {
                        "app_id": r["app_id"],
                        "executable_path": r["executable_path"],
                        "display_name": r["display_name"],
                        "process_name": r["process_name"],
                        "category": r["category"],
                        "icon_path": r["icon_path"],
                        "first_seen": r["first_seen"],
                        "last_seen": r["last_seen"],
                        "rx": r["rx"],
                        "tx": r["tx"],
                        "total": r["total"],
                    } for r in top_apps
                ],
                "hourly_trend": hourly_points,
            }

    def get_applications(
        self,
        period: str = "today",
        search: str = "",
        sort_by: str = "total",
        category: str = "all",
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        """Returns all applications with aggregated metrics for the chosen period."""
        date_filter, params = self._resolve_period_filter(period, start_date, end_date)
        where_clauses = ["1=1"]
        where_params: List[Any] = []

        if search:
            where_clauses.append("(a.display_name LIKE ? OR a.process_name LIKE ? OR a.app_id LIKE ?)")
            where_params.extend([f"%{search}%", f"%{search}%", f"%{search}%"])

        if category and category != "all":
            where_clauses.append("a.category = ?")
            where_params.append(category)

        order_clause = "ORDER BY total DESC"
        if sort_by == "rx":
            order_clause = "ORDER BY rx DESC"
        elif sort_by == "tx":
            order_clause = "ORDER BY tx DESC"
        elif sort_by == "name":
            order_clause = "ORDER BY a.display_name ASC"

        recent_cutoff = (datetime.datetime.now() - datetime.timedelta(minutes=10)).strftime("%Y-%m-%d %H:%M:%S")
        all_params = params + where_params + [recent_cutoff]

        query = f"""
            SELECT a.app_id, a.executable_path, a.process_name, a.display_name, a.category, a.icon_path,
                   a.first_seen, a.last_seen,
                   coalesce(sum(d.bytes_received), 0) as rx,
                   coalesce(sum(d.bytes_sent), 0) as tx,
                   (coalesce(sum(d.bytes_received), 0) + coalesce(sum(d.bytes_sent), 0)) as total
            FROM applications a
            LEFT JOIN daily_rollups d ON a.app_id = d.app_id {date_filter}
            WHERE {' AND '.join(where_clauses)}
            GROUP BY a.app_id
            HAVING total > 0 OR a.last_seen >= ?
            {order_clause};
        """

        with self._get_connection() as conn:
            rows = conn.execute(query, all_params).fetchall()
            return [
                {
                    "app_id": r["app_id"],
                    "executable_path": r["executable_path"],
                    "process_name": r["process_name"],
                    "display_name": r["display_name"],
                    "category": r["category"],
                    "icon_path": r["icon_path"],
                    "first_seen": r["first_seen"],
                    "last_seen": r["last_seen"],
                    "rx": r["rx"],
                    "tx": r["tx"],
                    "total": r["total"],
                } for r in rows
            ]

    def get_history(self, period: str = "7days", start_date: Optional[str] = None, end_date: Optional[str] = None) -> Dict[str, Any]:
        """Provides historical usage and time-series points for the requested period."""
        date_filter, params, time_points = self._resolve_history_series(period, start_date, end_date)

        with self._get_connection() as conn:
            totals_row = conn.execute(f"""
                SELECT coalesce(sum(bytes_received), 0) as rx, coalesce(sum(bytes_sent), 0) as tx
                FROM daily_rollups d
                WHERE 1=1 {date_filter};
            """, params).fetchone()
            total_rx = totals_row["rx"] if totals_row else 0
            total_tx = totals_row["tx"] if totals_row else 0

            app_rows = conn.execute(f"""
                SELECT a.app_id, a.executable_path, a.process_name, a.display_name, a.category, a.icon_path,
                       a.first_seen, a.last_seen,
                       sum(d.bytes_received) as rx, sum(d.bytes_sent) as tx,
                       (sum(d.bytes_received) + sum(d.bytes_sent)) as total
                FROM daily_rollups d
                JOIN applications a ON a.app_id = d.app_id
                WHERE 1=1 {date_filter}
                GROUP BY a.app_id
                ORDER BY total DESC;
            """, params).fetchall()

            return {
                "period": period,
                "total_rx": total_rx,
                "total_tx": total_tx,
                "total": total_rx + total_tx,
                "chart_data": time_points,
                "applications": [
                    {
                        "app_id": r["app_id"],
                        "executable_path": r["executable_path"],
                        "process_name": r["process_name"],
                        "display_name": r["display_name"],
                        "category": r["category"],
                        "icon_path": r["icon_path"],
                        "first_seen": r["first_seen"],
                        "last_seen": r["last_seen"],
                        "rx": r["rx"],
                        "tx": r["tx"],
                        "total": r["total"],
                    } for r in app_rows
                ],
            }

    def export_usage_csv(
        self,
        period: str = "today",
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        category: str = "all",
    ) -> str:
        """Generates a UTF-8 CSV report of application bandwidth consumption."""
        apps = self.get_applications(period=period, category=category, start_date=start_date, end_date=end_date)
        buf = io.StringIO()
        buf.write("\ufeff")  # UTF-8 BOM for Microsoft Excel Arabic compatibility
        writer = csv.writer(buf)
        writer.writerow([
            "Display Name",
            "Process Name",
            "Category",
            "Download (Bytes)",
            "Upload (Bytes)",
            "Total (Bytes)",
            "Executable Path",
            "First Seen",
            "Last Seen",
        ])
        for a in apps:
            writer.writerow([
                a["display_name"],
                a["process_name"],
                a["category"],
                a["rx"],
                a["tx"],
                a["total"],
                a["executable_path"],
                a["first_seen"],
                a["last_seen"],
            ])
        return buf.getvalue()

    def _resolve_period_filter(
        self,
        period: str,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
    ) -> Tuple[str, List[Any]]:
        today = datetime.date.today()
        if period == "today":
            return "AND d.date = ?", [today.strftime("%Y-%m-%d")]
        elif period == "yesterday":
            yesterday = today - datetime.timedelta(days=1)
            return "AND d.date = ?", [yesterday.strftime("%Y-%m-%d")]
        elif period == "7days":
            start = today - datetime.timedelta(days=6)
            return "AND d.date BETWEEN ? AND ?", [start.strftime("%Y-%m-%d"), today.strftime("%Y-%m-%d")]
        elif period == "week":
            start = today - datetime.timedelta(days=today.weekday())
            return "AND d.date BETWEEN ? AND ?", [start.strftime("%Y-%m-%d"), today.strftime("%Y-%m-%d")]
        elif period == "month":
            start = today.replace(day=1)
            return "AND d.date BETWEEN ? AND ?", [start.strftime("%Y-%m-%d"), today.strftime("%Y-%m-%d")]
        elif period == "last_month":
            first_this_month = today.replace(day=1)
            last_day_last_month = first_this_month - datetime.timedelta(days=1)
            first_day_last_month = last_day_last_month.replace(day=1)
            return "AND d.date BETWEEN ? AND ?", [first_day_last_month.strftime("%Y-%m-%d"), last_day_last_month.strftime("%Y-%m-%d")]
        elif period == "year":
            start = today.replace(month=1, day=1)
            return "AND d.date BETWEEN ? AND ?", [start.strftime("%Y-%m-%d"), today.strftime("%Y-%m-%d")]
        elif period == "custom" and start_date and end_date:
            return "AND d.date BETWEEN ? AND ?", [start_date, end_date]
        return "", []

    def _resolve_history_series(
        self,
        period: str,
        start_date: Optional[str],
        end_date: Optional[str],
    ) -> Tuple[str, List[Any], List[Dict[str, Any]]]:
        today = datetime.date.today()
        chart_points: List[Dict[str, Any]] = []

        with self._get_connection() as conn:
            if period in ("today", "yesterday"):
                target_date = today if period == "today" else (today - datetime.timedelta(days=1))
                date_str = target_date.strftime("%Y-%m-%d")
                rows = conn.execute("""
                    SELECT hour_timestamp, coalesce(sum(bytes_received), 0) as rx, coalesce(sum(bytes_sent), 0) as tx
                    FROM hourly_rollups
                    WHERE hour_timestamp LIKE ?
                    GROUP BY hour_timestamp;
                """, (f"{date_str}%",)).fetchall()
                by_hour = {r["hour_timestamp"]: (r["rx"], r["tx"]) for r in rows}
                for h in range(24):
                    h_str = f"{date_str} {h:02d}:00:00"
                    rx, tx = by_hour.get(h_str, (0, 0))
                    chart_points.append({"label": f"{h:02d}:00", "rx": rx, "tx": tx})
                return "AND d.date = ?", [date_str], chart_points

            if period in ("7days", "week", "month", "last_month", "custom"):
                if period == "7days":
                    start_dt = today - datetime.timedelta(days=6)
                    end_dt = today
                elif period == "week":
                    start_dt = today - datetime.timedelta(days=today.weekday())
                    end_dt = today
                elif period == "month":
                    start_dt = today.replace(day=1)
                    end_dt = today
                elif period == "last_month":
                    first_this_month = today.replace(day=1)
                    end_dt = first_this_month - datetime.timedelta(days=1)
                    start_dt = end_dt.replace(day=1)
                else:
                    try:
                        if not start_date or not end_date:
                            raise ValueError("Missing custom date range")
                        start_dt = datetime.datetime.strptime(start_date, "%Y-%m-%d").date()
                        end_dt = datetime.datetime.strptime(end_date, "%Y-%m-%d").date()
                        if end_dt < start_dt:
                            start_dt, end_dt = end_dt, start_dt
                    except Exception:
                        start_dt = today - datetime.timedelta(days=6)
                        end_dt = today

                s_str = start_dt.strftime("%Y-%m-%d")
                e_str = end_dt.strftime("%Y-%m-%d")
                rows = conn.execute("""
                    SELECT date, coalesce(sum(bytes_received), 0) as rx, coalesce(sum(bytes_sent), 0) as tx
                    FROM daily_rollups
                    WHERE date BETWEEN ? AND ?
                    GROUP BY date;
                """, (s_str, e_str)).fetchall()
                by_date = {r["date"]: (r["rx"], r["tx"]) for r in rows}

                cur = start_dt
                while cur <= end_dt:
                    d_str = cur.strftime("%Y-%m-%d")
                    if period in ("7days", "week"):
                        lbl = cur.strftime("%a %d")
                    elif period in ("month", "last_month"):
                        lbl = str(cur.day)
                    else:
                        lbl = cur.strftime("%m-%d")
                    rx, tx = by_date.get(d_str, (0, 0))
                    chart_points.append({"label": lbl, "date": d_str, "rx": rx, "tx": tx})
                    cur += datetime.timedelta(days=1)

                return "AND d.date BETWEEN ? AND ?", [s_str, e_str], chart_points

            if period == "year":
                year_prefix = f"{today.year}"
                rows = conn.execute("""
                    SELECT substr(date, 1, 7) as ym, coalesce(sum(bytes_received), 0) as rx, coalesce(sum(bytes_sent), 0) as tx
                    FROM daily_rollups
                    WHERE date LIKE ?
                    GROUP BY ym;
                """, (f"{year_prefix}%",)).fetchall()
                by_ym = {r["ym"]: (r["rx"], r["tx"]) for r in rows}
                for m in range(1, 13):
                    ym = f"{today.year}-{m:02d}"
                    m_label = datetime.date(today.year, m, 1).strftime("%b")
                    rx, tx = by_ym.get(ym, (0, 0))
                    chart_points.append({"label": m_label, "rx": rx, "tx": tx})
                return "AND d.date LIKE ?", [f"{year_prefix}%"], chart_points

            start_dt = today - datetime.timedelta(days=6)
            return "AND d.date BETWEEN ? AND ?", [start_dt.strftime("%Y-%m-%d"), today.strftime("%Y-%m-%d")], []

    def get_settings(self) -> Dict[str, str]:
        with self._get_connection() as conn:
            rows = conn.execute("SELECT key, value FROM app_settings;").fetchall()
            return {r["key"]: r["value"] for r in rows}

    def set_setting(self, key: str, value: str):
        with self._get_connection() as conn:
            conn.execute("""
                INSERT INTO app_settings (key, value) VALUES (?, ?)
                ON CONFLICT(key) DO UPDATE SET value=excluded.value;
            """, (key, str(value)))
            conn.commit()

    def clear_history(self):
        """Clears all historical traffic records and rollups while preserving applications and settings."""
        with self._get_connection() as conn:
            conn.execute("DELETE FROM traffic_records;")
            conn.execute("DELETE FROM hourly_rollups;")
            conn.execute("DELETE FROM daily_rollups;")
            conn.execute("DELETE FROM active_connections;")
            conn.execute("VACUUM;")
            conn.commit()

    def get_storage_stats(self) -> Dict[str, Any]:
        """Returns database file size and row statistics."""
        size_bytes = os.path.getsize(self.db_path) if os.path.exists(self.db_path) else 0
        with self._get_connection() as conn:
            app_count = conn.execute("SELECT count(*) as c FROM applications;").fetchone()["c"]
            records_count = conn.execute("SELECT count(*) as c FROM traffic_records;").fetchone()["c"]
            hourly_count = conn.execute("SELECT count(*) as c FROM hourly_rollups;").fetchone()["c"]
            daily_count = conn.execute("SELECT count(*) as c FROM daily_rollups;").fetchone()["c"]

            return {
                "file_path": self.db_path,
                "size_bytes": size_bytes,
                "size_mb": round(size_bytes / (1024 * 1024), 2),
                "applications_count": app_count,
                "traffic_records_count": records_count,
                "hourly_records_count": hourly_count,
                "daily_records_count": daily_count,
            }
