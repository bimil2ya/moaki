import Foundation

/// 천지인 방식의 모음 조합기.
///
/// ㅣ·ㅡ·ㆍ 스트로크를 순서대로 입력받아 버퍼에 쌓다가, 버퍼가 더 이상 확장될 수 없는
/// 시점에 자동으로 확정한다. ㅐㅒㅔㅖㅚㅟㅢ 같은 ㅣ-결합 이중모음과 ㅘㅙㅝㅞ 같은 복합
/// 이중모음도 각각의 전체 스트로크 시퀀스를 트라이에 직접 등록해서 다룬다 — 예를 들어
/// ㅝ(ㅜ+ㅓ)는 [.eu, .dot](ㅜ)에 이어 [.dot, .i](ㅓ)를 그대로 이어붙인
/// [.eu, .dot, .dot, .i]로 등록한다. 이렇게 해야 ㅡㆍㆍ까지 입력됐을 때 "ㅠ로 이미
/// 끝난 것"으로 조급하게 확정하지 않고, 뒤에 ㅣ가 더 오면 ㅝ로 계속 확장할 수 있다.
/// (`HangulComposer.combineVowels`로 두 번 연쇄 결합해야 하는 방식은 ㅙ/ㅞ처럼 결합을
/// 두 번 거쳐야 하는 겹모음을 만들 수 없어서 여기서는 쓰지 않는다.)
final class CheonjiinResolver {
    private final class Node {
        var children: [CheonjiinStroke: Node] = [:]
        var vowel: Jungseong?
    }

    private static let sequences: [(strokes: [CheonjiinStroke], vowel: Jungseong)] = [
        // 기본/y계 10개 모음
        ([.i], .ㅣ),
        ([.i, .dot], .ㅏ),
        ([.i, .dot, .dot], .ㅑ),
        ([.dot, .i], .ㅓ),
        ([.dot, .dot, .i], .ㅕ),
        ([.dot, .eu], .ㅗ),
        ([.dot, .dot, .eu], .ㅛ),
        ([.eu, .dot], .ㅜ),
        ([.eu, .dot, .dot], .ㅠ),
        ([.eu], .ㅡ),

        // ㅣ-결합 이중모음: 기본 모음 시퀀스 뒤에 ㅣ를 이어붙인다
        ([.i, .dot, .i], .ㅐ),             // ㅏ+ㅣ
        ([.i, .dot, .dot, .i], .ㅒ),       // ㅑ+ㅣ
        ([.dot, .i, .i], .ㅔ),             // ㅓ+ㅣ
        ([.dot, .dot, .i, .i], .ㅖ),       // ㅕ+ㅣ
        ([.eu, .i], .ㅢ),                  // ㅡ+ㅣ

        // ㅗ/ㅜ 계열 복합 이중모음: ㅗ(ㆍㅡ)/ㅜ(ㅡㆍ) 시퀀스 뒤에 ㅣ, ㅏ/ㅓ, ㅐ/ㅔ를 이어붙인다
        ([.dot, .eu, .i], .ㅚ),                    // ㅗ+ㅣ
        ([.dot, .eu, .i, .dot], .ㅘ),               // ㅗ+ㅏ
        ([.dot, .eu, .i, .dot, .i], .ㅙ),           // ㅗ+ㅐ
        ([.eu, .dot, .i], .ㅟ),                     // ㅜ+ㅣ
        ([.eu, .dot, .dot, .i], .ㅝ),                // ㅜ+ㅓ
        ([.eu, .dot, .dot, .i, .i], .ㅞ),            // ㅜ+ㅔ
    ]

    private static func buildTrie() -> Node {
        let root = Node()
        for (strokes, vowel) in sequences {
            var current = root
            for stroke in strokes {
                if let next = current.children[stroke] {
                    current = next
                } else {
                    let next = Node()
                    current.children[stroke] = next
                    current = next
                }
            }
            current.vowel = vowel
        }
        return root
    }

    private let root = CheonjiinResolver.buildTrie()
    private var currentNode: Node

    init() {
        currentNode = root
    }

    /// 아직 확정되지 않고 버퍼에 쌓여있는 모음 (프리뷰 표시용).
    var pendingVowel: Jungseong? {
        currentNode.vowel
    }

    /// 스트로크 하나를 입력한다.
    /// 버퍼를 계속 확장할 수 있으면 nil을 반환하고(대기), 더 이상 확장 불가능해
    /// 이전 버퍼가 확정되면 그 모음을 반환한다. 확정을 유발한 스트로크는 버려지지
    /// 않고 새 버퍼의 시작으로 재사용된다.
    @discardableResult
    func input(_ stroke: CheonjiinStroke) -> Jungseong? {
        if let next = currentNode.children[stroke] {
            currentNode = next
            return nil
        }

        let committed = currentNode.vowel
        currentNode = root
        if let next = currentNode.children[stroke] {
            currentNode = next
        }
        return committed
    }

    /// 대기 중인 버퍼를 강제로 확정한다. 천지인 스트로크가 아닌 다른 입력이
    /// 들어오기 직전에 호출해서, 미완성 상태로 남은 모음이 유실되지 않게 한다.
    @discardableResult
    func flush() -> Jungseong? {
        let committed = currentNode.vowel
        currentNode = root
        return committed
    }

    /// 버퍼를 비우고 확정하지 않는다 (예: 외부에서 텍스트 필드가 초기화될 때).
    func reset() {
        currentNode = root
    }
}
