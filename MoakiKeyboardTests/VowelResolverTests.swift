import XCTest

final class VowelResolverTests: XCTestCase {

    var resolver: VowelResolver!

    override func setUp() {
        super.setUp()
        resolver = VowelResolver()
    }

    override func tearDown() {
        resolver = nil
        super.tearDown()
    }

    // MARK: - Basic Vowel Tests

    func testBasicVowels() {
        // ㅗ = ↑
        XCTAssertEqual(resolver.resolve(directions: [.up]).vowel, .ㅗ)

        // ㅜ = ↓
        XCTAssertEqual(resolver.resolve(directions: [.down]).vowel, .ㅜ)

        // ㅏ = →
        XCTAssertEqual(resolver.resolve(directions: [.right]).vowel, .ㅏ)

        // ㅓ = ←
        XCTAssertEqual(resolver.resolve(directions: [.left]).vowel, .ㅓ)

        // ㅜ = ↙ (normalizes to ↓)
        XCTAssertEqual(resolver.resolve(directions: [.downLeft]).vowel, .ㅜ)

        // ㅗ = ↖ (normalizes to ↑)
        XCTAssertEqual(resolver.resolve(directions: [.upLeft]).vowel, .ㅗ)
    }

    // MARK: - Y-Vowel Tests (Triple Direction)

    func testYVowels() {
        // ㅛ = ↑↓↑
        XCTAssertEqual(resolver.resolve(directions: [.up, .down, .up]).vowel, .ㅛ)

        // ㅠ = ↓↑↓
        XCTAssertEqual(resolver.resolve(directions: [.down, .up, .down]).vowel, .ㅠ)

        // ㅑ = →←→
        XCTAssertEqual(resolver.resolve(directions: [.right, .left, .right]).vowel, .ㅑ)

        // ㅕ = ←→←
        XCTAssertEqual(resolver.resolve(directions: [.left, .right, .left]).vowel, .ㅕ)
    }

    // MARK: - Y-Vowel Diagonal Drift Tests

    func testYVowelDiagonalDrift() {
        // ㅛ = ↑↓↗ (세 번째 획이 ↗로 빠질 때)
        XCTAssertEqual(resolver.resolve(directions: [.up, .down, .upRight]).vowel, .ㅛ)

        // ㅛ = ↑↘↗ (중간+세 번째 모두 오른쪽 대각선)
        XCTAssertEqual(resolver.resolve(directions: [.up, .downRight, .upRight]).vowel, .ㅛ)

        // ㅠ = ↓↑↘ (세 번째 획이 ↘로 빠질 때)
        XCTAssertEqual(resolver.resolve(directions: [.down, .up, .downRight]).vowel, .ㅠ)

        // ㅠ = ↓↗↘ (중간+세 번째 모두 오른쪽 대각선)
        XCTAssertEqual(resolver.resolve(directions: [.down, .upRight, .downRight]).vowel, .ㅠ)
    }

    // MARK: - Complex Vowel Tests (Diphthongs)

    func testDiphthongs() {
        // ㅘ = ↑→
        XCTAssertEqual(resolver.resolve(directions: [.up, .right]).vowel, .ㅘ)

        // ㅙ = ↑→←
        XCTAssertEqual(resolver.resolve(directions: [.up, .right, .left]).vowel, .ㅙ)

        // ㅝ = ↓←
        XCTAssertEqual(resolver.resolve(directions: [.down, .left]).vowel, .ㅝ)

        // ㅞ = ↓←→
        XCTAssertEqual(resolver.resolve(directions: [.down, .left, .right]).vowel, .ㅞ)

        // ㅚ = ↑↓
        XCTAssertEqual(resolver.resolve(directions: [.up, .down]).vowel, .ㅚ)

        // ㅟ = ↓↑
        XCTAssertEqual(resolver.resolve(directions: [.down, .up]).vowel, .ㅟ)
    }

    // MARK: - Diphthong Diagonal Drift Tests

