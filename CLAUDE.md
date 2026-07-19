# 모아키 (Moaki) - iOS 한글 키보드

제스처 기반 한글 입력 iOS 키보드 앱

## 프로젝트 구조

```
ios-moaki/
├── ios-moaki/              # 메인 앱 (설정 UI, 튜토리얼, LicensesView)
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
│   │   ├── KeyboardView.swift      # 메인 키보드 + ViewModel (KeyboardViewModel)
│   │   ├── ConsonantGridView.swift # 자음+천지인 그리드
│   │   ├── ConsonantKeyView.swift  # 개별 키 (KeyView)
│   │   ├── FunctionRowView.swift   # 하단 기능행 (123/🌐/한자/스페이스/문장부호/⏎)
│   │   ├── GestureOverlayView.swift # 제스처 방향 프리뷰 오버레이
│   │   └── HanjaCandidateBar.swift # 한자 후보 선택 바
│   ├── Utilities/          # 유틸리티
│   │   ├── HangulConstants.swift   # 유니코드 조합 공식
│   │   ├── KeyboardMetrics.swift   # 키 배치/크기, KeyContent 정의
│   │   └── KeyboardSettings.swift  # 사용자 설정 (제스처 프리뷰 표시 여부)
│   ├── Resources/
│   │   └── hanja_single.txt         # 음절→한자 사전 데이터 (libhangul, BSD 3-Clause)
│   └── KeyboardViewController.swift # UIKit 진입점, KeyboardViewModelDelegate 구현
└── MoakiKeyboardTests/     # 유닛 테스트
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
- 다크모드 대응: `Color(.systemBackground)` 계열 사용
- `insertText()` 호출 전 `flushCommittedText()`로 확정 텍스트 획득 필수
