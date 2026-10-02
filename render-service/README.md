# Fermata CV / Profile — render-service

클래식 음악가 CV를 **에디토리얼 A4 PDF** 와 **공개 웹 프로필** 로 렌더링하는 코어.
템플릿 한 벌(`templates/cv.html.j2`)이 두 출력을 공유한다.

## 진실원천
- `DESIGN_GUIDE.md` 가 **유일한 수치 기준**이다. 템플릿의 `:root` 토큰은 이 문서(§2~§5)를 그대로 옮긴 것.
  값을 바꿀 땐 가이드 → 토큰 순으로 바꾼다. 템플릿 본문에 임의 수치를 넣지 않는다.
- 포맷은 **에디토리얼 1종·영어 단일** 로 고정 (가이드 확정사항).

## 구조
```
templates/cv.html.j2      섹션별 레이아웃 매크로 5종 + 헤더 + @page/@media
schema/cv_data.schema.json  렌더러 입력 계약(canonical JSON)
schema/cv_data.example.json 샘플 데이터
render.py                 build_html() / to_pdf() / CLI
fonts/                    Pretendard*, IBMPlexMono*  (아래 참조)
```

## 섹션 레이아웃 (가이드 §7)
| kind        | layout        | 표현 |
|-------------|---------------|------|
| performance | `year_group`  | 연도를 그룹 헤더로 묶고 곡명 중심 |
| competition | `result_list` | 결과 우측 정렬·강조 |
| education   | `stack_edu`   | 기관명 크게 + 학위/사사 별도 줄 |
| masterclass | `two_up`      | 한 줄에 두 건 |
| repertoire  | `inline`      | 구분점 연결 |

섹션 **순서와 레이아웃은 데이터 주도** — `sections` 배열 순서가 곧 출력 순서.

## Supabase 데이터 매핑 (Phase 1 Edge Function이 조립)
| canonical JSON        | 원본 |
|-----------------------|------|
| `person.*`            | `profiles` (real_name, instrument, avatar_url, home_city…) |
| `sections[].entries[]`| `activities` (type, title, activity_date, location, organizer, prize, program) |
| `entries[].result`    | `activities.prize` |
| `entries[].year`      | `extract(year from activities.activity_date)` |
| `entries[].teacher`   | `lineage` (사사) |
| `entries[].verification` | `verification_status`: institution_verified→`institution`, peer_confirmed→`peer`, pending→`null` |

## 실행
```bash
python3 render.py schema/cv_data.example.json out.pdf   # HTML+PDF 동시 출력
```
- `build_html(data)` 는 Jinja2만 필요 (웹 SSR 경로).
- `to_pdf(html)` 만 WeasyPrint(+시스템 라이브러리) 필요 — 지연 import.

## 폰트 (필수)
`fonts/` 에 아래 파일을 넣어야 활자가 가이드대로 나온다. 없으면 시스템 폰트로 폴백된다.
- `Pretendard-Light.otf` / `-Regular` / `-Medium` / `-SemiBold`
- `IBMPlexMono-Regular.ttf` / `-Medium`
> 라이선스: Pretendard(OFL), IBM Plex(OFL) — 컨테이너 이미지에 동봉 배포 가능.

## HTTP 서비스 (app.py)
| 라우트 | 용도 |
|--------|------|
| `GET /healthz` | 헬스체크 |
| `GET /p/{slug}` | 공개 웹 프로필 HTML (Supabase `cv_data_by_slug` → build_html) |
| `GET /p/{slug}.pdf` | 공개 프로필 PDF |
| `POST /render` | canonical JSON → PDF. Edge Function 전용, `x-render-token` 헤더로 보호 |

### 환경변수
| 변수 | 설명 |
|------|------|
| `SUPABASE_URL` | 예: `https://xxx.supabase.co` (로컬은 `http://host.docker.internal:54321`) |
| `SUPABASE_ANON_KEY` | 웹 프로필 RPC 호출용 (리댁션된 공개 데이터만) |
| `RENDER_TOKEN` | `POST /render` 공유 시크릿 (Edge Function 과 동일 값) |

### 로컬 실행
```bash
docker build -t fermata-render:dev .
docker run -d --name fermata-render -p 8899:8080 \
  -e RENDER_TOKEN=devtoken \
  -e SUPABASE_URL=http://host.docker.internal:54321 \
  -e SUPABASE_ANON_KEY=<anon> \
  --add-host host.docker.internal:host-gateway \
  fermata-render:dev
curl -X POST localhost:8899/render -H "x-render-token: devtoken" \
  -H "Content-Type: application/json" -d @schema/cv_data.example.json -o cv.pdf
```
> WeasyPrint 62.3 은 **pydyf==0.10.0** 과만 호환 (0.11 은 Stream.transform 제거) — requirements 에 고정.

## Edge Function 연동 (supabase/functions/cv-export)
`POST` → `profiles.slug/cv_version` 로 캐시키 `cv/{slug}/{cv_version}.pdf` 확인 →
미스면 `cv_data(uid,false)` 조립 → `POST {RENDER_SERVICE_URL}/render` → Storage 업로드 → signed URL.
필요 env: `RENDER_SERVICE_URL`, `RENDER_TOKEN`, `SUPABASE_SERVICE_ROLE_KEY`. 버킷 `cv`(비공개)는 migration 0032.

## 다음 단계
- Cloud Run/Fly 배포 + `RENDER_SERVICE_URL` 로 Edge Function 연결 (edge→service 네트워킹)
- CV 편집 UI (name_en / cv_i18n patch·include / repertoire)
- 폰트 라이선스 고지 (Pretendard·IBM Plex, OFL — 이미지 동봉 OK)
