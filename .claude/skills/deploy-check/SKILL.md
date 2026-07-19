---
name: deploy-check
description: moaki 배포(TestFlight/앱스토어) 전 점검 절차. 사용자가 "배포", "빌드해줘", "테스트플라이트", "앱스토어에 올려줘", "릴리즈"를 언급하거나, 코드 수정을 마치고 반영을 요청할 때 반드시 이 스킬을 사용한다. 빌드/테스트 검증과 회귀 UI 경로(시뮬레이터 실기기 확인) 점검을 거치지 않은 배포는 금지.
---

# moaki 배포 전 점검

키보드 익스텐션은 사람이 실제로 타이핑해봐야만 드러나는 회귀(제스처 오작동, 레이아웃 깨짐, 조합 텍스트 유실)가 많다. 자동 빌드/테스트가 통과해도 이 절차의 수동 확인 단계를 생략하지 않는다. CLAUDE.md의 규칙(모음 제스처 규칙, 키보드 익스텐션 메모리 제약, `flushCommittedText()` 필수 호출)이 전제 지식이다.

## 절차

### 1. 변경 범위 파악

`git status`와 `git diff`(스테이징 전이면 작업 트리 기준)로 이번 배포에 포함되는 변경 파일을 나열한다. 사용자가 말한 수정이 git에 보이지 않으면 배포를 중단하고 어디에 있는지부터 확인한다.

### 2. 자동 검증 (순서대로, 하나라도 실패 시 중단)

```bash
# 스킴 목록 확인 — MoakiKeyboardTests가 실제로 존재하는지 매번 확인한다
# (project.pbxproj에 이 타겟/스킴이 없을 수 있다는 게 이전에 확인된 적 있음)
xcodebuild -list -project ios-moaki.xcodeproj

# 빌드
xcodebuild -scheme MoakiKeyboard -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme ios-moaki -destination 'platform=iOS Simulator,name=iPhone 16' build

# 테스트 (스킴이 실제로 있을 때만)
xcodebuild test -scheme MoakiKeyboardTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

`MoakiKeyboardTests` 스킴이 목록에 없으면 테스트를 건너뛰지 말고, 사용자에게 스킴을 추가해달라고 먼저 요청한다 — 테스트 파일이 있어도 타겟에 연결 안 돼 있으면 아무것도 검증하지 않은 것과 같다.

이 환경(Claude Code가 실행되는 머신)에 Xcode가 없을 수 있다. 그럴 땐 `swiftc -typecheck`로 UI에 의존하지 않는 로직 레이어(Models/Engine/Utilities)만이라도 타입체크하고, 나머지는 사용자에게 직접 빌드해달라고 명시한다 — "빌드 통과"라고 잘못 보고하지 않는다.

### 3. 영향 UI 경로 도출

변경 파일별로 "이 변경이 영향을 미치는 UI/입력 경로"를 표로 만든다. 파일→경로 매핑 감각:

- `MoakiKeyboard/Engine/HangulComposer.swift`, `GestureAnalyzer.swift`, `VowelResolver.swift`, `CheonjiinResolver.swift` → 한글 조합 전체(드래그 제스처 + 천지인 탭 입력 모두)
- `MoakiKeyboard/Models/*.swift`(Choseong/Jungseong/Jongseong, GestureDirection, VowelPattern, CheonjiinStroke) → 위와 동일하게 영향 범위 넓음
- `MoakiKeyboard/Utilities/KeyboardMetrics.swift` → 키 배치 전체(한글 모드 + 기호 모드 양쪽, 자리 하나만 바꿔도 전체 그리드 폭 계산에 영향)
- `MoakiKeyboard/Views/ConsonantGridView.swift`, `ConsonantKeyView.swift` → 키 렌더링/제스처 판정 전체
- `MoakiKeyboard/Views/FunctionRowView.swift` → 기능 행 전체(123 토글, 🌐, 한자, 스페이스, 문장부호, 엔터)
- `MoakiKeyboard/Views/KeyboardView.swift`(KeyboardViewModel) → 사실상 모든 입력 경로(자음/모음/삭제/스페이스/엔터/커서 이동/한자/기호 순환)와 그 상태 간 상호작용(예: 천지인 대기 버퍼가 다른 입력 전에 확정되는지)
- `MoakiKeyboard/KeyboardViewController.swift` → 델리게이트로 실제 텍스트 필드에 반영되는 전 구간(insertText/deleteBackward/커서 이동/키보드 전환)
- `MoakiKeyboard/Engine/HanjaDictionary.swift`, `Resources/hanja_single.txt` → 한자 변환 기능, 리소스 파일이 실제 타겟에 번들됐는지도 함께 확인
- `ios-moaki/`(메인 앱, `Tutorial/` 포함) → 온보딩/튜토리얼 화면, 설정 안내, 라이선스 화면

### 4. 수동 확인 요청

도출된 경로 체크리스트를 사용자에게 제시하고, **시뮬레이터(또는 실기기)에서 키보드를 실제로 활성화해 확인해달라고 요청한다**:

1. 시뮬레이터에서 `ios-moaki` 실행
2. 설정 → 일반 → 키보드 → 키보드 → 새 키보드 추가 → MoakiKeyboard
3. 메모 앱 등에서 🌐로 전환해 변경된 경로들을 하나씩 타이핑해서 확인

자동 빌드가 통과해도 이 단계를 건너뛰지 않는다 — 제스처/조합 관련 회귀는 대부분 실제로 타이핑해봐야 드러난다.

### 5. 배포

사용자가 수동 확인을 완료했다고 답한 뒤에만 진행한다. 이 프로젝트엔 fastlane 등 CLI 배포 자동화가 없으므로, Archive 이후 단계(App Store Connect 업로드, TestFlight 배포)는 Xcode Organizer에서 사용자가 직접 수행하도록 안내한다:

1. Xcode에서 `ios-moaki` 스킴 선택, `Any iOS Device`로 대상 변경 후 Product → Archive
2. Organizer에서 생성된 아카이브를 App Store Connect로 업로드
3. App Store Connect에서 TestFlight 빌드 처리 확인

CLI로 대신 실행할 수 있는 단계가 아니므로, 진행 상황을 사용자에게 계속 확인받는다.

## 예외

사용자가 "긴급이니 점검 생략하고 진행해"라고 명시하면 2번(자동 검증)만은 수행하고 넘어간다. 자동 검증까지 생략하지는 않는다.
