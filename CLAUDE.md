# 모아키 (Moaki) - iOS 한글 키보드

제스처 기반 한글 입력 iOS 키보드 앱

## 프로젝트 구조

```
ios-moaki/
├── ios-moaki/              # 메인 앱: 튜토리얼(Tutorial/), 설정 화면들, LicensesView
│   ├── ContentView.swift
│   ├── SnippetSettingsView.swift            # 문구 자동완성 등록 화면
│   ├── GestureSensitivitySettingsView.swift # 제스처 민감도 배율 설정
│   ├── ExperimentalYVowelSettingsView.swift # 실험 기능: Y계열 원점 복귀 인식
│   ├── LicensesView.swift
│   └── PrivacyInfo.xcprivacy       # 프라이버시 매니지먼트(App Group UserDefaults 사유 선언)
├── MoakiKeyboard/          # 키보드 익스텐션
│   ├── Engine/             # 한글 조합 로직
│   │   ├── HangulComposer.swift    # 한글 조합 상태머신
│   │   ├── GestureAnalyzer.swift   # 제스처 방향 분석
│   │   ├── VowelResolver.swift     # 제스처→모음 변환
│   │   ├── CheonjiinResolver.swift # 천지인(ㅣㅡㆍ) 탭 시퀀스→모음 변환
│   │   └── HanjaDictionary.swift   # 음절→한자 후보 사전 (지연 로드)
│   ├── Models/             # 데이터 모델
│   │   ├── HangulJamo.swift        # 초/중/종성 enum
│   │   ├── GestureDirection.swift  # 방향 enum
│   │   ├── VowelPattern.swift      # 모음 패턴 정의
│   │   └── CheonjiinStroke.swift   # ㅣ/ㅡ/ㆍ 스트로크 enum
│   ├── Views/              # SwiftUI 뷰
│   │   ├── KeyboardView.swift             # 메인 키보드 SwiftUI 뷰 (struct KeyboardView)
│   │   ├── KeyboardViewModel.swift        # 키보드 상태·조합 로직 (class KeyboardViewModel, KeyboardViewModelDelegate)
│   │   ├── ConsonantGridView.swift        # 자음+천지인 그리드
│   │   ├── ConsonantKeyView.swift         # 개별 키 (KeyView)
│   │   ├── FunctionRowView.swift          # 하단 기능행 (123/🌐/한자/스페이스/문장부호/⏎)
│   │   ├── GestureOverlayView.swift       # 제스처 방향 프리뷰 오버레이
│   │   ├── HanjaCandidateBar.swift        # 한자 후보 선택 바
│   │   ├── SnippetCandidateBar.swift      # 문구 후보 선택 바
│   │   └── AccessibilityVowelPickerView.swift # VoiceOver용 모음 선택 오버레이(AccessibilityVowelPickerBar)
│   ├── Utilities/          # 유틸리티
│   │   ├── HangulConstants.swift            # 유니코드 조합 공식
│   │   ├── KeyboardMetrics.swift            # 키 배치/크기, KeyContent 정의
│   │   ├── AppGroupConstants.swift          # App Group ID 등 공유 상수
│   │   ├── SnippetSettings.swift            # 문구 자동완성 저장소(App Group UserDefaults)
│   │   ├── GestureSensitivitySettings.swift # 제스처 민감도 배율 저장소
│   │   └── ExperimentalYVowelSettings.swift # 실험적 Y계열 인식기 토글/진단 카운터 저장소
│   ├── Resources/
│   │   └── hanja_single.txt         # 음절→한자 사전 데이터 (libhangul, BSD 3-Clause)
│   ├── PrivacyInfo.xcprivacy         # 프라이버시 매니지먼트(App Group UserDefaults 사유 선언)
│   └── KeyboardViewController.swift # UIKit 진입점, KeyboardViewModelDelegate 구현
└── MoakiKeyboardTests/     # 유닛 테스트
    ├── KeyboardViewModelLongPressTests.swift              # 롱프레스 숫자/문구, 키보드 전환, 백스페이스 반복 타이머
    ├── KeyboardViewModelSpaceCursorMoveTests.swift         # 스페이스 드래그 커서 이동
    ├── KeyboardViewModelHanjaTests.swift                   # 한자 후보 + 코드 중복 정리 예외 회귀
    ├── KeyboardViewModelCheonjiinTests.swift                # 천지인 탭 조합
    ├── KeyboardViewModelCheonjiinAutoCommitTests.swift     # 천지인 자동확정 타이머
    ├── KeyboardViewModelExperimentalYVowelTests.swift      # 실험적 Y계열 인식기 연결
    ├── KeyboardViewModelAccessibilityVowelTests.swift      # VoiceOver 모음 선택 + 후보 바 상호배타(P1)
    ├── KeyboardViewModelDirectVowelExtensionTests.swift    # 점(ㆍ) 단축 변환
    ├── KeyboardViewModelLeftEdgeColumnGestureTests.swift   # 왼쪽 열 위쪽 드래그 오인식 보정
    ├── SpyKeyboardDelegate.swift                            # 위 테스트들이 공유하는 KeyboardViewModelDelegate 스텁
    ├── HangulConstantsTests.swift        # 유니코드 조합/분해 (완성형 11,172자 전수 round-trip 포함)
    ├── KeyboardMetricsTests.swift        # 레이아웃 좌표·형태 불변식, 제스처 민감도 배율 스케일링
    ├── GestureSensitivitySettingsTests.swift    # 제스처 민감도 배율 clamp
    ├── ExperimentalYVowelSettingsTests.swift    # 실험 토글/진단 카운터
    └── SnippetSettingsTests.swift               # 문구 저장소 키/조합 로직
```

