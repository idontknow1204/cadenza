# Cadenza

클래식 음악가를 위한 커리어 네트워킹 앱.

## 플랫폼

| 디렉터리 | 플랫폼 | 기술 스택 |
|----------|--------|-----------|
| `ios/` | iOS 17+ | SwiftUI, Supabase Swift SDK |
| `android/` | Android (진행 중) | Kotlin, Jetpack Compose, Material 3 |

## 공유 인프라

| 디렉터리 | 설명 |
|----------|------|
| `supabase/` | DB 스키마, 마이그레이션, Edge Functions |
| `render-service/` | CV PDF 렌더링 서버 (Python/Fly.io) |
| `scripts/` | 데이터 파이프라인 스크립트 |
| `docs/` | 설계 문서 |

## 개발 시작

### iOS
```bash
cd ios
xcodegen generate   # project.yml → .xcodeproj 재생성
open Cadenza.xcodeproj
```

### Android
```bash
cd android
./gradlew assembleDebug
```
