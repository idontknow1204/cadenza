#!/usr/bin/env python3
"""
Fermata CV 렌더 코어 — 웹 프로필과 PDF 가 이 한 벌을 공유한다.

  build_html(data)        -> str    (웹 프로필 SSR / PDF 입력, 공용)
  to_pdf(html)            -> bytes  (PDF 전용, WeasyPrint)
  render_file(src, out)             (CLI 편의)

CLI:
  python3 render.py schema/cv_data.example.json out.pdf
"""
from __future__ import annotations
import json
import sys
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

BASE = Path(__file__).parent
TEMPLATE = "cv.html.j2"

_env = Environment(
    loader=FileSystemLoader(str(BASE / "templates")),
    autoescape=False,          # 데이터는 신뢰된 내부 소스(DB) — 성씨의 & 등은 템플릿에서 처리
    trim_blocks=True,
    lstrip_blocks=True,
)


def _has_verification(data: dict) -> bool:
    """검증 표시가 하나라도 있으면 각주 범례를 노출한다 (§9)."""
    for s in data.get("sections", []):
        for e in s.get("entries", []):
            if e.get("verification") in ("institution", "peer"):
                return True
    return False


def build_html(data: dict) -> str:
    """canonical JSON -> 완성 HTML. 웹/PDF 공용. @page 는 웹에서 무시된다."""
    return _env.get_template(TEMPLATE).render(
        meta=data.get("meta", {}),
        p=data["person"],
        sections=data.get("sections", []),
        has_verification=_has_verification(data),
    )


def to_pdf(html: str, *, base_url: str | None = None) -> bytes:
    """HTML -> A4 PDF. base_url 로 폰트/사진 상대경로를 해석한다.
    템플릿이 templates/ 에 있고 @font-face 가 ../fonts/ 를 참조하므로
    기본 base_url 은 templates/ (→ ../fonts = <root>/fonts)."""
    from weasyprint import HTML  # 지연 import — 웹 SSR 경로는 WeasyPrint 없이도 동작
    return HTML(string=html, base_url=base_url or str(BASE / "templates")).write_pdf()


def render_file(src: str, out: str) -> str:
    data = json.loads(Path(src).read_text(encoding="utf-8"))
    html = build_html(data)
    out_path = Path(out)
    out_path.with_suffix(".html").write_text(html, encoding="utf-8")
    out_path.write_bytes(to_pdf(html))
    return out


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: python3 render.py <data.json> <out.pdf>")
    print("wrote", render_file(sys.argv[1], sys.argv[2]))