## 핵심 아키텍처

### 한글 조합 흐름

```
사용자 입력 → KeyboardViewModel → HangulComposer → ComposerAction
                    ↓                                    ↓
              제스처 분석 ←──────────────────────── 텍스트 출력
```

### HangulComposer 상태

- `empty`: 입력 없음
- `choseong(초성)`: 자음만 입력됨
- `choseongJungseong(초성, 중성)`: 자음+모음
- `complete(초성, 중성, 종성)`: 완성된 글자

### ComposerAction

- `.none`: 변화 없음
- `.update`: 조합 중인 글자 갱신 (markedText 업데이트)
- `.commit`: 글자 확정 (composedText → insertText)
- `.delete`: 삭제 동작
- `.commitAndUpdate`: 이전 글자 확정 + 새 조합 시작
- `.commitAndCommit`: 이전 글자 + 현재 글자 모두 확정

**중요**: `.commit*` 액션 발생 시 `composer.flushCommittedText()`로 확정된 텍스트를 가져와 `delegate?.insertText()`로 출력해야 함

## 모음 제스처 규칙

자음 키 위에서 드래그하여 모음 입력:

### 대각선 정규화
왼쪽 대각선만 수직 방향으로 정규화됨:
- ↖ → ↑ (ㅗ)
- ↙ → ↓ (ㅜ)

오른쪽 대각선은 별도 모음:
- ↗ → ㅣ
- ↘ → ㅡ

### 기본 모음

| 방향 | 모음 |
|------|------|
| → | ㅏ |
| ← | ㅓ |
| ↑ (또는 ↖) | ㅗ |
| ↓ (또는 ↙) | ㅜ |
| ↘ | ㅡ |
| ↗ | ㅣ |

### Y-모음 (왕복 제스처)

| 방향 | 모음 |
|------|------|
| ↑↓↑ | ㅛ |
| ↓↑↓ | ㅠ |
| →←→ | ㅑ |
| ←→← | ㅕ |

### 복합 모음

| 방향 | 모음 |
|------|------|
| ↑→ | ㅘ |
| ↑→← | ㅙ |
| ↓← | ㅝ |
| ↓→← | ㅞ |
| ↑↓ | ㅚ |
| ↓↑ | ㅟ |
| →← | ㅐ |
| →←→← | ㅒ |
| ←→ | ㅔ |
| ←→←→ | ㅖ |
| ↘↖ 또는 ↘↑ | ㅢ |

## 천지인 입력 / 한자 변환

