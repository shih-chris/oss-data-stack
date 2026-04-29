"""HTTP health endpoint for the Cloud Run Dagster daemon service."""

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def _daemon_running() -> bool:
    pid = os.getenv("DAGSTER_DAEMON_PID")
    if not pid:
        return False

    try:
        os.kill(int(pid), 0)
    except (OSError, ValueError):
        return False
    return True


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path not in {"/", "/healthz"}:
            self.send_response(404)
            self.end_headers()
            return

        running = _daemon_running()
        self.send_response(200 if running else 503)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"dagster_daemon_running": running}).encode())

    def log_message(self, format: str, *args) -> None:
        return


def main() -> None:
    port = int(os.getenv("PORT", "8080"))
    server = ThreadingHTTPServer(("0.0.0.0", port), HealthHandler)
    server.serve_forever()


if __name__ == "__main__":
    main()
