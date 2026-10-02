"""Fermata render-service — 공개 웹 프로필(HTML) + PDF 렌더 HTTP API.

  GET  /healthz            헬스체크
  GET  /p/{slug}           공개 웹 프로필 (HTML, Supabase RPC → build_html)
  GET  /p/{slug}.pdf       공개 프로필 PDF
  POST /render             canonical JSON → PDF (Edge Function 전용, RENDER_TOKEN 보호)

템플릿/폰트는 render.py 와 공유한다. PDF 는 두 경로 모두 동일한 build_html 을 거친다.
"""
from __future__ import annotations
import os

from fastapi import FastAPI, HTTPException, Header, Request, Response
from fastapi.responses import HTMLResponse

from render import build_html, to_pdf
import supabase_client

RENDER_TOKEN = os.environ.get("RENDER_TOKEN", "")

app = FastAPI(title="fermata-render")


@app.get("/healthz")
def healthz():
    return {"ok": True}


SUPPORTED_LANGS = ("ko", "en", "de")


def _resolve_lang(explicit: str | None, accept_language: str) -> str:
    """방문자 언어 해석: ?lang= 우선 → Accept-Language 첫 매칭 → en 기본."""
    if explicit and explicit in SUPPORTED_LANGS:
        return explicit
    for part in accept_language.split(","):
        code = part.split(";")[0].strip().lower().split("-")[0]
        if code in SUPPORTED_LANGS:
            return code
    return "en"


def _load_public(slug: str, lang: str) -> dict:
    try:
        data = supabase_client.cv_data_by_slug(slug, lang)
    except Exception as e:  # 상류(REST) 오류
        raise HTTPException(status_code=502, detail=f"upstream error: {e}")
    if not data:
        raise HTTPException(status_code=404, detail="profile not found")
    return data


# NOTE: .pdf 라우트를 먼저 선언해야 함 — {slug} 가 ".pdf"까지 삼켜 shadow 되는 걸 방지
@app.get("/p/{slug}.pdf")
def web_profile_pdf(slug: str, lang: str | None = None,
                    accept_language: str = Header(default="")):
    resolved = _resolve_lang(lang, accept_language)
    pdf = to_pdf(build_html(_load_public(slug, resolved)))
    return Response(
        content=pdf,
        media_type="application/pdf",
        headers={"Content-Disposition": f'inline; filename="{slug}.pdf"'},
    )


@app.get("/p/{slug}", response_class=HTMLResponse)
def web_profile(slug: str, lang: str | None = None,
                accept_language: str = Header(default="")):
    resolved = _resolve_lang(lang, accept_language)
    return HTMLResponse(build_html(_load_public(slug, resolved)))


@app.post("/render")
async def render(request: Request, x_render_token: str = Header(default="")):
    # Edge Function 만 호출 — 전체(민감정보 포함) JSON 을 PDF 로. 공유 토큰으로 보호.
    if not RENDER_TOKEN or x_render_token != RENDER_TOKEN:
        raise HTTPException(status_code=401, detail="unauthorized")
    data = await request.json()
    if not isinstance(data, dict) or "person" not in data:
        raise HTTPException(status_code=400, detail="invalid CV data")
    pdf = to_pdf(build_html(data))
    return Response(content=pdf, media_type="application/pdf")
