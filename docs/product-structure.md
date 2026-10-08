# Cadenza — 제품 구조 분석 (Android 이식 기준)

> 1단계 산출물. `ios/` 전체(Swift 17.5k LOC, 68개 파일)를 읽고 정리.
> 작성일: 2026-10-08 · 대상 모델: Opus 4.8

---

## 1. 앱 목적과 핵심 기능

**Cadenza**는 클래식 음악가(음대생·전문 연주자)를 위한 **커리어 네트워킹 + 포트폴리오** 앱이다.
한국–독일–유럽–미국을 잇는 클래식 음악 생태계를 타깃으로 하며, 3개 언어(한국어/영어/독일어)를 런타임 전환 지원한다.

핵심 기능 5가지:

| # | 기능 | 설명 |
|---|------|------|
| 1 | **활동 기록 (Activity)** | 연주·경연·교육·음반 4종 활동을 사진/링크 프리뷰와 함께 기록. 공개범위 설정, 참가자 태그, 기관(Org) 연결 |
| 2 | **소셜 피드 (Feed)** | 연결된 사람들의 활동 타임라인. 좋아요/댓글(대댓글)/저장/공유, 게시글 번역(Apple 온디바이스) |
| 3 | **프로필 / CV (Fermata)** | 경력·학력·수상·언어·추천서 관리. 다국어 CV 오버레이, 서버 렌더 PDF 내보내기, 공개 웹 프로필 |
| 4 | **기회 아카이브 (Jobs)** | 오디션/단원모집/레슨/연주의뢰 + 큐레이션된 콩쿠르·마스터클래스. 도시/악기/상태/비용 필터, 교차언어 검색 |
| 5 | **연결 (Connections)** | 양방향 연결(요청→수락), 추천 프로필(학교/도시 기반), 실시간 상태 동기화, 인앱 알림 |

---

## 2. 화면 목록과 네비게이션 흐름

### 2.1 앱 진입 분기 (`CadenzaApp.swift`)

```
콜드 런치
  └─ AppLandingView (스플래시 1.5초, 언어 선택 후에만)
       │
       ├─ languageChosen == false  → LanguagePickerView (최초 1회)
       ├─ session.isBootstrapping  → ProgressView
       ├─ session == nil           → AuthView (로그인/회원가입)
       ├─ needsOnboarding          → OnboardingView (8단계)
       └─ else                     → RootTabView (메인)
```

상태는 `SessionStore`(@Observable)가 보유하며 `.environment(session)`로 주입. 언어 변경 시 `.id(appLanguage)`로 전체 뷰 트리 리빌드.

### 2.2 메인 탭 (`RootTabView.swift`) — 5탭

| 탭 | 인덱스 | 화면 | 비고 |
|----|-------|------|------|
| 피드 | 0 | `FeedView` | 홈. 알림 배지, 생성 진입점 |
| 알림 | 1 | `NotificationsView` | 배지 = 읽지않은 알림 + 연결 요청 대기 |
| 기록 | 2 | (액션) | 탭 시 `CreateActivityView` 시트 — 네비게이션 아님 |
| 기회 | 3 | `JobsView` | Jobs 목록/검색/필터 |
| 프로필 | 4 | `ProfileView` | 내 프로필 |

- 같은 탭 재탭 → 최상단 스크롤(`scrollToTopRevision`).
- 앱 활성화 시 연결/배지 새로고침 + Realtime 구독 시작.

### 2.3 온보딩 (`OnboardingCoordinator`, 8단계)

각 단계는 **즉시 서버 저장**(중단 후 재개 가능). Step 4–7은 건너뛰기 가능.

1. Consent(동의) → 2. 전공·악기 → 3. 소속(학교/과정/입학년도)+활동도시 → 4. 사사(교사) → 5. 프로필(소개·아바타) → 6. 활동 샘플 → 7. 연락처(오픈인 UI만, 실제 접근 없음) → 8. 공개범위 설정 → 완료

### 2.4 주요 하위 화면 (모달/푸시)

- **Activity**: CreateActivityView, EditActivityView, ImageViewerSheet, InstagramImportView
- **Feed**: CommentsSheet, LinkPreview
- **Profile**: PublicProfileView, EditProfileView, ProfileSettingsView, ProfileActivitiesView, ConnectionsListView
  - **CV**: CVEditorView, CVEntryComposerView, CVEntryOverrideView, MultilingualProfileEditorView
  - **Sheets**: Bio/Career/Affiliation/Award/Language/Recommendation/CvWebsite 편집, AddProfileSection
- **Jobs**: JobsView, JobDetailView, CreateJobView, JobFilter(필터 상태)
- **Org**: OrgPageView, CreateOrgView
- **Confirm**: ConfirmInboxView(참가자 승인함)
- **Privacy**: PrivacyPolicyView, TermsOfServiceView, DataPrivacySettingsView
- **Auth**: AuthView, LanguagePickerView

---

## 3. 데이터 모델 / API 구조 / 로컬 저장

### 3.1 데이터 모델 (`Models.swift`, 1006 LOC)

핵심 엔티티(모두 Codable, snake_case ↔ camelCase 매핑):

