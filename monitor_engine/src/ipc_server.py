"""
NetScope IPC Server
Provides dual-mode inter-process communication:
1. High-speed Windows Named Pipe: \\\\.\\pipe\\NetScopePipe
2. Local REST & WebSocket API: http://127.0.0.1:58220
Allows Flutter frontend to query stats, stream live telemetry, and control settings.
"""

import os
import sys
import json
import time
import asyncio
import logging
import threading
from typing import Dict, Any, List, Optional

import win32pipe
import win32file
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from pydantic import BaseModel
import uvicorn

from .monitor import NetworkMonitor

logger = logging.getLogger("NetScopeIPC")


class SettingUpdateRequest(BaseModel):
    key: str
    value: str


class IPCServer:
    def __init__(self, monitor: NetworkMonitor, service: Any = None):
        self.monitor = monitor
        self.db = monitor.db
        self.service = service
        self.pipe_name = r"\\.\pipe\NetScopePipe"
        self._pipe_thread: Optional[threading.Thread] = None
        self._http_thread: Optional[threading.Thread] = None
        self._running = False
        self._connected_websockets: List[WebSocket] = []
        self._uvicorn_server: Optional[uvicorn.Server] = None

        self.app = FastAPI(title="NetScope IPC Service", version="1.0.0")
        self.app.add_middleware(
            CORSMiddleware,
            allow_origin_regex=r"^https?://(127\.0\.0\.1|localhost)(:\d+)?$",
            allow_credentials=True,
            allow_methods=["GET", "POST", "OPTIONS"],
            allow_headers=["*"],
        )
        self._setup_routes()

    def _setup_routes(self):
        app = self.app

        @app.middleware("http")
        async def disable_static_cache(request, call_next):
            response = await call_next(request)
            if not request.url.path.startswith("/icons/"):
                response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate"
            return response

        @app.get("/api/status")
        async def get_status():
            return self.monitor.get_live_status()

        @app.get("/api/dashboard")
        async def get_dashboard(top_limit: int = 5):
            summary = self.db.get_dashboard_summary(top_limit=top_limit)
            live = self.monitor.get_live_status()
            summary["live"] = live

            for app_item in summary.get("top_apps", []):
                app_id = app_item["app_id"]
                metrics = self.monitor.app_live_metrics.get(app_id, {})
                app_item["rx_speed"] = metrics.get("rx_speed", 0.0)
                app_item["tx_speed"] = metrics.get("tx_speed", 0.0)
                app_item["is_active"] = metrics.get("active", False)
            return summary

        @app.get("/api/applications")
        async def get_applications(
            period: str = "today",
            search: str = "",
            sort: str = "total",
            category: str = "all",
            start: Optional[str] = None,
            end: Optional[str] = None,
        ):
            apps = self.db.get_applications(
                period=period,
                search=search,
                sort_by=sort,
                category=category,
                start_date=start,
                end_date=end,
            )
            for a in apps:
                app_id = a["app_id"]
                metrics = self.monitor.app_live_metrics.get(app_id, {})
                a["rx_speed"] = metrics.get("rx_speed", 0.0)
                a["tx_speed"] = metrics.get("tx_speed", 0.0)
                a["is_active"] = metrics.get("active", False)
            return apps

        @app.get("/api/history")
        async def get_history(period: str = "7days", start: Optional[str] = None, end: Optional[str] = None):
            return self.db.get_history(period=period, start_date=start, end_date=end)

        @app.get("/api/connections")
        async def get_connections(app_id: Optional[str] = None):
            conns = self.monitor.get_active_connections(app_id=app_id)
            if not conns:
                conns = self.db.get_active_connections(app_id=app_id)
            return conns

        @app.get("/api/alerts")
        async def get_alerts():
            return self.monitor.get_alerts()

        @app.post("/api/alerts/clear")
        async def clear_alerts():
            self.monitor.clear_alerts()
            return {"status": "ok"}

        @app.get("/api/export")
        async def export_usage(
            format: str = "csv",
            period: str = "today",
            start: Optional[str] = None,
            end: Optional[str] = None,
            category: str = "all",
        ):
            if format.lower() == "json":
                data = self.db.get_applications(
                    period=period,
                    category=category,
                    start_date=start,
                    end_date=end,
                )
                return Response(
                    content=json.dumps(data, ensure_ascii=False, indent=2),
                    media_type="application/json; charset=utf-8",
                    headers={"Content-Disposition": f'attachment; filename="netscope_{period}.json"'},
                )
            csv_text = self.db.export_usage_csv(
                period=period,
                start_date=start,
                end_date=end,
                category=category,
            )
            return Response(
                content=csv_text.encode("utf-8"),
                media_type="text/csv; charset=utf-8",
                headers={"Content-Disposition": f'attachment; filename="netscope_{period}.csv"'},
            )

        @app.get("/api/settings")
        async def get_settings():
            return self.db.get_settings()

        @app.post("/api/settings")
        async def update_setting(req: SettingUpdateRequest):
            self.db.set_setting(req.key, req.value)
            if req.key == "start_with_windows" and self.service is not None:
                try:
                    self.service.configure_startup(req.value.lower() == "true")
                except Exception as e:
                    logger.warning(f"Failed applying start_with_windows setting: {e}")
            elif req.key == "monitoring_enabled":
                self.monitor.set_paused(req.value.lower() == "false")
            elif req.key in ("usage_notifications", "daily_quota_mb", "monthly_quota_mb", "alert_on_new_app"):
                self.monitor.reload_settings()
            return {"status": "ok", "key": req.key, "value": req.value}

        @app.post("/api/monitor/toggle")
        async def toggle_monitor():
            active = self.monitor.toggle_pause()
            self.db.set_setting("monitoring_enabled", "true" if active else "false")
            return {"status": "ok", "monitoring_active": active}

        @app.post("/api/database/clear")
        async def clear_database():
            self.db.clear_history()
            return {"status": "ok", "message": "History cleared successfully"}

        @app.post("/api/service/shutdown")
        async def shutdown_service():
            def _do_shutdown():
                time.sleep(0.3)
                if self.service is not None:
                    self.service.stop()
                os._exit(0)

            threading.Thread(target=_do_shutdown, daemon=True).start()
            return {"status": "ok", "message": "NetScope service is shutting down"}

        @app.get("/api/storage")
        async def get_storage():
            return self.db.get_storage_stats()

        @app.get("/icons/{icon_file}")
        async def get_icon(icon_file: str):
            safe_name = os.path.basename(icon_file)
            icons_root = os.path.realpath(self.monitor.icons_dir)
            icon_path = os.path.realpath(os.path.join(icons_root, safe_name))
            if not icon_path.startswith(icons_root + os.sep) or not os.path.exists(icon_path):
                raise HTTPException(status_code=404, detail="Icon not found")
            return FileResponse(icon_path, media_type="image/png")

        @app.websocket("/ws/live")
        async def websocket_live_endpoint(websocket: WebSocket):
            await websocket.accept()
            self._connected_websockets.append(websocket)
            try:
                while self._running:
                    status = self.monitor.get_live_status()
                    await websocket.send_json(status)
                    await asyncio.sleep(1.0)
            except WebSocketDisconnect:
                if websocket in self._connected_websockets:
                    self._connected_websockets.remove(websocket)
            except Exception:
                if websocket in self._connected_websockets:
                    self._connected_websockets.remove(websocket)

        web_dir = self._find_web_dir()
        if web_dir and os.path.exists(web_dir):
            from fastapi.staticfiles import StaticFiles
            app.mount("/", StaticFiles(directory=web_dir, html=True), name="web")
            logger.info(f"Mounted Flutter Web static files from: {web_dir}")
        else:
            logger.warning("Flutter Web assets directory not found; only API endpoints are active.")

    @staticmethod
    def _find_web_dir() -> Optional[str]:
        candidates = []
        if getattr(sys, "frozen", False):
            if hasattr(sys, "_MEIPASS"):
                candidates.append(os.path.join(sys._MEIPASS, "web"))
            candidates.append(os.path.join(os.path.dirname(sys.executable), "web"))
            candidates.append(os.path.join(os.path.dirname(sys.executable), "_internal", "web"))
        base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        candidates.append(os.path.join(base, "app", "build", "web"))

        for c in candidates:
            if c and os.path.exists(os.path.join(c, "index.html")):
                return c
        return None

    def start(self, host: str = "127.0.0.1", port: int = 58220):
        """Starts both Named Pipe server and HTTP/WebSocket server in background threads."""
        self._running = True

        self._pipe_thread = threading.Thread(target=self._run_named_pipe_loop, daemon=True, name="NetScopePipeThread")
        self._pipe_thread.start()

        def run_uvicorn():
            try:
                config = uvicorn.Config(
                    app=self.app,
                    host=host,
                    port=port,
                    log_config=None,
                    log_level="warning",
                )
                self._uvicorn_server = uvicorn.Server(config)
                self._uvicorn_server.run()
            except Exception as e:
                logger.error(f"Uvicorn server crashed: {e}")

        self._http_thread = threading.Thread(target=run_uvicorn, daemon=True, name="NetScopeHTTPThread")
        self._http_thread.start()
        logger.info(f"NetScope IPC Server running at http://{host}:{port} and {self.pipe_name}")

    def stop(self):
        self._running = False
        if self._uvicorn_server is not None:
            self._uvicorn_server.should_exit = True

    def _run_named_pipe_loop(self):
        """Windows Named Pipe IPC handler."""
        while self._running:
            try:
                pipe_handle = win32pipe.CreateNamedPipe(
                    self.pipe_name,
                    win32pipe.PIPE_ACCESS_DUPLEX,
                    win32pipe.PIPE_TYPE_MESSAGE | win32pipe.PIPE_READMODE_MESSAGE | win32pipe.PIPE_WAIT,
                    win32pipe.PIPE_UNLIMITED_INSTANCES,
                    65536,
                    65536,
                    0,
                    None,
                )
                win32pipe.ConnectNamedPipe(pipe_handle, None)

                res, data = win32file.ReadFile(pipe_handle, 64 * 1024)
                if res == 0 and data:
                    cmd_str = data.decode("utf-8").strip()
                    resp_dict = self._handle_pipe_command(cmd_str)
                    resp_bytes = json.dumps(resp_dict).encode("utf-8")
                    win32file.WriteFile(pipe_handle, resp_bytes)

                win32pipe.DisconnectNamedPipe(pipe_handle)
                win32file.CloseHandle(pipe_handle)
            except Exception:
                time.sleep(0.5)

    def _handle_pipe_command(self, cmd_str: str) -> Dict[str, Any]:
        """Dispatches pipe commands to appropriate handlers."""
        try:
            req = json.loads(cmd_str)
            action = req.get("action", "")
            if action == "status":
                return self.monitor.get_live_status()
            elif action == "dashboard":
                return self.db.get_dashboard_summary()
            elif action == "applications":
                return {"applications": self.db.get_applications(req.get("period", "today"), category=req.get("category", "all"))}
            elif action == "connections":
                return {"connections": self.monitor.get_active_connections(req.get("app_id"))}
            elif action == "toggle":
                active = self.monitor.toggle_pause()
                self.db.set_setting("monitoring_enabled", "true" if active else "false")
                return {"monitoring_active": active}
            return {"status": "ok", "message": f"Unknown action: {action}"}
        except Exception as e:
            return {"error": str(e)}
