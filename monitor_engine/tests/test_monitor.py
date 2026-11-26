"""
Automated Unit and Integration Tests for NetScope Monitoring Engine
Tests:
1. SQLite schema creation and default settings
2. Application upsert, category filtering, and process resolution
3. Traffic batching and hourly/daily rollups
4. Period filtering, custom date ranges, and CSV export
5. Active connections sync and alerts/quota settings
6. Live monitoring engine sampling and IPC FastAPI ASGI endpoints
"""

import os
import sys
import json
import time
import asyncio
import unittest
import datetime
from unittest.mock import MagicMock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.database import DatabaseManager
from src.monitor import NetworkMonitor
from src.ipc_server import IPCServer


def invoke_asgi(app, method: str, path: str, query: str = "", json_body: dict = None):
    """Lightweight dependency-free ASGI test caller for FastAPI routes."""
    body_bytes = json.dumps(json_body).encode("utf-8") if json_body is not None else b""
    headers = [(b"content-type", b"application/json")] if json_body is not None else []
    scope = {
        "type": "http",
        "asgi": {"version": "3.0"},
        "http_version": "1.1",
        "method": method,
        "scheme": "http",
        "path": path,
        "raw_path": path.encode("utf-8"),
        "query_string": query.encode("utf-8"),
        "headers": headers,
        "client": ("127.0.0.1", 50000),
        "server": ("127.0.0.1", 58220),
    }

    sent_status = 500
    sent_headers = {}
    sent_body = []
    req_sent = False

    async def receive():
        nonlocal req_sent
        if not req_sent:
            req_sent = True
            return {"type": "http.request", "body": body_bytes, "more_body": False}
        return {"type": "http.disconnect"}

    async def send(message):
        nonlocal sent_status, sent_headers
        if message["type"] == "http.response.start":
            sent_status = message["status"]
            sent_headers = {k.decode("latin-1").lower(): v.decode("latin-1") for k, v in message.get("headers", [])}
        elif message["type"] == "http.response.body":
            sent_body.append(message.get("body", b""))

    asyncio.run(app(scope, receive, send))
    return sent_status, sent_headers, b"".join(sent_body)


