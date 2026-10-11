# Cadenza — Android 이식 로드맵

> 2단계 산출물. `docs/product-structure.md` 분석을 실행 계획으로 구체화.
> 작성일: 2026-10-08 · 대상 모델: Opus 4.8

---

## 1. 기술 스택 확정안

| 영역 | 선택 | 근거 |
|------|------|------|
| 언어 | **Kotlin** (2.0+) | 요구사항 |
| UI | **Jetpack Compose + Material 3** | 요구사항. SwiftUI와 선언형 패러다임 유사 → 화면 이식 매핑 용이 |
| 아키텍처 | **MVVM + Repository** | iOS의 `Repository` struct + `@Observable` store 구조와 1:1 대응 |
| DI | **Hilt** | 요구사항. ViewModel/Repository/SupabaseClient 주입 |
| 네트워크/백엔드 | **supabase-kt** (Ktor 엔진) | iOS supabase-swift와 동일 백엔드 1:1 대체. Auth/Postgrest/Realtime/Storage/Functions 모듈 |
| 로컬 DB | **Room** (선택적) | iOS는 캐시 없음. v1은 최소 사용(드래프트 자동저장 등), 오프라인 캐시는 후순위 |
| 비동기 | **Coroutines + Flow / StateFlow** | iOS async/await + @Observable 대응 |
| 이미지 로딩 | **Coil 3** | AsyncImage 대응 |
| 직렬화 | **kotlinx.serialization** | supabase-kt 기본. snake_case ↔ camelCase 매핑 |
| 다국어 | **strings.xml (ko/en/de)** + `AppCompatDelegate.setApplicationLocales` | 런타임 언어 전환 |
| 번역 | **ML Kit Translation** 또는 시스템 번역 인텐트 (§6 결정 필요) | Apple Translation 대체 |
| 최소 SDK | **API 26 (Android 8.0)** | supabase-kt/Compose/Coil 안정 지원 하한. 국내외 음악가층 구형기기 고려 시 상향 가능 |
| 타겟 SDK | **API 35 (Android 15)** | Play Store 최신 요건 |
| 빌드 | **Gradle (Kotlin DSL) + Version Catalog** | — |

### SwiftUI → Compose 개념 매핑 (이식 사전)

| iOS | Android |
|-----|---------|
| `@Observable class Store` | `ViewModel` + `StateFlow<UiState>` |
| `.environment(session)` | Hilt 주입 + `CompositionLocal` |
| `Repository` struct | `@Singleton Repository` 클래스 |
| `NavigationStack` / `.sheet` | Navigation Compose + `ModalBottomSheet` |
| `TabView` | `NavigationBar` (Material 3) + nested nav |
| `AsyncImage` | Coil `AsyncImage` |
| `PhotosPicker` | `rememberLauncherForActivityResult(PickVisualMedia)` |
| `@AppStorage` | DataStore Preferences |
| `Codable` + CodingKeys | `@Serializable` + `@SerialName` |

---

## 2. 이식 단계 분할

이식은 **뼈대 → 데이터 → 화면 → 플랫폼 → 마무리** 순서. 각 단계는 **빌드 가능 상태**로 종료.

### 3단계: 프로젝트 뼈대
- **범위**: Gradle(KTS)+Version Catalog, 모듈 구조, Hilt 설정, supabase-kt 클라이언트(AppConfig 상당), DataStore, Material 3 테마(BrandGold/BrandSurface/AccentColor 컬러 이관), 폰트, 앱 아이콘, 5탭 빈 스캐폴드 네비게이션, strings.xml 3언어 골격
- **완료 기준**: 빈 5탭이 뜨고 언어 리소스가 로드되는 디버그 APK 빌드·실행
- **난이도**: 중 / **모델**: Sonnet 4.6

### 4단계: 데이터 계층
- **범위**: 전 데이터 모델을 `@Serializable`로 이관(Models.swift 1006 LOC), `Repository`의 모든 쿼리/RPC/Edge Function/Storage 호출 포팅(1471 LOC), SessionStore/ConnectionStore → ViewModel+StateFlow, 인증 플로우(이메일/비번 먼저), OnboardingData 룩업 테이블
- **완료 기준**: 로그인 → 프로필 조회 → 피드 RPC 호출이 실제 Supabase에서 성공(로그로 검증). UI는 최소
- **난이도**: 중 / **모델**: Sonnet 4.6

### 5단계: 화면 단위 이식
우선순위 순. 각 화면 완료 시 빌드·스모크 확인.

| 묶음 | 화면 | 난이도 | 모델 |
|------|------|--------|------|
| 5a | Auth / LanguagePicker | 중 | Sonnet |
| 5b | Onboarding 8단계 | 중 | Sonnet |
| 5c | RootTab 네비게이션 확정 | 하 | Sonnet |
| 5d | **Feed** (피드/댓글/링크프리뷰, 번역 제외) | **상** | **Opus** |
| 5e | Profile + CV 에디터 + 섹션 시트들 | 상 | Opus(핵심)/Sonnet(시트 반복) |
| 5f | Activity 생성/편집(다중 이미지) | 상 | Opus |
| 5g | Jobs 목록/상세/생성/필터 | 중 | Sonnet |
| 5h | Notifications / Confirm / Connections | 중 | Sonnet |
| 5i | Org 페이지/생성 | 하 | Sonnet |
| 5j | Privacy/Terms/Settings | 하 | Haiku/Sonnet |

