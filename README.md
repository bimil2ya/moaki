[English](README_en.md)

# 모아키 (Moaki)

> 제스처 기반 한글 키보드

[앱스토어](https://apps.apple.com/kr/app/moaki-keyboard/id6759444872?l=en-GB)
[시연 영상](https://youtube.com/shorts/6dgNRADQuDA?feature=share)

## 기능

- 자음 키 위 스와이프로 모음 입력 (21종), 드래그 후 천지인 "점(ㆍ)"으로 Y계열(ㅑㅕㅛㅠ) 단축 변환
- 우측 열 천지인(ㅣㅡㆍ) 탭 입력 지원
- 쌍자음 포함 4줄 자음 배열
- 자음 길게 누르면 숫자 입력, ㅋㅌㅊㅍ 길게 누르면 등록해둔 문구 자동완성
- 한자 변환 (커서 앞 음절 기준 후보 제시)
- 숫자/기호 키패드
- VoiceOver 사용자를 위한 탭 기반 모음 선택 모드
- 제스처 민감도 조절, 실험적 Y계열 원점 복귀 인식기(설정 화면에서 켜고 끌 수 있음)
- 다크모드, 햅틱 피드백
- 네트워크 불필요

## 제스처 가이드

자음 키 위에서 드래그하여 모음을 입력합니다. 왼쪽 대각선(↖, ↙)은 수직 방향으로 정규화됩니다.

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

또는, 드래그로 ㅏ·ㅓ·ㅗ·ㅜ를 만든 뒤 곧바로 천지인 "점(ㆍ)" 키를 누르면 각각 ㅑ·ㅕ·ㅛ·ㅠ로 바뀝니다(예: 하→햐, 모→묘).

### 복합 모음

| 방향 | 모음 |
|------|------|
| ↑→ | ㅘ |
| ↑→← | ㅙ |
| ↓← | ㅝ |
| ↓←→ | ㅞ |
| ↑↓ | ㅚ |
| ↓↑ | ㅟ |
| →← | ㅐ |
| →←→← | ㅒ |
| ←→ | ㅔ |
| ←→←→ | ㅖ |
| ↘↖ 또는 ↘↑ | ㅢ |

## 키보드 배열

```
 ~  ㅃ ㅉ ㄸ ㄲ ㅆ  #
 ^  ㅂ ㅈ ㄷ ㄱ ㅅ  ⌫
 ;  ㅁ ㄴ ㅇ ㄹ ㅎ  ㅣ
 *  ㅋ ㅌ ㅊ ㅍ  ㅡ  ㆍ
[123] [🌐] [      스페이스      ] [.,?!] [⏎]
```

우측 상단 ㅣ · ㅡ · ㆍ 키는 천지인(天地人) 방식으로, 드래그 제스처 없이도 탭만으로 모음을 조합할 수 있다 (예: ㅣ+ㆍ=ㅏ, ㆍ+ㅡ=ㅗ). 스페이스바 옆 `.,?!` 키는 탭할 때마다 `. → , → ? → !` 순서로 순환 입력된다.

자음 길게 누르면 숫자 입력:

```
ㅂ→1  ㅈ→2  ㄷ→3  ㄱ→4  ㅅ→5
ㅁ→6  ㄴ→7  ㅇ→8  ㄹ→9  ㅎ→0
```

## 설치 (TestFlight)

1. iOS 기기에서 [TestFlight](https://apps.apple.com/app/testflight/id899247664)를 설치합니다.
2. 아래 초대 링크를 클릭하여 모아키를 설치합니다.

> **TestFlight 초대 링크**: [모아키 TestFlight](https://testflight.apple.com/join/zWVF8vqJ)

## 키보드 활성화

1. **설정** → **일반** → **키보드** → **키보드** → **새 키보드 추가** → **Moaki** 선택
2. 텍스트 입력 시 🌐 버튼으로 모아키로 전환

## 빌드

```bash
git clone https://github.com/bimil2ya/moaki.git
cd moaki
open ios-moaki.xcodeproj
```

Xcode에서 `MoakiKeyboard` 스킴을 선택하고 빌드합니다.

```bash
xcodebuild -scheme MoakiKeyboard -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -scheme MoakiKeyboardTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

## 구조

```
ios-moaki/
├── ios-moaki/              # 메인 앱 (튜토리얼, 문구/제스처민감도/실험기능 설정 화면)
├── MoakiKeyboard/          # 키보드 익스텐션
│   ├── Engine/             # 한글 조합 (HangulComposer, GestureAnalyzer, VowelResolver, CheonjiinResolver, HanjaDictionary)
│   ├── Models/             # 데이터 모델 (HangulJamo, GestureDirection, VowelPattern, CheonjiinStroke)
│   ├── Views/              # SwiftUI 뷰 (KeyboardView, ConsonantGridView, HanjaCandidateBar, SnippetCandidateBar 등)
│   ├── Utilities/          # 유틸리티 (HangulConstants, KeyboardMetrics, SnippetSettings 등)
│   └── KeyboardViewController.swift
└── MoakiKeyboardTests/     # 유닛 테스트
```

자세한 아키텍처는 [CLAUDE.md](CLAUDE.md)를 참조하세요.

## 라이선스

[MIT License](LICENSE)