- **Profile** — 사용자 프로필 + Fermata CV 필드(name_en, eyebrow, birth_date, phone, address, repertoire, profile_langs)
- **Activity / ActivityWithAuthor** — 활동. 링크 프리뷰(OG) 필드 포함. 작성자/기관 조인 투영
- **Job / City** — 기회. 큐레이션 메타(source, city_id, zone, 비용, 장학금, 나이, 상태, source_url 등)
- **Organization / OrgSummary** — 기관(오케스트라/학교/레이블/공연장/에이전시)
- **Career / Affiliation / ProfileAward / ProfileLanguage / Recommendation** — 프로필 섹션
- **CVEntryRow / CVOverride** — CV 전용 항목 + 언어별 i18n 오버레이
- **Connection(ConnectionRecord/ConnectedProfile/SuggestedProfile)** — follows 테이블 기반
- **ActivityComment / ActivityStats** — 댓글(대댓글), 좋아요/댓글수/저장 집계
- **AppNotification** — 인앱 알림(like/comment/follow/tag)

열거형: JobType, OrgCategory, ActivityType, Visibility(4단계), VerificationStatus, ConfirmStatus, ConnectionStatus, ProfileSection

### 3.2 백엔드 = Supabase (`Repository.swift`, 1471 LOC)

단일 `Repository` struct가 모든 네트워크를 담당. 5가지 Supabase 기능 사용:

**(a) PostgREST 테이블** — profiles, activities, jobs, organizations, careers, affiliations, profile_awards, profile_languages, recommendations, follows, activity_likes/comments/saves/tags/participants, comment_likes, notifications, org_admins/org_follows, cv_entries, cv_i18n, city, user_base_city, lineage

**(b) RPC 함수** (서버 로직 캡슐화 — 이식 시 그대로 호출):
`social_feed`, `transition_connection`, `connection_count`, `get_connections`, `get_suggested_profiles`, `get_comments`, `activity_stats`, `search_opportunities`, `delete_my_account`

**(c) Edge Functions** (Deno/TS):
- `cv-export` — CV JSON 어셈블리 → PDF 렌더(Fly.io render-service)/캐시 → signed URL
- `cv-translate` — 한국어 CV 필드 → 영어 번역 제안(Claude Messages API)
- `instagram-import` — 인스타 URL → 캡션/썸네일 추출 (현재 대기, Facebook 토큰 필요)

**(d) Storage 버킷**: `avatars`, `activity-images`, `user-files`(CV PDF). RLS: 경로 prefix = auth.uid()

**(e) Realtime**: `follows`(수신/발신) + `notifications` postgres change 구독 + 8초 폴링 폴백 (`observeConnectionChanges`)

**(f) Auth**: 이메일/비번, Google OAuth, Apple Sign In. 딥링크 `cadenza://auth-callback`

### 3.3 로컬 저장

- **UserDefaults / @AppStorage**: `appLanguage`, `languageChosen`, `AppleLanguages`(OS 포매터용)
- **Core Data / SQLite 없음** — 영속 캐시 없이 매번 서버 조회. (오프라인 미지원)
- **폼 드래프트 자동저장**: 긴 폼은 작성 중 손실 방지 필수 (프로젝트 메모리 피드백 반영). iOS는 ActivityDraft 등으로 처리

### 3.4 서버 측 보안

공개범위(Visibility)·RLS·피드 가시성은 **전부 서버(PostgreSQL RLS + RPC)에서 강제**. 클라이언트는 UI 표현만 담당 → Android에서도 동일 백엔드 재사용하므로 보안 로직 재구현 불필요(이식 리스크 낮춤).

---

## 4. 외부 라이브러리 / SDK

| 종류 | 라이브러리 | 용도 | Android 대응 |
|------|-----------|------|--------------|
| 유일한 서드파티 | **supabase-swift** (2.0+) | Auth/PostgREST/Realtime/Storage/Functions | **supabase-kt** (Kotlin Multiplatform, Ktor 기반) |
| Apple | SwiftUI | UI | Jetpack Compose |
| Apple | PhotosUI (`PhotosPicker`) | 이미지 선택 | Photo Picker (`ActivityResultContracts.PickVisualMedia`) |
| Apple | AuthenticationServices | Apple Sign In | 웹 OAuth 플로우 (Custom Tabs) |
| Apple | **Translation** + `_Translation_SwiftUI` | 피드 게시글 온디바이스 번역 | ⚠️ ML Kit Translate / 시스템 번역 인텐트 |
| Apple | UniformTypeIdentifiers | 파일 타입 | MIME 타입 |
| Apple | ShareLink / `openURL` | 공유/외부링크 | `Intent.ACTION_SEND` / Custom Tabs |

> 서드파티 의존성이 **supabase 하나뿐**이라 이식 표면이 작다. 나머지는 모두 Apple 1st-party 프레임워크 → 각 Android 네이티브로 대체.

---

## 5. 플랫폼 전용 기능과 Android 대응