- **완료 기준(묶음별)**: iOS와 기능 동일, Material 3 가이드 준수, 실 데이터로 동작
- **난이도**: 혼합

### 6단계: 플랫폼 전용 기능
- **범위**: Google 로그인(Supabase OAuth + PKCE), Apple Sign In(웹 OAuth), 딥링크(`cadenza://auth-callback` + App Links), 이미지 업로드/Storage 권한, 게시글 번역(§6 결정안 구현), 공유(ACTION_SEND), 외부링크(Custom Tabs), CV PDF 다운로드/공유
- **완료 기준**: 소셜 로그인·번역·공유가 실기기에서 동작
- **난이도**: 상 / **모델**: Opus 4.8

### 7단계: 빌드 에러 수정 · QA · 체크리스트
- **범위**: 경고/크래시 수정, 다국어 QA, 반응형(폴더블/태블릿) 점검, 접근성
- **난이도**: 하~중 / **모델**: Haiku 4.5(단순) / Sonnet 4.6

### 8단계: 최종 리뷰 · iOS 기능 동일성 검증
- **범위**: iOS와 화면별 기능 대조표 작성·검증, 릴리스 빌드, Play Console 준비
- **난이도**: 중 / **모델**: Opus 4.8

---

## 3. 단계별 추천 모델 요약

| 단계 | 작업 | 모델 |
|------|------|------|
| 3 | 프로젝트 뼈대 | Sonnet 4.6 |
| 4 | 데이터 계층 | Sonnet 4.6 |
| 5 | 일반 화면 이식 | Sonnet 4.6 |
| 5d/5e/5f | 복잡 화면(Feed/Profile/Activity) | Opus 4.8 |
| 5j | 정적 화면(약관 등) | Haiku 4.5 |
| 6 | 플랫폼 전용(로그인/번역/공유) | Opus 4.8 |
| 7 | 빌드수정·QA | Haiku 4.5 / Sonnet 4.6 |
| 8 | 최종 리뷰·동일성 검증 | Opus 4.8 |

> 실제 모델명 매핑: Sonnet 4.6 = claude-sonnet-4-6, Opus 4.8 = claude-opus-4-8, Haiku 4.5 = claude-haiku-4-5. (사용자가 지정한 "5.5/5.1"은 현존하지 않아 상응 모델로 대체)

---

## 4. v1 출시 범위 (확정)

**결정: 전체 기능을 v1에 한 번에 이식** (2026-10-08 사용자 확정).
iOS의 모든 화면·기능을 동일하게 포팅한다. QA 부담이 크므로 7단계(QA)와 8단계(동일성 검증)를 충실히 수행한다.

### v1 포함 (iOS 전 기능)
- 인증: 이메일/비번 + **Google** (Apple Sign In은 후순위 — §5 D2)
- 온보딩 8단계
- 피드(좋아요/댓글/저장/공유) + **게시글 번역(ML Kit 온디바이스, v1 포함)**
- 활동 생성/편집(다중 이미지)
- 프로필 조회/편집 + 전 CV 섹션 + 다국어 오버레이 + PDF 내보내기
- Jobs 목록/상세/필터/검색(교차언어)
- 알림 · 연결(요청/수락/추천) · Confirm 승인함
- Org 페이지 조회 **및 생성**
- Privacy/Terms/Settings

### v1 제외 (양 플랫폼 공통 보류)
- **Apple Sign In** — 웹 OAuth 복잡도로 후순위. Google로 소셜 로그인 충족 (D2)
- **Instagram 가져오기** — iOS도 대기 상태(Facebook App Token 필요). 토큰 확보 시 양 플랫폼 동시 복구
- **푸시 알림** — iOS에도 없음. 신규 기능이므로 별도 과제
- **본격 오프라인 캐시** — 드래프트 자동저장만 v1, 전면 캐시는 후순위 (D5)

---

## 5. 결정 사항 (확정됨 — 2026-10-08)

| # | 결정 사항 | 확정 |
|---|-----------|------|
| D1 | **게시글 번역** | ✅ **ML Kit 온디바이스, v1 포함** (언어 모델 다운로드 방식) |
| D2 | **Apple Sign In** | ✅ **후순위** — v1은 이메일/비번 + Google OAuth(PKCE) |
| D3 | **최소 SDK** | ✅ **API 26** |
| D4 | **v1 범위** | ✅ **전체 한 번에** (iOS 전 기능) |
| D5 | **오프라인 캐시(Room)** | ✅ **최소** — 드래프트 자동저장 등에만, 전면 캐시는 후순위 |
| D6 | **패키지명/앱ID** | ✅ **`com.cadenza.android`** (iOS `com.cadenza.app`와 구분, 변경 가능) |
| D7 | **Supabase 설정 분리** | ✅ anon key를 `BuildConfig`(gradle.properties)로 분리 |
| D8 | **디자인 기준** | ✅ **Material 3 네이티브 우선** (기능 동일, UI는 M3 가이드) |
| D9 | **푸시 알림** | ✅ **도입 안 함** (iOS와 동일, 인앱 알림만) |

> D1·D2·D4는 사용자 직접 결정. D3·D5~D9는 권장 기본값으로 확정 — 해당 단계 착수 전 조정 가능.

---

## 6. 다음 행동

1. ✅ 결정 사항 확정 완료
2. **3단계(프로젝트 뼈대)** 착수 — 모델 **Sonnet 4.6**로 전환 권장
3. 각 단계 완료 시 `CLAUDE.md` 체크리스트 갱신
</content>