- 자음 위 드래그 제스처와 별개로, 우측 열의 ㅣ·ㆍ·ㅡ 키를 탭해서도 모음을 조합할 수 있다 (`CheonjiinResolver`). ㅏㅑㅓㅕㅗㅛㅜㅠㅡㅣ 기본 10개뿐 아니라 ㅐㅒㅔㅖㅚㅟㅢㅘㅙㅝㅞ 겹모음까지 전체 스트로크 시퀀스를 트라이에 직접 등록해 처리한다 — 예: ㅝ(ㅜ+ㅓ)는 `[.eu, .dot]`(ㅜ) 뒤에 `[.dot, .i]`(ㅓ)를 그대로 이어붙인 `[.eu, .dot, .dot, .i]`로 등록되어 있다. `HangulComposer.combineVowels`로 두 번 연쇄 결합해야 하는 방식은 ㅙ/ㅞ처럼 결합을 두 번 거쳐야 하는 겹모음을 만들 수 없어서 쓰지 않는다(제스처 드래그 쪽 겹모음은 여전히 `combineVowels` 사용).
- ㅏㅓㅗㅜ 같은 기본 모음은 ㅑㅕㅛㅠ와 스트로크 앞부분이 겹쳐서, 스트로크만으로는 확정 시점을 알 수 없다. 그래서 마지막 스트로크 이후 `KeyboardViewModel.cheonjiinAutoCommitDelay`(기본 0.45초) 동안 다음 스트로크가 없으면 타이머로 자동 확정하고, 대기 중에는 `previewVowel`을 통해 실시간 미리보기가 뜬다(`GestureOverlayView`는 드래그 방향이 없어도 미리보기 모음만 있으면 표시하도록 조건이 완화되어 있다). 확정 전 버퍼는 이 타이머 외에도 `KeyboardViewModel.flushPendingCheonjiin()`으로 다른 입력이 들어오기 직전에 항상 흘려보낸다.
- 기능행의 "한자" 버튼은 커서 바로 앞 음절(`KeyboardViewModelDelegate.characterBeforeCursor()`)을 `HanjaDictionary`에서 조회해 후보를 보여준다. 사전 데이터(`Resources/hanja_single.txt`)는 libhangul 프로젝트의 BSD 3-Clause 라이선스 데이터 부분집합이며, 라이선스 고지는 `ios-moaki/LicensesView.swift`에 있다.

## 키보드 전환(지구본) 버튼

`switchToNextKeyboard()`가 `KeyboardViewModelDelegate`에 있었지만 실제로 호출하는 UI가 없었던 적이 있다(과거 지구본 버튼을 빼고 그 자리를 "문구" 단축키로 썼는데, "iOS가 서드파티 키보드에 강제로 붙이는 시스템 바로 이미 전환 가능하다"는 근거가 실제로는 부정확했다). `UIInputViewController.needsInputModeSwitchKey`는 호스트 연결 전에 읽으면 부정확하고 생명주기 도중 값이 바뀐 사례, 특정 `UIKeyboardType`에서 신뢰 못 하는 사례가 여러 차례 보고된 API라, 이 프로퍼티로 조건부 표시하지 않고 **지구본 버튼을 항상 노출**한다(Gboard 등 주요 서드파티 키보드도 같은 방식). 롱프레스로 특정 키보드를 고르는 `handleInputModeList(from:with:)` 연동은 실제 `UIEvent`가 필요해 SwiftUI `DragGesture` 기반 `FunctionKeyView`로는 못 만들고 `UIViewRepresentable` 브릿지가 필요하므로 의도적으로 구현하지 않았다 — 탭 한 번으로 다음 키보드 전환만 지원한다. 전환 시 조합 상태 정리는 새 로직 없이 기존 `KeyboardViewController.viewWillDisappear` → `flushPendingStateBeforeDisappearing()` 경로를 그대로 재사용한다.

## 문구 자동완성 / 제스처 민감도 / 실험적 Y계열 인식기

세 기능 모두 `MoakiKeyboard/Utilities/`의 전용 저장소(`SnippetSettings`, `GestureSensitivitySettings`, `ExperimentalYVowelSettings`)가 App Group(`group.dev.nohkyeongho.moaki`) `UserDefaults(suiteName:)`를 직접 읽고 쓰며, 호스트 앱(`ios-moaki/`)의 대응 설정 화면(`SnippetSettingsView`, `GestureSensitivitySettingsView`, `ExperimentalYVowelSettingsView`)에서 편집한다 — 키보드 익스텐션과 호스트 앱이 별도 프로세스라 코드를 공유하지 못하므로, 앱 그룹 키 문자열은 양쪽에 동일하게 유지해야 한다. 이 키 상수들은 양쪽에 각각 독립적으로 리터럴로 존재해 실제로 중복 선언돼 있다(공유 프레임워크 타깃은 아직 없음) — 두 타깃 간 100% 동기화를 보장하진 않지만, `MoakiKeyboardTests`와 `ios-moakiTests`(호스트 앱 테스트 타깃, `import Testing`/`@Test`/`#expect` 사용 — `MoakiKeyboardTests`의 XCTest와는 다른 컨벤션) 양쪽에 각자 자기 값을 고정 문자열과 대조하는 테스트를 둬서 어느 한쪽만 값이 실수로 바뀌어도 그쪽 테스트가 즉시 실패하게 한다.