class TestNetScopeEngine(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.test_db_path = os.path.join(os.path.dirname(__file__), "test_netscope.db")
        if os.path.exists(cls.test_db_path):
            os.remove(cls.test_db_path)
        cls.db = DatabaseManager(cls.test_db_path)
        cls.monitor = NetworkMonitor(cls.db)
        cls.mock_service = MagicMock()
        cls.ipc = IPCServer(cls.monitor, service=cls.mock_service)

    @classmethod
    def tearDownClass(cls):
        cls.monitor.stop()
        if os.path.exists(cls.test_db_path):
            try:
                os.remove(cls.test_db_path)
            except Exception:
                pass

    def test_01_database_initialization(self):
        """Test database tables and default settings exist."""
        settings = self.db.get_settings()
        self.assertIn("start_with_windows", settings)
        self.assertIn("daily_quota_mb", settings)
        self.assertIn("alert_on_new_app", settings)
        self.assertEqual(settings["theme_mode"], "dark")
        self.assertEqual(settings["language"], "en")

    def test_02_upsert_and_category_filter(self):
        """Test application upsert and category filtering."""
        self.db.upsert_application(
            app_id="c:\\program files\\chrome\\chrome.exe",
            executable_path="C:\\Program Files\\Chrome\\chrome.exe",
            process_name="chrome.exe",
            display_name="Google Chrome",
            category="app",
        )
        self.db.upsert_application(
            app_id="c:\\windows\\system32\\svchost.exe",
            executable_path="C:\\Windows\\System32\\svchost.exe",
            process_name="svchost.exe",
            display_name="Host Process for Windows Services",
            category="system",
        )
        user_apps = self.db.get_applications("today", category="app")
        sys_apps = self.db.get_applications("today", category="system")
        self.assertTrue(any(a["process_name"] == "chrome.exe" for a in user_apps))
        self.assertFalse(any(a["process_name"] == "svchost.exe" for a in user_apps))
        self.assertTrue(any(a["process_name"] == "svchost.exe" for a in sys_apps))

    def test_03_record_traffic_batch_and_rollups(self):
        """Test recording traffic updates raw records, hourly rollups, and daily rollups."""
        now = datetime.datetime.now()
        batch = [
            ("c:\\program files\\chrome\\chrome.exe", 1048576, 524288, now),
        ]
        self.db.record_traffic_batch(batch)

        summary = self.db.get_dashboard_summary(top_limit=5)
        self.assertGreaterEqual(summary["today_rx"], 1048576)
        self.assertGreaterEqual(summary["today_tx"], 524288)
        self.assertGreaterEqual(summary["today_total"], 1572864)
        self.assertLessEqual(len(summary["top_apps"]), 5)
        self.assertEqual(len(summary["hourly_trend"]), 24)

    def test_04_period_history_and_custom_range(self):
        """Test historical aggregations for 7 days and custom date range."""
        hist = self.db.get_history("7days")
        self.assertIn("total", hist)
        self.assertGreaterEqual(hist["total"], 1572864)
        self.assertEqual(len(hist["chart_data"]), 7)

        today_str = datetime.date.today().strftime("%Y-%m-%d")
        custom_hist = self.db.get_history("custom", start_date=today_str, end_date=today_str)
        self.assertGreaterEqual(custom_hist["total"], 1572864)
        self.assertEqual(len(custom_hist["chart_data"]), 1)

    def test_05_path_resolution(self):
        """Test device path translation to Windows drive letter."""
        raw_id = r"\device\harddiskvolume2\windows\system32\notepad.exe"
        app_id, exe_path, proc_name, display_name, category = self.monitor.resolve_app_path(raw_id)
        self.assertEqual(proc_name.lower(), "notepad.exe")
        self.assertEqual(category, "system")

    def test_06_live_sampling(self):
        """Test live monitoring engine start, sample, and live status."""
        self.monitor.start()
        time.sleep(1.5)
        status = self.monitor.get_live_status()
        self.assertTrue(status["monitoring_active"])
        self.assertIn("download_speed", status)
        self.assertIn("upload_speed", status)
        self.assertIn("peak_download_speed", status)
        self.assertIn("link_speed_mbps", status)
        self.monitor.stop()

    def test_07_active_connections_and_csv_export(self):
        """Test active connections storage and CSV export generation."""
        self.db.sync_active_connections([
            ("c:\\program files\\chrome\\chrome.exe", "192.168.1.10", 54321, "142.250.1.1", 443, "TCP", "ESTABLISHED")
        ])
        conns = self.db.get_active_connections("c:\\program files\\chrome\\chrome.exe")
        self.assertEqual(len(conns), 1)
        self.assertEqual(conns[0]["remote_port"], 443)

        csv_out = self.db.export_usage_csv(period="today")
        self.assertIn("Google Chrome", csv_out)
        self.assertIn("1048576", csv_out)

    def test_08_ipc_endpoints_and_security(self):
        """Test FastAPI ASGI endpoints, startup setting wiring, and icon path safety."""
        status, _, body = invoke_asgi(self.ipc.app, "GET", "/api/dashboard")
        self.assertEqual(status, 200)
        self.assertIn("top_apps", json.loads(body))

        status, _, _ = invoke_asgi(
            self.ipc.app,
            "POST",
            "/api/settings",
            json_body={"key": "start_with_windows", "value": "false"},
        )
        self.assertEqual(status, 200)
        self.mock_service.configure_startup.assert_called_with(False)

        status, hdrs, body = invoke_asgi(self.ipc.app, "GET", "/api/export", query="format=csv&period=today")
        self.assertEqual(status, 200)
        self.assertIn("text/csv", hdrs.get("content-type", ""))
        self.assertIn(b"Google Chrome", body)

        status, _, _ = invoke_asgi(self.ipc.app, "GET", "/icons/../../main.py")
        self.assertEqual(status, 404)


if __name__ == "__main__":
    unittest.main()
