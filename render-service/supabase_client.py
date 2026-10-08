"""Supabase REST 클라이언트 — 공개 웹 프로필용 cv_data_by_slug RPC 호출."""
from __future__ import annotations
import os
import httpx

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
ANON_KEY = os.environ.get("SUPABASE_ANON_KEY", "")


def cv_data_by_slug(slug: str, lang: str = "en") -> dict | None:
    """slug + 언어로 공개(리댁션된) canonical JSON 을 가져온다. 없으면 None."""
    if not SUPABASE_URL or not ANON_KEY:
        raise RuntimeError("SUPABASE_URL / SUPABASE_ANON_KEY not configured")
    r = httpx.post(
        f"{SUPABASE_URL}/rest/v1/rpc/cv_data_by_slug",
        headers={
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {ANON_KEY}",
            "Content-Type": "application/json",
        },
        json={"p_slug": slug, "p_lang": lang},
        timeout=15.0,
    )
    r.raise_for_status()
    data = r.json()
    return data or None