- **문구 자동완성**: ㅋㅌㅊㅍ 키 롱프레스로 등록된 문구를 바로 삽입한다(`inputLongPressNumber`가 이름과 달리 숫자와 문구 롱프레스를 모두 처리 — 실제로는 "롱프레스로 확정된 문자열을 그대로 삽입"이라는 동일 동작이기 때문). 기능행의 "문구" 버튼은 등록된 전체 목록을 `SnippetCandidateBar`로 보여준다.
- **제스처 민감도**: `GestureSensitivitySettings.multiplier()`(0.7~1.5 clamp)가 `KeyboardMetrics.gestureThreshold` 등 모든 거리 임계값에 곱해진다. 설정 화면에서 바꿔도 이미 열려 있는 키보드 인스턴스에는 즉시 반영되지 않고, 키보드를 껐다 켜야 반영된다.
- **실험적 Y계열(ㅑㅕㅛㅠ) 원점 복귀 인식기**: 기본 OFF. `GestureAnalyzer`가 좌표만으로 항상 계산하는 별도 상태머신(`confirmedYVowel`)이며, `KeyboardViewModel`이 토글이 켜져 있을 때만 이 값을 채택한다 — 토글이 꺼져 있어도 왕복 제스처로 Y계열을 만드는 기본 경로(`VowelPattern`의 3획 패턴, 예: ↑↓↑=ㅛ)는 항상 동작한다. 토글은 제스처 시작 시점에 한 번만 캐시되어(`isExperimentalYVowelEnabledForCurrentGesture`) 도중에 값이 바뀌어도 이미 진행 중인 제스처에는 영향이 없다.

### 테스트에서 App Group 격리하기

`KeyboardViewModel.init`은 실제 App Group을 읽고/쓰는 세 프로덕션 API(`ExperimentalYVowelSettings.isEnabled()`/`.recordApplied(wasConflictOverride:)`, `SnippetSettings.allSnippets()`)를 각각 기본값으로 하는 주입 지점을 갖는다 — `experimentalYVowelEnabledProvider`, `experimentalYVowelRecorder`, `snippetsProvider`. 테스트가 `gestureStarted`(내부적으로 항상 `experimentalYVowelEnabledProvider()`/`experimentalYVowelRecorder()`를 호출) 또는 `showSnippetCandidates()`(항상 `snippetsProvider()`를 호출)에 도달하는 `KeyboardViewModel` 인스턴스를 만들 때는, 이 provider들을 UUID 임시 `UserDefaults(suiteName:)`로 리디렉션한 클로저로 반드시 넘겨야 한다 — 그러지 않으면 인자를 하나도 안 주든(`KeyboardViewModel()`) 다른 인자만 주든(`cheonjiinAutoCommitDelay:` 등) 실제 기기/시뮬레이터의 App Group을 조용히 읽고(토글이 켜져 있으면 쓰기까지) 오염시킨다. `GestureSensitivitySettings.multiplier()`(제스처 민감도 배율)는 이 패턴에서 아직 예외다 — `GestureAnalyzer.init`의 기본 파라미터가 실제 App Group을 인자 없이 읽으며, 주입 지점이 없어 모든 `KeyboardViewModel` 생성이 읽기 전용으로 영향을 받는다(쓰기는 없어 영구 오염은 아님 — 후속 작업 대상).

## VoiceOver 접근성 모음 선택

VoiceOver 사용자는 드래그 제스처 대신, 자음 키의 커스텀 액션("모음 선택하여 입력")으로 `AccessibilityVowelPickerBar` 오버레이를 열어 모음을 탭으로 선택할 수 있다(`KeyboardViewModel.showAccessibilityVowelPicker`/`selectAccessibilityVowel`). 이 경로는 새 조합 로직 없이 기존 `inputConsonant`/`inputVowel`을 그대로 재사용한다. 키보드 익스텐션 UI에서 `.sheet()` 같은 시스템 모달은 검증되지 않은 위험 요소로 보고, 기존 `HanjaCandidateBar`/`SnippetCandidateBar`와 같은 ZStack 오버레이 바 패턴을 따랐다.

