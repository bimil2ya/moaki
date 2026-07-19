import Foundation

struct VowelPattern {
    let vowel: Jungseong
    let directions: [GestureDirection]

    init(_ vowel: Jungseong, _ directions: GestureDirection...) {
        self.vowel = vowel
        self.directions = directions
    }

    static let allPatterns: [VowelPattern] = [
        // Basic vowels (왼쪽 대각선만 정규화: ↖→↑, ↙→↓)
        VowelPattern(.ㅗ, .up),                           // ↑ (↖도 정규화로 처리됨)
        VowelPattern(.ㅜ, .down),                         // ↓ (↙도 정규화로 처리됨)
        VowelPattern(.ㅏ, .right),                        // →
        VowelPattern(.ㅓ, .left),                         // ←
        VowelPattern(.ㅡ, .downRight),                    // ↘ → ㅡ
        VowelPattern(.ㅣ, .upRight),                      // ↗ → ㅣ

        // Y-vowels (triple direction)
        // 마지막 획은 이미 갈림길(↑ 다음 ↓냐 →냐, ↓ 다음 ↑냐 ←냐)을 지나온 뒤라
        // 더 이상 다른 뜻과 헷갈릴 일이 없다 — "계속 같은 방향으로 가는 것"만
        // 아니면 전부 이 모음으로 본다. 대각선(↖↗↙↘)은 normalizeTrailingStroke가
        // 이미 알아서 축(↑/↓/←/→)으로 정규화해주므로, 여기서는 그 정규화로 커버
        // 안 되는 반대쪽 축(→/← 또는 ↑/↓)만 추가로 등록한다.
        VowelPattern(.ㅛ, .up, .down, .up),               // ↑↓↑
        VowelPattern(.ㅛ, .up, .down, .left),             // ↑↓← (← 방향으로 삐끗해도 ㅛ)
        VowelPattern(.ㅛ, .up, .down, .right),            // ↑↓→
        VowelPattern(.ㅠ, .down, .up, .down),             // ↓↑↓
        VowelPattern(.ㅠ, .down, .up, .left),             // ↓↑←
        VowelPattern(.ㅠ, .down, .up, .right),            // ↓↑→
        VowelPattern(.ㅑ, .right, .left, .right),         // →←→
        VowelPattern(.ㅑ, .right, .left, .up),            // →←↑
        VowelPattern(.ㅑ, .right, .left, .down),          // →←↓
        VowelPattern(.ㅕ, .left, .right, .left),          // ←→←
        VowelPattern(.ㅕ, .left, .right, .up),            // ←→↑
        VowelPattern(.ㅕ, .left, .right, .down),          // ←→↓

        // Complex vowels (diphthongs)
        VowelPattern(.ㅘ, .up, .right),                   // ↑→
        VowelPattern(.ㅙ, .up, .right, .left),            // ↑→←
        VowelPattern(.ㅙ, .up, .right, .up),              // ↑→↑
        VowelPattern(.ㅙ, .up, .right, .down),            // ↑→↓
        VowelPattern(.ㅝ, .down, .left),                  // ↓←
        VowelPattern(.ㅞ, .down, .left, .right),          // ↓←→
        VowelPattern(.ㅞ, .down, .left, .up),             // ↓←↑
        VowelPattern(.ㅞ, .down, .left, .down),           // ↓←↓
        VowelPattern(.ㅚ, .up, .down),                    // ↑↓
        VowelPattern(.ㅟ, .down, .up),                    // ↓↑

        // Ae/E vowels
        // ㅐ/ㅔ는 시작 획(→ 또는 ←)이 다른 모음(ㅏ, ㅓ)과 안 겹치는 유일한
        // 두 번째 획(←/→)을 가지므로, 그 두 번째 획도 정확한 반대 각도일
        // 필요 없이 "계속 같은 방향(→ 또는 ←)"만 아니면 전부 인정한다.
        VowelPattern(.ㅐ, .right, .left),                 // →←
        VowelPattern(.ㅐ, .right, .up),                   // →↑
        VowelPattern(.ㅐ, .right, .down),                 // →↓
        VowelPattern(.ㅒ, .right, .left, .right, .left),  // →←→←
        VowelPattern(.ㅒ, .right, .left, .right, .up),    // →←→↑
        VowelPattern(.ㅒ, .right, .left, .right, .down),  // →←→↓
        VowelPattern(.ㅔ, .left, .right),                 // ←→
        VowelPattern(.ㅔ, .left, .up),                    // ←↑
        VowelPattern(.ㅔ, .left, .down),                  // ←↓
        VowelPattern(.ㅖ, .left, .right, .left, .right),  // ←→←→
        VowelPattern(.ㅖ, .left, .right, .left, .up),     // ←→←↑
        VowelPattern(.ㅖ, .left, .right, .left, .down),   // ←→←↓

        // Eu-i (ㅡ + ㅣ): 되돌아오는 두 번째 획이 정확히 ↖(정반대 방향)가 아니어도
        // 된다 — ↘ 다음에 오는 다른 획은 ㅢ 말고는 의미가 없으므로, "계속 같은
        // 방향으로 가는 것"(↓, →)만 아니면 전부 같은 의도로 본다.
        VowelPattern(.ㅢ, .downRight, .upLeft),           // ↘↖ (오른쪽아래-왼쪽위, 정반대)
        VowelPattern(.ㅢ, .downRight, .up),               // ↘↑ (오른쪽아래-위)
        VowelPattern(.ㅢ, .downRight, .left),             // ↘← (오른쪽아래-왼쪽)
        VowelPattern(.ㅢ, .downRight, .upRight),          // ↘↗ (오른쪽아래-오른쪽위)
        VowelPattern(.ㅢ, .downRight, .downLeft),         // ↘↙ (오른쪽아래-왼쪽아래)
    ]

    // Build a trie for efficient pattern matching
    static let patternTrie: PatternTrie = {
        let trie = PatternTrie()
        for pattern in allPatterns {
            trie.insert(pattern)
        }
        return trie
    }()
}

// Trie for efficient pattern matching
class PatternTrie {
    class Node {
        var children: [GestureDirection: Node] = [:]
        var vowel: Jungseong?
        var isPartialMatch: Bool = false // True if this is a prefix of a longer pattern
    }

    let root = Node()

    func insert(_ pattern: VowelPattern) {
        var current = root
        for (index, direction) in pattern.directions.enumerated() {
            if current.children[direction] == nil {
                current.children[direction] = Node()
            }
            current = current.children[direction]!

            // Mark intermediate nodes as partial matches
            if index < pattern.directions.count - 1 {
                current.isPartialMatch = true
            }
        }
        current.vowel = pattern.vowel
    }

    struct MatchResult {
        let vowel: Jungseong?
        let consumedCount: Int
        let hasLongerMatch: Bool
    }

    func match(_ directions: [GestureDirection]) -> MatchResult {
        var current = root
        var lastMatch: (vowel: Jungseong, count: Int)?
        var hasLongerMatch = false

        for (index, direction) in directions.enumerated() {
            guard let next = current.children[direction] else {
                break
            }
            current = next

            if let vowel = current.vowel {
                lastMatch = (vowel, index + 1)
            }

            if index == directions.count - 1 && !current.children.isEmpty {
                hasLongerMatch = true
            }
        }

        if let match = lastMatch {
            return MatchResult(vowel: match.vowel, consumedCount: match.count, hasLongerMatch: hasLongerMatch)
        }

        return MatchResult(vowel: nil, consumedCount: 0, hasLongerMatch: !current.children.isEmpty)
    }
}