    func testDiphthongDiagonalDrift() {
        // ㅙ = ↑→↙ (세 번째 획이 ↙로 빠지면 ← 성분으로 해석)
        XCTAssertEqual(resolver.resolve(directions: [.up, .right, .downLeft]).vowel, .ㅙ)
        XCTAssertEqual(resolver.resolve(directions: [.up, .right, .down]).vowel, .ㅙ)

        // ㅙ = ↑↗← (두 번째 획이 ↗면 → 성분으로 해석)
        XCTAssertEqual(resolver.resolve(directions: [.up, .upRight, .left]).vowel, .ㅙ)

        // ㅙ = ↑↗↙ (두 번째/세 번째 획 모두 대각선이어도 →/← 성분을 추출)
        XCTAssertEqual(resolver.resolve(directions: [.up, .upRight, .downLeft]).vowel, .ㅙ)
        XCTAssertEqual(resolver.resolve(directions: [.up, .upRight, .down]).vowel, .ㅙ)

        // ㅞ = ↓←↘ (세 번째 획이 ↘면 → 성분으로 해석)
        XCTAssertEqual(resolver.resolve(directions: [.down, .left, .downRight]).vowel, .ㅞ)
        XCTAssertEqual(resolver.resolve(directions: [.down, .left, .down]).vowel, .ㅞ)

        // ㅞ = ↓↙→ (두 번째 획이 ↙면 ← 성분으로 해석)
        XCTAssertEqual(resolver.resolve(directions: [.down, .downLeft, .right]).vowel, .ㅞ)

        // ㅞ = ↓↙↘ (두 번째/세 번째 획 모두 대각선이어도 ←/→ 성분을 추출)
        XCTAssertEqual(resolver.resolve(directions: [.down, .downLeft, .downRight]).vowel, .ㅞ)
        XCTAssertEqual(resolver.resolve(directions: [.down, .downLeft, .down]).vowel, .ㅞ)
    }

    func testDiphthongDriftFallsBackToPrefixMatch() {
        // A third stroke that leaves the original axis intentionally selects the extended vowel.
        XCTAssertEqual(resolver.resolve(directions: [.up, .right]).vowel, .ㅘ)
        XCTAssertEqual(resolver.resolve(directions: [.up, .right, .up]).vowel, .ㅙ)

        // Down-left-up is likewise an accepted third-stroke variation for ㅞ.
        XCTAssertEqual(resolver.resolve(directions: [.down, .left, .up]).vowel, .ㅞ)
    }

    // MARK: - Ae/E Vowel Tests

    func testAeEVowels() {
        // ㅐ = →←
        XCTAssertEqual(resolver.resolve(directions: [.right, .left]).vowel, .ㅐ)

        // ㅒ = →←→←
        XCTAssertEqual(resolver.resolve(directions: [.right, .left, .right, .left]).vowel, .ㅒ)

        // ㅔ = ←→
        XCTAssertEqual(resolver.resolve(directions: [.left, .right]).vowel, .ㅔ)

        // ㅖ = ←→←→
        XCTAssertEqual(resolver.resolve(directions: [.left, .right, .left, .right]).vowel, .ㅖ)
    }

    // MARK: - Special Vowels

    func testSpecialVowels() {
        // ㅢ = ↘↖ (오른쪽아래-왼쪽위, 정반대 방향)
        XCTAssertEqual(resolver.resolve(directions: [.downRight, .upLeft]).vowel, .ㅢ)

        // ↘ 다음에 오는 방향은 ㅢ 말고는 의미가 없으므로, 정반대(↖)가 아니어도
        // "계속 같은 방향(↓, →)"만 아니면 전부 ㅢ로 받아들인다.
        XCTAssertEqual(resolver.resolve(directions: [.downRight, .up]).vowel, .ㅢ)
        XCTAssertEqual(resolver.resolve(directions: [.downRight, .left]).vowel, .ㅢ)
        XCTAssertEqual(resolver.resolve(directions: [.downRight, .upRight]).vowel, .ㅢ)
        XCTAssertEqual(resolver.resolve(directions: [.downRight, .downLeft]).vowel, .ㅢ)

        // 하지만 계속 같은 방향으로 가는 것(↓, →)은 ㅢ가 아니다.
        XCTAssertNotEqual(resolver.resolve(directions: [.downRight, .down]).vowel, .ㅢ)
        XCTAssertNotEqual(resolver.resolve(directions: [.downRight, .right]).vowel, .ㅢ)
    }