## 드래그 모음 → 점(ㆍ) 단축 변환, 왼쪽 열 위쪽 드래그 보정

- 드래그로 만든 기본 모음(ㅏㅓㅗㅜ) 직후 천지인 "점" 키를 누르면 Y계열(ㅑㅕㅛㅠ)로 바뀐다(하→햐 등). `CheonjiinResolver`의 실제 스트로크 시퀀스(ㅓ=[ㆍ,ㅣ]→ㅕ=[ㆍ,ㆍ,ㅣ] 등, "끝에 점 추가" 패턴을 따르지 않음)와는 무관한 독립 단축 매핑이며, `KeyboardViewModel.pendingDirectVowelExtension`이라는 1회성 대기 상태로만 처리한다. 대기 상태는 드래그(`handleKoreanModeGesture`)와 접근성 선택(`selectAccessibilityVowel`) 두 경로에서만 설정하고, `inputVowel(_:)` 내부에는 절대 넣지 않는다 — 그 함수는 천지인 자체 확정에서도 호출되므로 넣으면 교차오염된다. `resetGestureState()`도 절대 건드리지 않는다 — `gestureEnded`가 그 함수를 제스처 종료 직후 바로 호출하므로, 여기 무효화를 넣으면 막 설정한 대기 상태를 같은 제스처가 스스로 지워버린다.
- 왼쪽 끝 자음 열(ㅃㅂㅁㅋ)에서 위로 드래그하면 손동작이 화면 중앙 쪽으로 휘어져 ㅗ/ㅛ가 ㅣ로 잘못 인식되는 문제가 실기기에서 보고됐다. `GestureDirection.from(vector:threshold:upSectorExpansionDegrees:)`가 up/upRight 사이의 공유 경계만(기본 80도, 최대 30도까지 축소 가능) 왼쪽 끝 열 제스처에 한해 넓혀 보정한다 — down 계열 분류나 다른 열에는 영향이 없다. `GestureAnalyzer`는 `classifyDirection(vector:threshold:)` 헬퍼 하나로 이 값을 관리하며, `reset(upSectorExpansionDegrees:)`가 매 제스처마다 기본값 0으로 확실히 덮어써야 이전 제스처의 확장값이 다음 제스처(다른 열)로 새지 않는다.

## 빌드 및 테스트

```bash
# 빌드
xcodebuild -scheme MoakiKeyboard -destination 'platform=iOS Simulator,name=iPhone 15'

# 테스트
xcodebuild test -scheme MoakiKeyboardTests -destination 'platform=iOS Simulator,name=iPhone 15'
```

**배포(TestFlight/앱스토어) 전에는 `.claude/skills/deploy-check/SKILL.md` 절차를 따른다** — 빌드/테스트 자동 검증과 변경 파일별 영향 UI 경로를 사람이 시뮬레이터에서 직접 확인하는 단계를 포함한다.

## 키보드 테스트 방법

1. 시뮬레이터에서 앱 실행
2. 설정 → 일반 → 키보드 → 키보드 → 새 키보드 추가 → MoakiKeyboard
3. 메모 앱에서 키보드 전환 (🌐 버튼)

## 주의사항

- iOS 키보드 익스텐션은 제한된 메모리에서 동작
- `KeyboardViewController`는 UIKit, 나머지는 SwiftUI
- `KeyboardViewModel`은 `@MainActor`로 격리되어 있다 — `MoakiKeyboard`/`MoakiKeyboardTests` 타깃은 `ios-moaki`(호스트 앱)와 달리 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`가 설정돼 있지 않아, 명시적 어노테이션이 유일한 격리 수단이다. `deinit`은 Swift에서 항상 `nonisolated`라 `@MainActor` 격리 메서드를 호출할 수 없으므로, `KeyboardViewModel.deinit`은 `stopBackspaceRepeat()` 등을 호출하는 대신 그 본문(타이머 `invalidate()`)을 직접 인라인한다. `KeyboardViewModel`을 생성하거나 그 메서드를 호출하는 테스트 클래스는 `@MainActor`가 필요하다.
- 다크모드 대응: `Color(.systemBackground)` 계열 사용
- `insertText()` 호출 전 `flushCommittedText()`로 확정 텍스트 획득 필수
