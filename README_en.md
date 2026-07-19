[한국어](README.md)

# Moaki

> Gesture-based Korean (Hangul) Keyboard

<!-- TODO: Add keyboard demo video -->
[App Store](https://apps.apple.com/kr/app/moaki-keyboard/id6759444872?l=en-GB)

## Features

- Swipe on consonant keys to input vowels (all 21 vowels), or drag a basic vowel then tap the cheonjiin "dot(ㆍ)" key to shortcut into its Y-vowel form
- Tap-based cheonjiin (ㅣㅡㆍ) input on the right column
- 4-row consonant layout including double consonants
- Long press consonants for numbers, long press ㅋㅌㅊㅍ for user-registered text snippets
- Hanja (Chinese character) conversion based on the syllable before the cursor
- Number/symbol keypad
- Tap-based vowel picker mode for VoiceOver users
- Adjustable gesture sensitivity, experimental Y-vowel round-trip recognizer (toggle in Settings)
- Dark mode, haptic feedback
- No network required

## Gesture Guide

Drag on a consonant key to input a vowel. Left diagonals (↖, ↙) are normalized to vertical directions.

### Basic Vowels

| Direction | Vowel |
|-----------|-------|
| → | ㅏ (a) |
| ← | ㅓ (eo) |
| ↑ (or ↖) | ㅗ (o) |
| ↓ (or ↙) | ㅜ (u) |
| ↘ | ㅡ (eu) |
| ↗ | ㅣ (i) |

### Y-Vowels (Back-and-forth gestures)

| Direction | Vowel |
|-----------|-------|
| ↑↓↑ | ㅛ (yo) |
| ↓↑↓ | ㅠ (yu) |
| →←→ | ㅑ (ya) |
| ←→← | ㅕ (yeo) |

Alternatively, drag ㅏ/ㅓ/ㅗ/ㅜ then immediately tap the cheonjiin "dot(ㆍ)" key to turn it into ㅑ/ㅕ/ㅛ/ㅠ respectively (e.g. 하→햐, 모→묘).

### Compound Vowels

| Direction | Vowel |
|-----------|-------|
| ↑→ | ㅘ (wa) |
| ↑→← | ㅙ (wae) |
| ↓← | ㅝ (wo) |
| ↓←→ | ㅞ (we) |
| ↑↓ | ㅚ (oe) |
| ↓↑ | ㅟ (wi) |
| →← | ㅐ (ae) |
| →←→← | ㅒ (yae) |
| ←→ | ㅔ (e) |
| ←→←→ | ㅖ (ye) |
| ↘↖ or ↘↑ | ㅢ (ui) |

## Keyboard Layout

```
 ~  ㅃ ㅉ ㄸ ㄲ ㅆ  #
 ^  ㅂ ㅈ ㄷ ㄱ ㅅ  ⌫
 ;  ㅁ ㄴ ㅇ ㄹ ㅎ  ㅣ
 *  ㅋ ㅌ ㅊ ㅍ  ㅡ  ㆍ
[123] [🌐] [        Space        ] [.,?!] [⏎]
```

The top-right ㅣ · ㅡ · ㆍ keys work as cheonjiin (天地人) input — tapping them (without any drag gesture) also composes vowels, e.g. ㅣ+ㆍ=ㅏ, ㆍ+ㅡ=ㅗ. The `.,?!` key next to the space bar cycles through `. → , → ? → !` on each tap.

Long press consonants for numbers:

```
ㅂ→1  ㅈ→2  ㄷ→3  ㄱ→4  ㅅ→5
ㅁ→6  ㄴ→7  ㅇ→8  ㄹ→9  ㅎ→0
```

## Install (TestFlight)

1. Install [TestFlight](https://apps.apple.com/app/testflight/id899247664) on your iOS device.
2. Tap the invite link below to install Moaki.

> **TestFlight invite link**: [Moaki TestFlight](https://testflight.apple.com/join/zWVF8vqJ)

## Activate the Keyboard

1. **Settings** → **General** → **Keyboard** → **Keyboards** → **Add New Keyboard** → Select **Moaki**
2. Switch to Moaki using the 🌐 button when typing

## Build

```bash
git clone https://github.com/bimil2ya/moaki.git
cd moaki
open ios-moaki.xcodeproj
```

Select the `MoakiKeyboard` scheme in Xcode and build.

```bash
xcodebuild -scheme MoakiKeyboard -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -scheme MoakiKeyboardTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Structure

```
ios-moaki/
├── ios-moaki/              # Main app (tutorial, snippet/gesture-sensitivity/experimental-feature settings)
├── MoakiKeyboard/          # Keyboard extension
│   ├── Engine/             # Hangul composition (HangulComposer, GestureAnalyzer, VowelResolver, CheonjiinResolver, HanjaDictionary)
│   ├── Models/             # Data models (HangulJamo, GestureDirection, VowelPattern, CheonjiinStroke)
│   ├── Views/              # SwiftUI views (KeyboardView, ConsonantGridView, HanjaCandidateBar, SnippetCandidateBar, etc.)
│   ├── Utilities/          # Utilities (HangulConstants, KeyboardMetrics, SnippetSettings, etc.)
│   └── KeyboardViewController.swift
└── MoakiKeyboardTests/     # Unit tests
```

For detailed architecture, see [CLAUDE.md](CLAUDE.md).

## License

[MIT License](LICENSE)