    // MARK: - Same Relaxation Applied to Other Single-Continuation Nodes

    func testWideAngleAcceptedForAeYaFamily() {
        // → 다음에 오는 획은 ㅐ(그리고 그 연장인 ㅑㅒ) 말고는 뜻이 없으므로,
        // 정확히 ←가 아니어도(↑나 ↓여도) 같은 의도로 본다.
        XCTAssertEqual(resolver.resolve(directions: [.right, .left]).vowel, .ㅐ)
        XCTAssertEqual(resolver.resolve(directions: [.right, .up]).vowel, .ㅐ)
        XCTAssertEqual(resolver.resolve(directions: [.right, .down]).vowel, .ㅐ)
        XCTAssertEqual(resolver.resolve(directions: [.right, .left, .up]).vowel, .ㅑ)
        XCTAssertEqual(resolver.resolve(directions: [.right, .left, .down]).vowel, .ㅑ)
    }

    func testWideAngleAcceptedForEYeoFamily() {
        // ← 다음도 마찬가지로 ㅔ(와 ㅕㅖ) 말고는 뜻이 없다.
        XCTAssertEqual(resolver.resolve(directions: [.left, .right]).vowel, .ㅔ)
        XCTAssertEqual(resolver.resolve(directions: [.left, .up]).vowel, .ㅔ)
        XCTAssertEqual(resolver.resolve(directions: [.left, .down]).vowel, .ㅔ)
        XCTAssertEqual(resolver.resolve(directions: [.left, .right, .up]).vowel, .ㅕ)
        XCTAssertEqual(resolver.resolve(directions: [.left, .right, .down]).vowel, .ㅕ)
    }

    func testWideAngleAcceptedForYoAfterOeAndYuAfterWi() {
        // ↑↓(ㅚ 확정)까지 온 다음의 세 번째 획은 ㅛ 말고는 뜻이 없고,
        // ↓↑(ㅟ 확정) 다음도 ㅠ 말고는 뜻이 없다.
        XCTAssertEqual(resolver.resolve(directions: [.up, .down, .up]).vowel, .ㅛ)
        XCTAssertEqual(resolver.resolve(directions: [.up, .down, .left]).vowel, .ㅛ)
        XCTAssertEqual(resolver.resolve(directions: [.up, .down, .right]).vowel, .ㅛ)
        XCTAssertEqual(resolver.resolve(directions: [.down, .up, .down]).vowel, .ㅠ)
        XCTAssertEqual(resolver.resolve(directions: [.down, .up, .left]).vowel, .ㅠ)
        XCTAssertEqual(resolver.resolve(directions: [.down, .up, .right]).vowel, .ㅠ)
    }

    func testWideAngleAcceptedForWaeAfterWaAndWeAfterWeo() {
        // ↑→(ㅘ 확정) 다음의 세 번째 획은 ㅙ 말고는 뜻이 없고,
        // ↓←(ㅝ 확정) 다음도 ㅞ 말고는 뜻이 없다.
        XCTAssertEqual(resolver.resolve(directions: [.up, .right, .left]).vowel, .ㅙ)
        XCTAssertEqual(resolver.resolve(directions: [.up, .right, .up]).vowel, .ㅙ)
        XCTAssertEqual(resolver.resolve(directions: [.up, .right, .down]).vowel, .ㅙ)
        XCTAssertEqual(resolver.resolve(directions: [.down, .left, .right]).vowel, .ㅞ)
        XCTAssertEqual(resolver.resolve(directions: [.down, .left, .up]).vowel, .ㅞ)
        XCTAssertEqual(resolver.resolve(directions: [.down, .left, .down]).vowel, .ㅞ)
    }

    func testUpAndDownStillDisambiguateAsFirstStroke() {
        // 반대로 ↑/↓가 "첫 획"일 때는 진짜 갈림길이라 정확한 방향이 필요하다.
        XCTAssertEqual(resolver.resolve(directions: [.up, .down]).vowel, .ㅚ)
        XCTAssertEqual(resolver.resolve(directions: [.up, .right]).vowel, .ㅘ)
        XCTAssertEqual(resolver.resolve(directions: [.down, .up]).vowel, .ㅟ)
        XCTAssertEqual(resolver.resolve(directions: [.down, .left]).vowel, .ㅝ)
    }