| iOS 기능 | 현재 구현 | Android 대응 방안 | 난이도 |
|----------|-----------|-------------------|--------|
| **로그인** | 이메일/비번 + Google OAuth + Apple Sign In (Supabase) | supabase-kt Auth 동일. Google=Credential Manager, Apple=웹 OAuth(Custom Tabs) | 중 |
| **딥링크** | `cadenza://auth-callback` | Android App Links / intent-filter + scheme | 하 |
| **이미지 선택** | PhotosPicker (다중) | Photo Picker API | 하 |
| **카메라 권한** | Info.plist(포스터/티켓 촬영) | runtime permission `CAMERA` | 하 |
| **연락처 권한** | Info.plist만 — **실제 접근 없음**(opt-in UI) | 권한 선언 불필요. UI만 이식 | 하 |
| **게시글 번역** | Apple Translation(온디바이스) + 시스템 번역 시트 | ML Kit On-Device Translation 또는 번역 인텐트 | **중상** |
| **런타임 언어 전환** | Bundle ISA 스위즐링(`LanguageBundle`) | per-app language (`AppCompatDelegate.setApplicationLocales`) + Compose locale | 중 |
| **공유** | ShareLink | `Intent.ACTION_SEND` | 하 |
| **외부 링크** | `openURL` | Custom Tabs / `ACTION_VIEW` | 하 |
| **CV PDF 내보내기** | 서버(Edge Function + Fly.io)가 렌더 | 동일 함수 호출 → signed URL 다운로드/공유 | 하 |
| **실시간 동기화** | Supabase Realtime 구독 | supabase-kt Realtime | 중 |
| **푸시 알림** | ❌ **없음** (인앱 알림만, DB 조회) | (선택) FCM 신규 도입 가능 — v1 제외 권장 | — |
| **인앱 결제** | ❌ 없음 | — | — |
| **iPad 적응형 레이아웃** | `adaptiveContentWidth`(준비됨) | 태블릿/폴더블 반응형(WindowSizeClass) | 중 |

---

## 6. 이식 난이도가 높은 부분과 리스크

### 🔴 높음
1. **Apple Translation 프레임워크** — 피드 게시글 번역. Android 직접 대응 없음. ML Kit 번역(모델 다운로드 필요) 또는 시스템 번역 인텐트로 대체 설계 필요. UX 차이 발생 가능 → **구현 전 질문 대상**.
2. **런타임 언어 전환(ko/en/de)** — iOS는 Bundle 스위즐링으로 즉시 전환. Android는 `setApplicationLocales` + Activity 재생성 패턴. 356개 문자열 키 + 3언어 + 코드 내 `localized(ko,en,de)` 인라인 호출을 strings.xml 리소스로 체계화 필요. 전공/악기/도시/학교 등 **대량 로컬라이즈드 옵션 테이블**(OnboardingData)도 이관.

### 🟡 중간
3. **Apple Sign In** — Android에서는 웹 기반 OAuth. Supabase가 중개하나 리다이렉트/Custom Tabs 플로우 구성 필요.
4. **상태 관리 패러다임 전환** — `@Observable`/`@Environment` → Compose `StateFlow` + ViewModel + Hilt. 기계적이나 전 화면 영향.
5. **Realtime + 8초 폴링 폴백** — `observeConnectionChanges`의 TaskGroup 동시성 로직을 Kotlin coroutine/Flow로 재구현.
6. **복잡한 화면**: FeedView(1340 LOC, 번역/인터랙션), ProfileView(1061), CreateActivityView(808, 다중 이미지 업로드 조정). → Opus 권장.
7. **오프라인/캐시 부재** → Android는 Room 도입 기회(선택). v1은 iOS와 동일하게 온라인 전제 가능.

### 🟢 낮음 (서버 공유로 리스크 흡수)
8. 모든 비즈니스 로직·RLS·RPC·Edge Function·Storage가 **서버에 있어 재사용** → 데이터 계층은 매핑 작업 위주.
9. PostgREST numeric 직렬화 이슈는 이미 서버에서 float8로 수정됨(0042). Kotlin Double 디코딩 안전.
10. CV PDF 렌더가 서버측 → 클라이언트는 호출+다운로드만.

### ⚠️ 설정/운영
- `AppConfig.swift`에 **Supabase anon key 하드코딩** → Android도 동일 프로젝트 사용. anon key는 공개 가능하나, BuildConfig/로컬 설정으로 분리 권장.
- 번들 ID `com.cadenza.app` → Android `applicationId` 별도 지정.
- 지원 언어 `ko, en, de`, 개발 기본 언어 `ko`.

---

## 7. 요약: Android 이식 관점 핵심

- **의존성 단순**: 서드파티는 supabase-swift 1개 → supabase-kt로 1:1 대체, 백엔드 완전 재사용.
- **서버 중심 설계**: 보안/피드/CV렌더/검색이 서버에 있어 클라이언트 이식 리스크가 구조적으로 낮음.
- **진짜 난관 2가지**: ① 다국어 런타임 전환 체계, ② Apple Translation 대체.
- **플랫폼 미사용**: 푸시/결제 없음 → v1 범위 축소 가능.
- 다음 단계(2단계)에서 이 분석을 로드맵으로 구체화.
</content>
