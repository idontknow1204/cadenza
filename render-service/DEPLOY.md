# render-service 배포 가이드

PDF 렌더러(WeasyPrint)를 호스팅하고, Supabase `cv-export` Edge Function 을 연결하는 순서.
DB 마이그레이션(0030~0032)은 **이미 프로덕션에 적용됨**. 남은 건 렌더러 호스팅 + 함수 연결.

전제: 아래에서 `RENDER_TOKEN` 은 아무 랜덤 시크릿 하나를 정해 **render-service 와 Supabase 함수 양쪽에 같은 값**으로 넣는다.
```bash
RENDER_TOKEN=$(openssl rand -hex 24)   # 이 값을 메모
```

---

## A. 렌더러 호스팅 — 택1

### 옵션 1) Fly.io  (권장, fly.toml 준비됨)
```bash
cd render-service
fly launch --no-deploy            # 최초 1회: 앱 생성 (fly.toml 의 app 이름 확인/수정)
fly secrets set \
  SUPABASE_URL=https://vcxllrzpolymzylrfscb.supabase.co \
  SUPABASE_ANON_KEY=<anon key> \
  RENDER_TOKEN=$RENDER_TOKEN
fly deploy
fly status                        # 공개 URL 확인 → 예: https://fermata-render.fly.dev
```

### 옵션 2) Google Cloud Run
```bash
cd render-service
gcloud run deploy fermata-render \
  --source . --port 8080 --region europe-west1 \
  --allow-unauthenticated \
  --memory 1Gi \
  --set-env-vars SUPABASE_URL=https://vcxllrzpolymzylrfscb.supabase.co,SUPABASE_ANON_KEY=<anon key>,RENDER_TOKEN=$RENDER_TOKEN
# 출력된 Service URL 확인 → 예: https://fermata-render-xxxx.a.run.app
```

### 배포 확인
```bash
curl -s https://<RENDER_URL>/healthz            # {"ok":true}
curl -s https://<RENDER_URL>/p/<어느 slug>        # 공개 웹 프로필 HTML
```

---

## B. Edge Function 연결
`SUPABASE_URL/ANON_KEY/SERVICE_ROLE_KEY` 는 Edge Function 에 자동 주입되므로,
**렌더러 URL 과 토큰만** 시크릿으로 넣으면 된다.
```bash
supabase secrets set \
  RENDER_SERVICE_URL=https://<RENDER_URL> \
  RENDER_TOKEN=$RENDER_TOKEN          # A 에서 쓴 값과 동일
supabase functions deploy cv-export
```

---

## C. 최종 확인 (앱에서)
프로필 → 설정 → **CV / 이력서** → 항목 영어화 몇 개 확정 → **PDF 내보내기** → signed URL 로 PDF 열림.

## 참고
- `cv/{slug}/{cv_version}.pdf` 로 캐시됨. `activities/affiliations/lineage` 변경 시 `cv_version` 이 올라 자동 무효화.
- 공개 웹 프로필(`fermata.app/p/{slug}`) 을 붙이려면 도메인 → `<RENDER_URL>/p/{slug}` 로 라우팅.
- WeasyPrint 메모리 부족(OOM) 시 Fly `memory` 를 1gb 이상으로.