    // MARK: - Edge Cases

    func testEmptyDirections() {
        let result = resolver.resolve(directions: [])
        XCTAssertNil(result.vowel)
        XCTAssertFalse(result.hasMoreMatches)
    }

    func testPartialMatch() {
        // ↑ alone matches ㅗ
        let result = resolver.resolve(directions: [.up])
        XCTAssertEqual(result.vowel, .ㅗ)
        // But there could be longer matches (↑→ for ㅘ, ↑↓ for ㅚ, etc.)
        XCTAssertTrue(result.hasMoreMatches)
    }

    func testNoMatch() {
        // ↗ should resolve to ㅣ
        let result = resolver.resolve(directions: [.upRight])
        XCTAssertEqual(result.vowel, .ㅣ)
    }

    func testRepeatCollapseAndTrailingDiagonalNormalization() {
        // Repeated same direction should collapse.
        XCTAssertEqual(resolver.resolve(directions: [.up, .up, .down]).vowel, .ㅚ)

        // ㅙ: ↑ + (↗ normalized to →) + ←
        XCTAssertEqual(resolver.resolve(directions: [.up, .up, .upRight, .left]).vowel, .ㅙ)

        // ㅞ: ↓ + (↙ normalized to ←) + (↘ normalized to → via previous horizontal context)
        XCTAssertEqual(resolver.resolve(directions: [.down, .down, .downLeft, .downRight]).vowel, .ㅞ)
    }

    // MARK: - Peek Vowel Tests

    func testPeekVowel() {
        // Should return the current matched vowel without consuming
        XCTAssertEqual(resolver.peekVowel(directions: [.up]), .ㅗ)
        XCTAssertEqual(resolver.peekVowel(directions: [.up, .right]), .ㅘ)
        XCTAssertEqual(resolver.peekVowel(directions: [.down, .right]), .ㅜ) // fallback to best prefix
        XCTAssertNil(resolver.peekVowel(directions: []))
    }

    // MARK: - Potential Match Tests

    func testHasPotentialMatch() {
        // Single direction that could be part of longer pattern
        XCTAssertTrue(resolver.hasPotentialMatch(directions: [.up])) // Could be ㅗ, ㅘ, ㅙ, ㅚ, ㅛ

        // ㅣ is a complete match, and can also be a component of longer patterns
        XCTAssertTrue(resolver.hasPotentialMatch(directions: [.upRight]))
    }

    // MARK: - Gesture Finalization + Resolver Integration

    func testFinalizeAndResolvePreservesWeDiagonalTurn() {
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 128))   // ↓
        analyzer.addPoint(CGPoint(x: 76, y: 152))    // ↙
        analyzer.addPoint(CGPoint(x: 104, y: 152))   // →

        let finalDirections = analyzer.finalizeGesture()
        XCTAssertEqual(finalDirections, [.down, .downLeft, .right])
        XCTAssertEqual(resolver.resolve(directions: finalDirections).vowel, .ㅞ)
    }

    func testFinalizeAndResolvePreservesWaeDiagonalTurn() {
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 72))    // ↑
        analyzer.addPoint(CGPoint(x: 124, y: 48))    // ↗
        analyzer.addPoint(CGPoint(x: 96, y: 48))     // ←

        let finalDirections = analyzer.finalizeGesture()
        XCTAssertEqual(finalDirections, [.up, .upRight, .left])
        XCTAssertEqual(resolver.resolve(directions: finalDirections).vowel, .ㅙ)
    }

    func testWeRequiresLeftFamilySecondStroke() {
        // No left-family evidence in the second stroke, so this should not be ㅞ.
        XCTAssertNotEqual(resolver.resolve(directions: [.down, .right, .down]).vowel, .ㅞ)
        XCTAssertEqual(resolver.resolve(directions: [.down, .right, .down]).vowel, .ㅜ)
    }

    func testResolvePrefersThreeStrokeComplexWhenEvidenceExists() {
        XCTAssertEqual(resolver.resolve(directions: [.down, .downLeft, .downRight]).vowel, .ㅞ)
        XCTAssertEqual(resolver.resolve(directions: [.up, .upRight, .downLeft]).vowel, .ㅙ)
    }
}
