# Cadenza — Android 이식 작업 가이드

## 저장소 구조

```
/
├── ios/          # 원본 iOS(SwiftUI) 앱 — 수정 금지
├── android/      # Android(Kotlin+Compose) 이식 작업
├── supabase/     # 공유: DB 마이그레이션, Edge Functions
├── render-service/ # 공유: CV PDF 렌더 서버
├── scripts/      # 공유: 데이터 파이프라인
└── docs/         # 설계 문서 및 이식 산출물
```

## 확정된 기술 스택 (Android)

| 영역 | 라이브러리 |
|------|-----------|
| UI | Jetpack Compose + Material 3 |
| 아키텍처 | MVVM + Repository |
| DI | Hilt |
| 로컬 DB | Room |
| 네트워크 | supabase-kt (Ktor 엔진) |
| 인증 | supabase-kt Auth — 이메일/비번 + Google(Credential Manager). Apple은 후순위 |
| 직렬화 | kotlinx.serialization |
| 비동기 | Coroutines + Flow/StateFlow |
| 이미지 | Coil 3 |
| 번역 | ML Kit 온디바이스 번역 (피드 게시글, v1 포함) |
| 최소 SDK | API 26 (Android 8.0) |
| 타겟 SDK | API 35 |
| appId | `com.cadenza.android` |

v1 범위: **iOS 전 기능 한 번에 이식**. 제외: Apple Sign In(후순위), Instagram 가져오기(토큰 대기), 푸시 알림(미도입), 전면 오프라인 캐시(후순위).
자세한 내용: `docs/android-roadmap.md`, `docs/product-structure.md`

## 이식 규칙

1. iOS 코드(`ios/`) 수정 금지
2. 화면은 하나씩 이식
3. 기능은 iOS와 동일하게, UI는 Material 3 가이드 기준으로 조정
4. iOS 전용 API 중 대체 불명확한 것은 구현 전 질문
5. 각 단계 완료 시 이 파일의 체크리스트 갱신

## 단계별 추천 모델

| 단계 | 작업 | 추천 모델 |
|------|------|-----------|
| 0 | 저장소 정리 | Sonnet 4.6 |
| 1 | 제품 구조 파악 | Opus 4.8 |
| 2 | 로드맵 작성 | Opus 4.8 |
| 3 | 프로젝트 뼈대 | Sonnet 4.6 |
| 4 | 데이터 계층 | Sonnet 4.6 |
| 5 | 화면 이식 (일반) | Sonnet 4.6 |
| 5 | 화면 이식 (복잡한 애니메이션/제스처) | Opus 4.8 |
| 6 | 플랫폼 전용 기능 (결제, 푸시, 로그인) | Opus 4.8 |
| 7 | 빌드 에러 수정, 반복 작업 | Haiku 4.5 |
| 8 | 최종 리뷰, iOS 기능 동일성 검증 | Opus 4.8 |

## 이식 진행 현황

- [x] **0단계**: 저장소 정리 (ios/ 이동, android/ 생성)
- [x] **1단계**: 제품 구조 파악 → `docs/product-structure.md`
- [x] **2단계**: 로드맵 작성 + 결정사항 확정 → `docs/android-roadmap.md`
- [x] **3단계**: 프로젝트 뼈대 (Gradle KTS+VersionCatalog, Hilt, supabase-kt, M3 테마, 5탭 스캐폴드, strings 3언어)
- [x] **4단계**: 데이터 계층 (Models, Repository, Supabase 연동)
- [ ] **5단계**: 화면 이식
  - [x] Auth / Onboarding (LanguagePicker, AuthScreen, OnboardingScreen 1–8단계, AppNavigation)
  - [x] Root Tab Navigation
  - [x] Feed (FeedScreen, FeedViewModel, ActivityCard, CommentsSheet, LinkPreviewCard, ImageViewerDialog, ML Kit 번역, 검색)
  - [x] Profile (ProfileScreen, PublicProfileScreen, ProfileViewModel, PublicProfileViewModel, SectionCard, ActivityPagerCard, CareerRow, AffiliationRow, RecommendationRow, 편집 시트 일체)
  - [x] Jobs (JobsScreen, JobsViewModel, JobDetailSheet, CreateJobSheet, JobFilterSheet)
  - [x] Notifications (NotificationsScreen, NotificationsViewModel)
  - [x] Connections (ConnectionsListSheet, ProfileScreen·PublicProfileScreen 연동)
  - [ ] Org
  - [ ] CV Editor
  - [ ] Settings / Privacy
- [ ] **6단계**: 플랫폼 전용 기능
  - [ ] 푸시 알림 (FCM)
  - [ ] 이미지 업로드 / 스토리지
  - [ ] 딥링크
- [ ] **7단계**: 빌드 에러 수정 및 QA
- [ ] **8단계**: 최종 리뷰, iOS 기능 동일성 검증

## Android에 반영 필요한 iOS 변경사항

<!-- iOS 업데이트 후 Android에 적용해야 할 사항을 여기에 기록 -->
| iOS 변경 | 반영 여부 | 메모 |
|---------|----------|------|
| (없음) | - | - |
