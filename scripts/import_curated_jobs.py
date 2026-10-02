#!/usr/bin/env python3
"""Import verified music opportunities from official institution pages.

Dry-run is the default. ``--apply`` requires migration 0038 and
``SUPABASE_SERVICE_KEY``.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import html
import json
import math
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass
from html.parser import HTMLParser
from typing import Callable


SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://vcxllrzpolymzylrfscb.supabase.co")
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")
PARSER_VERSION = "2.2.0"

INSTRUMENTS = {
    "violin": "바이올린", "vioin": "바이올린", "violine": "바이올린",
    "viola": "비올라", "bratsche": "비올라", "violoncello": "첼로", "cello": "첼로",
    "kontrabass": "콘트라베이스", "double bass": "콘트라베이스",
    "flute": "플루트", "flöte": "플루트", "oboe": "오보에",
    "clarinet": "클라리넷", "klarinette": "클라리넷",
    "bassoon": "바순", "fagott": "바순", "horn": "호른",
    "trumpet": "트럼펫", "trompete": "트럼펫",
    "posaune": "트롬본", "trombone": "트롬본", "tuba": "튜바",
    "harp": "하프", "harfe": "하프", "percussion": "타악기",
    "schlagzeug": "타악기", "concertmaster": "바이올린",
    "konzertmeister": "바이올린",
}

MONTHS = {
    "january": 1, "february": 2, "march": 3, "april": 4, "may": 5,
    "june": 6, "july": 7, "august": 8, "september": 9, "october": 10,
    "ocotober": 10, "november": 11, "december": 12, "januar": 1,
    "februar": 2, "märz": 3, "maerz": 3, "mai": 5, "juni": 6,
    "juli": 7, "oktober": 10, "dezember": 12,
}


@dataclass(frozen=True)
class Source:
    slug: str
    url: str
    language: str
    organization: str
    city_id: str
    location: str
    parser_key: str
    expected_min: int = 1


@dataclass
class Opportunity:
    title: str
    organization: str
    location: str
    city_id: str
    source_url: str
    source_language: str
    instruments: list[str]
    description: str
    job_type: str = "position"
    requirements: str | None = None
    deadline: str | None = None
    event_start: str | None = None
    status: str = "open"
    has_scholarship: bool = False
    application_fee: float | None = None


@dataclass(frozen=True)
class FetchResult:
    status: int
    content_hash: str | None
    etag: str | None
    last_modified: str | None
    text: str | None


class TextExtractor(HTMLParser):
    block_tags = {
        "address", "article", "br", "dd", "div", "dt", "h1", "h2", "h3",
        "h4", "h5", "li", "p", "section", "td", "th", "tr",
    }

    def __init__(self) -> None:
        super().__init__()
        self.parts: list[str] = []
        self.skip_depth = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in {"script", "style", "noscript", "svg"}:
            self.skip_depth += 1
        if tag in self.block_tags:
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag in {"script", "style", "noscript", "svg"} and self.skip_depth:
            self.skip_depth -= 1
        if tag in self.block_tags:
            self.parts.append("\n")

    def handle_data(self, data: str) -> None:
        if not self.skip_depth:
            self.parts.append(data)

    def text(self) -> str:
        value = html.unescape(" ".join(self.parts))
        value = re.sub(r"[ \t\r\f\v]+", " ", value)
        value = re.sub(r" *\n *", "\n", value)
        return re.sub(r"\n{2,}", "\n", value).strip()


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def fetch_page(
    url: str,
    etag: str | None = None,
    last_modified: str | None = None,
    retries: int = 3,
) -> FetchResult:
    headers = {
        "User-Agent": "CadenzaOpportunityImporter/2.0 (+https://cadenza.app)",
        "Accept": "text/html,application/xhtml+xml",
        "Accept-Language": "en,de;q=0.9",
    }
    if etag:
        headers["If-None-Match"] = etag
    if last_modified:
        headers["If-Modified-Since"] = last_modified

    for attempt in range(retries):
        request = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                raw = response.read()
                content_type = response.headers.get("Content-Type", "")
                match = re.search(r"charset=([^;]+)", content_type, re.I)
                charset = match.group(1).strip() if match else "utf-8"
                extractor = TextExtractor()
                extractor.feed(raw.decode(charset, errors="replace"))
                extracted_text = extractor.text()
                return FetchResult(
                    response.status,
                    hashlib.sha256(extracted_text.encode("utf-8")).hexdigest(),
                    response.headers.get("ETag"),
                    response.headers.get("Last-Modified"),
                    extracted_text,
                )
        except urllib.error.HTTPError as exc:
            if exc.code == 304:
                return FetchResult(304, None, etag, last_modified, None)
            if exc.code not in {429, 500, 502, 503, 504} or attempt == retries - 1:
                detail = exc.read().decode("utf-8", errors="replace")[:240]
                raise RuntimeError(f"HTTP {exc.code} for {url}: {detail}") from exc
        except urllib.error.URLError as exc:
            if attempt == retries - 1:
                raise RuntimeError(f"Network error for {url}: {exc.reason}") from exc
        time.sleep(2**attempt)
    raise RuntimeError(f"Could not fetch {url}")


def text_lines(text: str) -> list[str]:
    lines: list[str] = []
    for line in text.splitlines():
        cleaned = re.sub(r"\s+", " ", line).strip(" -\u00a0")
        if len(cleaned) >= 2:
            lines.append(cleaned)
    return lines


def parse_date(value: str, default_year: int | None = None) -> str | None:
    value = re.sub(r"\s+", " ", value.replace(",", " ").strip())
    value = re.sub(r"\b(am|pm|Uhr|h)\b.*", "", value, flags=re.I).strip()
    numeric = re.search(r"(\d{1,2})\.(?:/(\d{1,2})\.)?(\d{1,2})\.(\d{4})", value)
    if numeric:
        day = int(numeric.group(2) or numeric.group(1))
        try:
            return dt.date(int(numeric.group(4)), int(numeric.group(3)), day).isoformat()
        except ValueError:
            return None
    numeric = re.search(r"(\d{1,2})\.(?:/(\d{1,2})\.)?(\d{1,2})\.", value)
    if numeric and default_year:
        day = int(numeric.group(2) or numeric.group(1))
        try:
            return dt.date(default_year, int(numeric.group(3)), day).isoformat()
        except ValueError:
            return None
    named = re.search(r"(\d{1,2})(?:st|nd|rd|th)?\.?\s+([A-Za-zÄÖÜäöüß]+)\s+(\d{4})", value)
    if named:
        month = MONTHS.get(named.group(2).lower())
        if month:
            try:
                return dt.date(int(named.group(3)), month, int(named.group(1))).isoformat()
            except ValueError:
                return None
    named = re.search(r"(\d{1,2})(?:st|nd|rd|th)?\.?\s+([A-Za-zÄÖÜäöüß]+)", value)
    if named and default_year:
        month = MONTHS.get(named.group(2).lower())
        if month:
            try:
                return dt.date(default_year, month, int(named.group(1))).isoformat()
            except ValueError:
                return None
    return None


def infer_instruments(title: str) -> list[str]:
    haystack = title.lower().replace("-", " ")
    found: list[str] = []
    for needle, instrument in INSTRUMENTS.items():
        if needle in haystack and instrument not in found:
            found.append(instrument)
    return found


def clean_title(raw: str) -> str:
    title = re.sub(r"\s+", " ", raw.strip(" :\u00a0"))
    if title.isupper():
        return title.title().replace("Tutti", "tutti").replace("Solo-", "Solo ")
    return title


def is_position_line(line: str) -> bool:
    low = line.lower()
    excluded = ("application", "bewerbung", "hinweise", "instructions", "deadline", "date of")
    if any(word in low for word in excluded) or len(line) > 100:
        return False
    return bool(infer_instruments(line) or re.search(r"\b(solo|tutti|academy|akademie|concertmaster|leader)\b", low))


def source_excerpt(lines: list[str], start: int, size: int = 8) -> str:
    return "\n".join(lines[start : start + size]).strip()


def munich_philharmonic(source: Source, text: str) -> list[Opportunity]:
    lines = text_lines(text)
    items: list[Opportunity] = []
    in_vacancies = False
    academy = False
    for index, line in enumerate(lines[:-1]):
        low = line.lower()
        if low == "gesucht werden":
            in_vacancies = True
            academy = False
            continue
        if low == "orchesterakademie":
            in_vacancies = True
            academy = True
            continue
        schedule = lines[index + 1]
        if not in_vacancies or not schedule.lower().startswith("probespieltermin:"):
            continue
        instruments = infer_instruments(line)
        if not instruments:
            continue
        deadline_match = re.search(r"Bewerbungsfrist:\s*([^)]+)", schedule, re.I)
        audition_match = re.search(r"Probespieltermin:\s*([^ (]+)", schedule, re.I)
        deadline = parse_date(deadline_match.group(1)) if deadline_match else None
        audition = parse_date(audition_match.group(1)) if audition_match else None
        prefix = "Orchesterakademie" if academy else "Münchner Philharmoniker"
        items.append(Opportunity(
            title=f"{prefix}: {clean_title(line)}", organization=source.organization,
            location=source.location, city_id=source.city_id, source_url=source.url,
            source_language=source.language, instruments=instruments,
            deadline=deadline, event_start=audition,
            description=f"{line}\n{schedule}", job_type="audition" if academy else "position",
            has_scholarship=academy,
        ))
    return items


def oper_frankfurt(source: Source, text: str) -> list[Opportunity]:
    lines = text_lines(text)
    items: list[Opportunity] = []
    capture = False
    starts: list[int] = []
    section_end = len(lines)
    for index, line in enumerate(lines):
        low = line.lower()
        if "sucht" in low or "stellenangebote des orchesters" in low:
            capture = True
        if capture and re.match(r"ein(?:e|en)?\s+", low) and is_position_line(line):
            starts.append(index)
        if "informationen zur bewerbung" in low:
            section_end = index
            break
    for position, index in enumerate(starts):
        line = lines[index]
        next_start = starts[position + 1] if position + 1 < len(starts) else section_end
        raw_title = re.sub(r"^ein(?:e|en)?\s+", "", line, flags=re.I)
        items.append(Opportunity(
            title=f"Opern- und Museumsorchester Frankfurt: {clean_title(raw_title)}",
            organization=source.organization, location=source.location,
            city_id=source.city_id, source_url=source.url,
            source_language=source.language, instruments=infer_instruments(raw_title),
            description="\n".join(lines[index:next_start]),
        ))
    return items


def karajan_akademie(source: Source, text: str) -> list[Opportunity]:
    lines = text_lines(text)
    items: list[Opportunity] = []
    heading = re.compile(r"^[A-ZÄÖÜa-zäöüß /-]+\s*\(\d+\)$")
    starts = [index for index, line in enumerate(lines) if heading.match(line) and infer_instruments(line)]
    for position, index in enumerate(starts):
        line = lines[index]
        next_start = starts[position + 1] if position + 1 < len(starts) else len(lines)
        end = min(next_start, index + 14)
        excerpt = "\n".join(lines[index:end]).strip()
        if not re.search(r"Audition:|Application deadline:|Compulsory (?:pieces?|repertoire)|Required pieces", excerpt, re.I):
            continue
        instruments = infer_instruments(line)
        deadline_match = re.search(r"(?:Application deadline|deadline):?\s*([^\n]+)", excerpt, re.I)
        has_schedule = bool(re.search(r"Audition:|Application deadline:", excerpt, re.I))
        items.append(Opportunity(
            title=f"Karajan-Akademie: {clean_title(line)}", organization=source.organization,
            location=source.location, city_id=source.city_id, source_url=source.url,
            source_language=source.language, instruments=instruments,
            deadline=parse_date(deadline_match.group(1)) if deadline_match else None,
            description=excerpt, job_type="audition", has_scholarship=True,
            status="open" if has_schedule else "announced",
        ))
    return items


SOURCES: list[tuple[Source, Callable[[Source, str], list[Opportunity]]]] = [
    (Source("munich-philharmonic", "https://www.mphil.de/ueber-uns/offene-stellen", "de", "Münchner Philharmoniker", "munich", "Munich, Germany", "munich_philharmonic"), munich_philharmonic),
    (Source("oper-frankfurt", "https://oper-frankfurt.de/de/das-frankfurter-opern-und-museumsorchester/stellenangebote-des-orchesters/", "de", "Oper Frankfurt", "frankfurt", "Frankfurt am Main, Germany", "oper_frankfurt"), oper_frankfurt),
    (Source("karajan-akademie", "https://www.berliner-philharmoniker.de/en/about-us/karajan-akademie/application-and-vacancies/", "en", "Berliner Philharmoniker", "berlin", "Berlin, Germany", "karajan_akademie"), karajan_akademie),
]


def normalized_title(title: str) -> str:
    return "".join(character for character in title.strip().lower() if character.isalnum())


def external_key(source: Source, item: Opportunity) -> str:
    digest = hashlib.md5(normalized_title(item.title).encode("utf-8")).hexdigest()
    return f"{source.slug}:{digest}"


def item_document(item: Opportunity) -> dict[str, object]:
    return {key: value for key, value in asdict(item).items() if value is not None}


def item_hash(item: Opportunity) -> str:
    encoded = json.dumps(item_document(item), ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def validate_item(item: Opportunity) -> tuple[list[str], float]:
    errors: list[str] = []
    if not 5 <= len(item.title.strip()) <= 180:
        errors.append("title length")
    if not item.organization.strip():
        errors.append("organization")
    if not item.location.strip() or not item.city_id.strip():
        errors.append("location")
    if not item.instruments:
        errors.append("instrument")
    if len(item.description.strip()) < 10:
        errors.append("description")
    if item.job_type not in {"audition", "position", "lesson", "gig"}:
        errors.append("job type")
    if item.source_language not in {"en", "de", "ko"}:
        errors.append("source language")
    if not item.source_url.startswith("https://"):
        errors.append("source URL")
    for label, value in (("deadline", item.deadline), ("event start", item.event_start)):
        if value:
            try:
                dt.date.fromisoformat(value)
            except ValueError:
                errors.append(label)
    return errors, 1.0 if item.deadline else 0.9


def is_expired(item: Opportunity) -> bool:
    return bool(item.deadline and item.deadline < dt.date.today().isoformat())


def explicit_empty_page(text: str) -> bool:
    compact = re.sub(r"\s+", " ", text.lower())
    markers = (
        "no current vacancies", "currently no vacancies",
        "no positions are currently available", "derzeit keine offenen stellen",
        "momentan keine offenen stellen", "keine freien stellen",
    )
    return any(marker in compact for marker in markers)


def normalize_items(source: Source, items: list[Opportunity]) -> tuple[list[Opportunity], list[str]]:
    unique: dict[str, Opportunity] = {}
    warnings: list[str] = []
    for item in items:
        key = external_key(source, item)
        errors, _ = validate_item(item)
        if errors:
            warnings.append(f"{item.title}: invalid {', '.join(errors)}")
            continue
        if is_expired(item):
            warnings.append(f"{item.title}: expired")
            continue
        if key in unique:
            warnings.append(f"{item.title}: duplicate")
        unique[key] = item
    return list(unique.values()), warnings


def request_headers(prefer: str | None = None) -> dict[str, str]:
    if not SERVICE_KEY:
        raise RuntimeError("SUPABASE_SERVICE_KEY is required for --apply.")
    headers = {
        "apikey": SERVICE_KEY,
        "Authorization": f"Bearer {SERVICE_KEY}",
        "Content-Type": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer
    return headers


def rest(method: str, path: str, body: object | None = None, prefer: str | None = None) -> tuple[int, str]:
    data = None if body is None else json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/{path}", data=data, method=method,
        headers=request_headers(prefer),
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", errors="replace")


def rest_json(method: str, path: str, body: object | None = None, prefer: str | None = None) -> object:
    status, text = rest(method, path, body, prefer)
    if status >= 300:
        raise RuntimeError(f"Supabase {method} {path} failed: {status} {text[:500]}")
    return json.loads(text) if text else None


def curator_user_id() -> str | None:
    user_id = os.environ.get("CADENZA_CURATOR_USER_ID", "").strip()
    if not user_id:
        return None
    if not re.fullmatch(r"[0-9a-fA-F-]{36}", user_id):
        raise RuntimeError("CADENZA_CURATOR_USER_ID must be a UUID when provided.")
    return user_id


def query_string(values: dict[str, str]) -> str:
    return urllib.parse.urlencode(values, safe="(),.*")


def load_source_record(source: Source) -> dict[str, object]:
    query = query_string({"select": "*", "slug": f"eq.{source.slug}", "limit": "1"})
    rows = rest_json("GET", f"opportunity_sources?{query}")
    if not isinstance(rows, list) or not rows:
        raise RuntimeError(f"Source {source.slug} is missing. Apply migration 0035 first.")
    record = rows[0]
    if not record.get("enabled"):
        raise RuntimeError(f"Source {source.slug} is disabled.")
    if record.get("parser_key") != source.parser_key:
        raise RuntimeError(f"Parser mismatch for {source.slug}.")
    return record


def start_run(source_id: str) -> str:
    rows = rest_json("POST", "opportunity_ingest_runs", {
        "source_id": source_id, "parser_version": PARSER_VERSION,
    }, "return=representation")
    if not isinstance(rows, list) or not rows:
        raise RuntimeError("Could not create ingest run.")
    return rows[0]["id"]


def patch_rows(table_and_filter: str, body: dict[str, object]) -> None:
    rest_json("PATCH", table_and_filter, body, "return=minimal")


def finish_run(run_id: str, **fields: object) -> None:
    patch_rows(f"opportunity_ingest_runs?id=eq.{run_id}", {"finished_at": now_iso(), **fields})


def existing_source_jobs(source_id: str) -> dict[str, dict[str, object]]:
    query = query_string({
        "select": "id,external_key,source_content_hash,is_active",
        "source_id": f"eq.{source_id}", "limit": "1000",
    })
    rows = rest_json("GET", f"jobs?{query}")
    if not isinstance(rows, list):
        raise RuntimeError("Invalid jobs response.")
    return {row["external_key"]: row for row in rows if row.get("external_key")}


def latest_completed_run(source_id: str) -> dict[str, object] | None:
    query = query_string({
        "select": "id,parser_version,status",
        "source_id": f"eq.{source_id}",
        "status": "in.(succeeded,skipped)",
        "order": "started_at.desc", "limit": "1",
    })
    rows = rest_json("GET", f"opportunity_ingest_runs?{query}")
    return rows[0] if isinstance(rows, list) and rows else None


def latest_seen_keys(source_id: str) -> list[str]:
    query = query_string({
        "select": "id", "source_id": f"eq.{source_id}",
        "status": "eq.succeeded", "order": "started_at.desc", "limit": "1",
    })
    runs = rest_json("GET", f"opportunity_ingest_runs?{query}")
    if not isinstance(runs, list) or not runs:
        return []
    item_query = query_string({
        "select": "external_key", "run_id": f"eq.{runs[0]['id']}", "limit": "1000",
    })
    rows = rest_json("GET", f"opportunity_raw_items?{item_query}")
    return [row["external_key"] for row in rows] if isinstance(rows, list) else []


def public_payload(source_id: str, source: Source, item: Opportunity, user_id: str | None) -> dict[str, object]:
    _, score = validate_item(item)
    data: dict[str, object | None] = {
        "user_id": user_id, "type": item.job_type, "title": item.title,
        "organization": item.organization, "location": item.location,
        "instruments": item.instruments, "description": item.description,
        "requirements": item.requirements, "deadline": item.deadline,
        "contact": item.source_url, "is_active": True, "source": "curated",
        "city_id": item.city_id, "event_start": item.event_start,
        "video_audition": False, "application_fee": item.application_fee,
        "has_scholarship": item.has_scholarship, "status": item.status,
        "source_url": item.source_url, "application_url": item.source_url,
        "source_language": item.source_language, "last_seen_at": now_iso(),
        "review_status": "published", "source_id": source_id,
        "external_key": external_key(source, item),
        "source_content_hash": item_hash(item), "missing_runs": 0,
        "quality_score": score,
    }
    # PostgREST bulk inserts require every object to have the same keys. Keep
    # explicit nulls so mixed known/unknown deadlines can be upserted together.
    return dict(data)


def apply_source(
    source: Source,
    parser: Callable[[Source, str], list[Opportunity]],
    user_id: str | None,
    close_after: int,
) -> bool:
    record = load_source_record(source)
    source_id = str(record["id"])
    run_id = start_run(source_id)
    checked_at = now_iso()
    try:
        previous_run = latest_completed_run(source_id)
        parser_is_current = bool(previous_run and previous_run.get("parser_version") == PARSER_VERSION)
        fetched = fetch_page(
            source.url,
            record.get("etag") if parser_is_current else None,
            record.get("last_modified") if parser_is_current else None,
        )
        unchanged = parser_is_current and (fetched.status == 304 or (
            bool(fetched.content_hash) and fetched.content_hash == record.get("content_hash")
        ))
        if unchanged:
            seen_keys = latest_seen_keys(source_id)
            archived = 0
            if seen_keys:
                archived_result = rest_json("POST", "rpc/reconcile_opportunity_source", {
                    "p_source_id": source_id,
                    "p_seen_keys": seen_keys,
                    "p_close_after": close_after,
                }, "return=representation")
                archived = int(archived_result or 0)
            patch_rows(f"opportunity_sources?id=eq.{source_id}", {
                "etag": fetched.etag or record.get("etag"),
                "last_modified": fetched.last_modified or record.get("last_modified"),
                "last_checked_at": checked_at, "last_success_at": checked_at,
                "consecutive_failures": 0, "updated_at": checked_at,
            })
            finish_run(run_id, status="skipped", http_status=fetched.status,
                       content_hash=fetched.content_hash or record.get("content_hash"),
                       archived_count=archived)
            print(f"skipped  {source.slug}: unchanged, {archived} closed")
            return True

        text = fetched.text or ""
        parsed = parser(source, text)
        items, warnings = normalize_items(source, parsed)
        explicit_empty = explicit_empty_page(text)
        if not parsed and not explicit_empty:
            raise RuntimeError("Parser found zero rows and the page has no explicit empty-state marker.")

        existing = existing_source_jobs(source_id)
        active_before = sum(1 for row in existing.values() if row.get("is_active"))
        if active_before >= 4 and len(items) < math.ceil(active_before / 3) and not explicit_empty:
            raise RuntimeError(f"Suspicious result drop: {active_before} active rows to {len(items)}; publication stopped.")

        job_payloads = [public_payload(source_id, source, item, user_id) for item in items]
        raw_payloads = [{
            "source_id": source_id, "run_id": run_id,
            "external_key": external_key(source, item), "source_url": item.source_url,
            "content_hash": item_hash(item), "payload": item_document(item),
        } for item in items]
        if raw_payloads:
            rest_json("POST", "opportunity_raw_items", raw_payloads, "return=minimal")
        if job_payloads:
            rest_json("POST", "jobs?on_conflict=source_id,external_key", job_payloads,
                      "resolution=merge-duplicates,return=minimal")

        keys = [external_key(source, item) for item in items]
        archived_result = rest_json("POST", "rpc/reconcile_opportunity_source", {
            "p_source_id": source_id, "p_seen_keys": keys, "p_close_after": close_after,
        }, "return=representation")
        archived = int(archived_result or 0)
        inserted = sum(1 for key in keys if key not in existing)
        updated = len(keys) - inserted

        patch_rows(f"opportunity_sources?id=eq.{source_id}", {
            "etag": fetched.etag, "last_modified": fetched.last_modified,
            "content_hash": fetched.content_hash, "last_checked_at": checked_at,
            "last_success_at": checked_at, "consecutive_failures": 0,
            "updated_at": checked_at,
        })
        finish_run(run_id, status="succeeded", http_status=fetched.status,
                   content_hash=fetched.content_hash, found_count=len(items),
                   inserted_count=inserted, updated_count=updated,
                   archived_count=archived, warning_count=len(warnings))
        print(f"applied  {source.slug}: {inserted} inserted, {updated} updated, {archived} closed, {len(warnings)} warnings")
        for warning in warnings:
            print(f"  warning: {warning}", file=sys.stderr)
        return True
    except Exception as exc:
        failures = int(record.get("consecutive_failures") or 0) + 1
        try:
            patch_rows(f"opportunity_sources?id=eq.{source_id}", {
                "last_checked_at": checked_at, "consecutive_failures": failures,
                "updated_at": checked_at,
            })
            finish_run(run_id, status="failed", error_message=str(exc)[:1000])
        except Exception as audit_error:
            print(f"audit failure for {source.slug}: {audit_error}", file=sys.stderr)
        print(f"failed   {source.slug}: {exc}", file=sys.stderr)
        return False


def collect_preview(
    selected: list[tuple[Source, Callable[[Source, str], list[Opportunity]]]],
) -> tuple[list[tuple[Source, Opportunity]], bool]:
    collected: list[tuple[Source, Opportunity]] = []
    all_ok = True
    for source, parser in selected:
        try:
            fetched = fetch_page(source.url)
            parsed = parser(source, fetched.text or "")
            items, warnings = normalize_items(source, parsed)
            if not parsed and not explicit_empty_page(fetched.text or ""):
                raise RuntimeError("parser found zero rows")
            print(f"{source.slug}: {len(items)} valid of {len(parsed)} parsed", file=sys.stderr)
            for warning in warnings:
                print(f"  warning: {warning}", file=sys.stderr)
            collected.extend((source, item) for item in items)
        except Exception as exc:
            all_ok = False
            print(f"failed {source.slug}: {exc}", file=sys.stderr)
    return collected, all_ok


def select_sources(slugs: list[str] | None) -> list[tuple[Source, Callable[[Source, str], list[Opportunity]]]]:
    if not slugs:
        return SOURCES
    wanted = set(slugs)
    return [entry for entry in SOURCES if entry[0].slug in wanted]


def main() -> None:
    parser = argparse.ArgumentParser(description="Import official curated Jobs opportunities.")
    parser.add_argument("--apply", action="store_true", help="Validate and write to Supabase.")
    parser.add_argument("--json", action="store_true", help="Print normalized JSON; never writes.")
    parser.add_argument("--source", action="append",
                        choices=[source.slug for source, _ in SOURCES],
                        help="Run one source. May be repeated.")
    parser.add_argument("--close-after", type=int, default=3,
                        help="Close missing rows after this many successful changed runs (minimum 2).")
    args = parser.parse_args()
    if args.close_after < 2:
        parser.error("--close-after must be at least 2")

    selected = select_sources(args.source)
    if args.apply:
        user_id = curator_user_id()
        successes = [apply_source(source, source_parser, user_id, args.close_after)
                     for source, source_parser in selected]
        if not all(successes):
            raise SystemExit(1)
        return

    collected, all_ok = collect_preview(selected)
    collected.sort(key=lambda pair: (pair[1].deadline or "9999-12-31", pair[1].organization, pair[1].title))
    if args.json:
        output = [{
            "external_key": external_key(source, item),
            "quality_score": validate_item(item)[1], **item_document(item),
        } for source, item in collected]
        print(json.dumps(output, ensure_ascii=False, indent=2))
    else:
        for _, item in collected:
            print(f"preview  {item.title} | {item.deadline or 'deadline unknown'} | {', '.join(item.instruments)}")
    if not all_ok:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
