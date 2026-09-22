"""Tracks how many pages each device has scanned today, so `/extract`'s free
LLM tier can't be drained by whoever finds the backend URL.

Deliberately simple: one SQLite file, no separate database service (keeps
the $0/month Azure App Service setup -- see backend/README.md). Fine for the
traffic this app expects; a real database would be worth it once usage grows
past what one SQLite file comfortably handles, or once the app runs on more
than one instance (Azure's Free/Basic tiers don't scale out, so that's not a
concern yet).
"""

import os
import sqlite3
import threading
from datetime import date


class QuotaExceeded(Exception):
    """Raised by `Quota.consume` when the device already used up today's
    allowance -- nothing is registered when this is raised."""

    def __init__(self, used: int, limit: int):
        super().__init__(f"{used}/{limit} pages already used today")
        self.used = used
        self.limit = limit


class Quota:
    """`db_path=':memory:'` gives an isolated, disposable quota -- use that
    in tests instead of pointing at the real file."""

    def __init__(self, db_path: str):
        self._lock = threading.Lock()
        if db_path != ":memory:":
            directory = os.path.dirname(db_path)
            if directory:
                os.makedirs(directory, exist_ok=True)
        self._conn = sqlite3.connect(db_path, check_same_thread=False)
        self._conn.execute(
            "CREATE TABLE IF NOT EXISTS usage ("
            "device_id TEXT NOT NULL, day TEXT NOT NULL, pages INTEGER NOT NULL, "
            "PRIMARY KEY (device_id, day))"
        )
        self._conn.commit()

    def consume(self, device_id: str, *, daily_limit: int) -> int:
        """Registers one scanned page for `device_id` today and returns how
        many pages are left today. Raises `QuotaExceeded` (without
        registering anything) once the device already used `daily_limit`
        pages today. `daily_limit <= 0` disables the quota -- always
        allowed, nothing tracked, returns 0."""
        if daily_limit <= 0:
            return 0
        today = date.today().isoformat()
        with self._lock:
            row = self._conn.execute(
                "SELECT pages FROM usage WHERE device_id = ? AND day = ?",
                (device_id, today),
            ).fetchone()
            used = row[0] if row else 0
            if used >= daily_limit:
                raise QuotaExceeded(used, daily_limit)
            self._conn.execute(
                "INSERT INTO usage (device_id, day, pages) VALUES (?, ?, 1) "
                "ON CONFLICT(device_id, day) DO UPDATE SET pages = pages + 1",
                (device_id, today),
            )
            self._conn.commit()
            return daily_limit - used - 1


def default_db_path() -> str:
    """Azure App Service (Linux) persists `/home` across restarts on the
    single instance the Free/Basic tiers run (no scale-out there, so a local
    file is safe); `WEBSITE_INSTANCE_ID` is set by Azure itself, so this only
    kicks in there. Locally it's just a file next to the app, overridable
    with LIVRESCAN_DB_PATH for local experiments."""
    if os.environ.get("WEBSITE_INSTANCE_ID"):
        return "/home/data/usage.db"
    return os.environ.get("LIVRESCAN_DB_PATH", "usage.db")
