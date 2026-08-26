#!/usr/bin/env python3
"""Live Arrive Alive backend contract check.

Creates an isolated test user and records. The caller can promote the printed
phone to admin between phases, then remove the test user from Supabase.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request


BASE = os.environ.get("ARRIVE_ALIVE_API_URL", "").rstrip("/")
PHONE = os.environ.get("ARRIVE_ALIVE_TEST_PHONE", f"qa{int(time.time())}")
PIN = "2468"
SECRET = "mango-sync"


def request(path, method="GET", body=None, token=None, origin=None):
    data = None if body is None else json.dumps(body).encode()
    headers = {"Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if origin:
        headers["Origin"] = origin
    req = urllib.request.Request(
        f"{BASE}{path}", data=data, headers=headers, method=method
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read().decode()
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        raw = error.read().decode()
        payload = json.loads(raw) if raw else {}
        raise AssertionError(f"{method} {path}: {error.code} {payload}") from error


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    require(BASE.startswith("https://"), "ARRIVE_ALIVE_API_URL must be HTTPS")
    phase = sys.argv[1] if len(sys.argv) > 1 else "user"

    if phase == "cors":
        req = urllib.request.Request(
            f"{BASE}/health",
            method="OPTIONS",
            headers={
                "Origin": "https://arrive-alive-virid.vercel.app",
                "Access-Control-Request-Method": "GET",
            },
        )
        with urllib.request.urlopen(req, timeout=30) as response:
            require(response.status == 204, "CORS preflight did not return 204")
            require(
                response.headers.get("Access-Control-Allow-Origin")
                == "https://arrive-alive-virid.vercel.app",
                "Production origin was not allowed",
            )
        print(json.dumps({"phase": "cors", "passed": True}))
        return

    if phase == "user":
        status, _ = request(
            "/api/auth/register",
            "POST",
            {
                "displayName": "Synchronization QA",
                "phone": PHONE,
                "pin": PIN,
                "secretWord": SECRET,
            },
        )
        require(status == 201, "Registration did not return 201")

    _, login = request(
        "/api/auth/login", "POST", {"phone": PHONE, "pin": PIN}
    )
    token = login.get("token")
    require(token, "Login did not return an opaque session token")

    if phase == "user":
        _, profile = request(
            "/api/profile",
            "PATCH",
            {"displayName": "Synchronization QA Updated"},
            token,
        )
        require(
            profile.get("displayName") == "Synchronization QA Updated",
            "Profile update did not persist",
        )

        suffix = PHONE.replace("+", "")
        snapshot = {
            "schemaVersion": 1,
            "revision": 1,
            "updatedAt": "2026-08-26T18:00:00.000Z",
            "collections": {
                "users": [],
                "profiles": [],
                "journeys": [
                    {
                        "id": f"journey-{suffix}",
                        "mode": "car",
                        "status": "completed",
                        "startTime": "2026-08-26T17:00:00.000Z",
                        "endTime": "2026-08-26T17:15:00.000Z",
                        "maxSpeed": 64,
                        "distance": 8.2,
                        "score": 96,
                        "version": 1,
                        "updatedAt": "2026-08-26T18:00:00.000Z",
                    }
                ],
                "incidents": [
                    {
                        "id": f"incident-{suffix}",
                        "type": "pothole",
                        "description": "Synchronization QA record",
                        "lat": 3.848,
                        "lng": 11.502,
                        "status": "active",
                        "version": 1,
                        "updatedAt": "2026-08-26T18:00:00.000Z",
                    }
                ],
                "agencies": [],
                "speedLimits": [],
            },
        }
        _, merged = request(
            "/api/sync",
            "POST",
            {"operation": "merge", "snapshot": snapshot},
            token,
        )
        require(
            merged.get("persistence", {}).get("durable") is True,
            "Sync did not report durable persistence",
        )
        _, pulled = request("/api/sync", "GET", token=token)
        journeys = pulled.get("snapshot", {}).get("collections", {}).get("journeys", [])
        incidents = pulled.get("snapshot", {}).get("collections", {}).get("incidents", [])
        require(
            any(item.get("id") == f"journey-{suffix}" for item in journeys),
            "Journey was missing after pull",
        )
        require(
            any(item.get("id") == f"incident-{suffix}" for item in incidents),
            "Incident was missing after pull",
        )
        print(
            json.dumps(
                {
                    "phase": "user",
                    "passed": True,
                    "phone": PHONE,
                    "durable": True,
                    "journeys": len(journeys),
                    "incidents": len(incidents),
                }
            )
        )
        return

    require(phase == "admin", f"Unknown phase: {phase}")
    require(login.get("role") == "admin", "Test user is not admin")
    _, overview = request("/api/stats", token=token)
    _, users = request("/api/users", token=token)
    _, violations = request("/api/violations", token=token)
    _, incidents = request("/api/incidents", token=token)
    _, health = request("/api/admin/sync-health", token=token)
    require(isinstance(users, list) and users, "Admin users endpoint is empty")
    require(isinstance(violations, list), "Admin violations endpoint is invalid")
    require(isinstance(incidents, list), "Admin incidents endpoint is invalid")
    require(health.get("durable") is True, "Admin sync health is not durable")
    print(
        json.dumps(
            {
                "phase": "admin",
                "passed": True,
                "overviewKeys": sorted(overview.keys()),
                "users": len(users),
                "durable": health.get("durable"),
            }
        )
    )


if __name__ == "__main__":
    main()
