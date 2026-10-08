#!/usr/bin/env python3
"""
Cadenza seed data cleanup.

Deletes all accounts marked is_seed=true and their associated data:
  - storage objects (activity images)
  - activities, follows, notifications, likes, comments, tags, saves
  - profiles
  - auth users

Usage:
    python3 cleanup_seed.py           # dry-run (shows what would be deleted)
    python3 cleanup_seed.py --confirm # actually delete
"""

import os
import sys
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://vcxllrzpolymzylrfscb.supabase.co")
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")
if not SERVICE_KEY:
    raise SystemExit("SUPABASE_SERVICE_KEY is required.")
SVC = {"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}", "Content-Type": "application/json"}

_session = requests.Session()
_retry = Retry(total=4, backoff_factor=1.0, status_forcelist=[500, 502, 503, 504])
_session.mount("https://", HTTPAdapter(max_retries=_retry))

DRY = "--confirm" not in sys.argv


def rest(method, path, **kw):
    r = _session.request(method, f"{SUPABASE_URL}/rest/v1/{path}", headers=SVC, **kw)
    if not r.ok:
        print(f"  WARN {method} {path}: {r.status_code} {r.text[:120]}")
    return r


def admin(method, path, **kw):
    r = _session.request(method, f"{SUPABASE_URL}/auth/v1/admin/{path}", headers=SVC, **kw)
    if not r.ok:
        print(f"  WARN admin {method} {path}: {r.status_code} {r.text[:120]}")
    return r


def main():
    if DRY:
        print("DRY RUN — pass --confirm to delete for real\n")

    # 1. Fetch seed profiles
    r = rest("GET", "profiles?is_seed=eq.true&select=id,real_name")
    seed_profiles = r.json()
    if not seed_profiles:
        print("No seed profiles found (is_seed=true). Nothing to do.")
        return

    seed_ids = [p["id"] for p in seed_profiles]
    print(f"Seed accounts ({len(seed_ids)}):")
    for p in seed_profiles:
        print(f"  {p['real_name']} — {p['id']}")

    # 2. Fetch seed activities (for storage cleanup)
    r = rest("GET", "activities?user_id=in.(" + ",".join(seed_ids) + ")&select=id,image_urls")
    seed_activities = r.json()
    print(f"\nSeed activities: {len(seed_activities)}")

    storage_paths = []
    for act in seed_activities:
        for url in (act.get("image_urls") or []):
            # Extract path after /activity-images/
            marker = "/activity-images/"
            if marker in url:
                storage_paths.append(url.split(marker, 1)[1])
    print(f"Storage objects to remove: {len(storage_paths)}")

    if DRY:
        print("\nNothing deleted. Run with --confirm to proceed.")
        return

    print("\nDeleting...")

    # 3. Remove storage objects in batches of 20
    BUCKET = "activity-images"
    for i in range(0, len(storage_paths), 20):
        batch = storage_paths[i:i+20]
        r = _session.delete(
            f"{SUPABASE_URL}/storage/v1/object/{BUCKET}",
            headers=SVC,
            json={"prefixes": batch}
        )
        print(f"  Storage batch {i//20+1}: {r.status_code}")

    # 4. Delete DB rows — order matters for FK constraints
    id_filter = "user_id=in.(" + ",".join(seed_ids) + ")"
    tables_by_user = [
        "activity_likes",
        "activity_comments",
        "activity_tags",
        "activity_saves",
        "notifications",
        "activities",
    ]
    for table in tables_by_user:
        r = rest("DELETE", f"{table}?{id_filter}")
        print(f"  DELETE {table}: {r.status_code}")

    # follows: seed users appear as both follower and followee
    seed_in = "(" + ",".join(seed_ids) + ")"
    r = rest("DELETE", f"follows?follower_id=in.{seed_in}")
    print(f"  DELETE follows (as follower): {r.status_code}")
    r = rest("DELETE", f"follows?followee_id=in.{seed_in}")
    print(f"  DELETE follows (as followee): {r.status_code}")

    r = rest("DELETE", "profiles?is_seed=eq.true")
    print(f"  DELETE profiles: {r.status_code}")

    # 5. Delete auth users via admin API
    for uid in seed_ids:
        r = admin("DELETE", f"users/{uid}")
        print(f"  DELETE auth user {uid}: {r.status_code}")

    print("\nCleanup complete.")


if __name__ == "__main__":
    main()
