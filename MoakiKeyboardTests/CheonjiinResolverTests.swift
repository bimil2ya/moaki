import XCTest

final class CheonjiinResolverTests: XCTestCase {

    var resolver: CheonjiinResolver!

    override func setUp() {
        super.setUp()
        resolver = CheonjiinResolver()
    }

    override func tearDown() {
        resolver = nil
        super.tearDown()
    }

    // MARK: - Single Stroke (flush 전까지는 확정되지 않음)

    func testEuAlonePendingUntilFlushed() {
        XCTAssertNil(resolver.input(.eu))
        XCTAssertEqual(resolver.flush(), .ㅡ)
    }

    func testIAlonePendingUntilFlushed() {
        XCTAssertNil(resolver.input(.i))
        XCTAssertEqual(resolver.flush(), .ㅣ)
    }

    // MARK: - Basic Two-Stroke Vowels

    func testAVowel() {
        XCTAssertNil(resolver.input(.i))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertEqual(resolver.flush(), .ㅏ)
    }

    func testEoVowel() {
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.i))
        XCTAssertEqual(resolver.flush(), .ㅓ)
    }

    func testOVowel() {
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.eu))
        XCTAssertEqual(resolver.flush(), .ㅗ)
    }

    func testUVowel() {
        XCTAssertNil(resolver.input(.eu))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertEqual(resolver.flush(), .ㅜ)
    }

    // MARK: - Y-Glide (Triple Stroke) Vowels

    func testYaVowel() {
        XCTAssertNil(resolver.input(.i))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertEqual(resolver.flush(), .ㅑ)
    }

    func testYeoVowel() {
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.i))
        XCTAssertEqual(resolver.flush(), .ㅕ)
    }

    func testYoVowel() {
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.eu))
        XCTAssertEqual(resolver.flush(), .ㅛ)
    }

    func testYuVowel() {
        XCTAssertNil(resolver.input(.eu))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertEqual(resolver.flush(), .ㅠ)
    }

    // MARK: - Auto-commit When Extension Is Blocked

    func testAutoCommitsWhenNextStrokeCannotExtend() {
        // ㅣ는 ㆍ로 이어지면 ㅏ가 될 수 있지만, ㅡ는 이어질 수 없으므로 즉시 확정된다.
        XCTAssertNil(resolver.input(.i))
        XCTAssertEqual(resolver.input(.eu), .ㅣ)
        // 확정을 유발한 ㅡ는 버려지지 않고 새 버퍼로 이어진다.
        XCTAssertEqual(resolver.flush(), .ㅡ)
    }

    func testAutoCommitsAAndRestartsBufferWithNextStroke() {
        XCTAssertNil(resolver.input(.i))
        XCTAssertNil(resolver.input(.dot))
        // ㅏ(ㅣㆍ) 다음에 ㅡ가 오면 더 확장할 수 없어 ㅏ가 확정되고, ㅡ가 새 버퍼로 시작된다.
        XCTAssertEqual(resolver.input(.eu), .ㅏ)
        XCTAssertEqual(resolver.flush(), .ㅡ)
    }

    func testYaTerminatesAndNextStrokeStartsFreshBuffer() {
        XCTAssertNil(resolver.input(.i))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.dot)) // ㅑ, 더 이상 확장 불가능한 완성 상태
        XCTAssertEqual(resolver.input(.eu), .ㅑ)
        XCTAssertEqual(resolver.flush(), .ㅡ)
    }

    // MARK: - Pending Vowel Preview

    func testPendingVowelPreview() {
        XCTAssertNil(resolver.pendingVowel)
        _ = resolver.input(.i)
        XCTAssertEqual(resolver.pendingVowel, .ㅣ)
        _ = resolver.input(.dot)
        XCTAssertEqual(resolver.pendingVowel, .ㅏ)
    }

    // MARK: - ㅣ-결합 이중모음 (기본 모음 시퀀스 + ㅣ)

    func testAeVowel() {
        XCTAssertNil(resolver.input(.i))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.i))
        XCTAssertEqual(resolver.flush(), .ㅐ)
    }

    func testYaeVowel() {
        XCTAssertNil(resolver.input(.i))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.i))
        XCTAssertEqual(resolver.flush(), .ㅒ)
    }

    func testEVowel() {
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.i))
        XCTAssertNil(resolver.input(.i))
        XCTAssertEqual(resolver.flush(), .ㅔ)
    }

    func testYeVowel() {
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.i))
        XCTAssertNil(resolver.input(.i))
        XCTAssertEqual(resolver.flush(), .ㅖ)
    }

    func testEuiVowel() {
        XCTAssertNil(resolver.input(.eu))
        XCTAssertNil(resolver.input(.i))
        XCTAssertEqual(resolver.flush(), .ㅢ)
    }

    // MARK: - ㅗ/ㅜ 계열 복합 이중모음

    func testOeVowel() {
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.eu))
        XCTAssertNil(resolver.input(.i))
        XCTAssertEqual(resolver.flush(), .ㅚ)
    }

    func testWaVowel() {
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.eu))
        XCTAssertNil(resolver.input(.i))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertEqual(resolver.flush(), .ㅘ)
    }

    func testWaeVowel() {
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.eu))
        XCTAssertNil(resolver.input(.i))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.i))
        XCTAssertEqual(resolver.flush(), .ㅙ)
    }

    func testWiVowel() {
        XCTAssertNil(resolver.input(.eu))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.i))
        XCTAssertEqual(resolver.flush(), .ㅟ)
    }

    func testWeoVowel() {
        XCTAssertNil(resolver.input(.eu))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.i))
        XCTAssertEqual(resolver.flush(), .ㅝ)
    }

    func testWeVowel() {
        XCTAssertNil(resolver.input(.eu))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.i))
        XCTAssertNil(resolver.input(.i))
        XCTAssertEqual(resolver.flush(), .ㅞ)
    }

    /// 핵심 회귀 테스트: ㅡㆍㆍ까지는 ㅠ와 프리픽스가 같지만, 뒤에 ㅣ가 이어지면
    /// (직전까지의 버그처럼) ㅠ로 조급하게 확정되지 않고 ㅝ로 계속 확장되어야 한다.
    func testYuPrefixDoesNotBlockWeoExtension() {
        XCTAssertNil(resolver.input(.eu))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertNil(resolver.input(.dot))
        XCTAssertEqual(resolver.pendingVowel, .ㅠ) // 여기까지는 ㅠ로도 완성 가능한 상태
        XCTAssertNil(resolver.input(.i)) // 그러나 ㅣ가 더 오면 ㅝ로 확장
        XCTAssertEqual(resolver.flush(), .ㅝ)
    }

    // MARK: - Flush / Reset

    func testFlushWithNoPendingBufferReturnsNil() {
        XCTAssertNil(resolver.flush())
    }

    func testFlushIsIdempotent() {
        _ = resolver.input(.eu)
        XCTAssertEqual(resolver.flush(), .ㅡ)
        XCTAssertNil(resolver.flush())
    }

    func testResetDiscardsPendingBufferWithoutCommitting() {
        _ = resolver.input(.i)
        resolver.reset()
        XCTAssertNil(resolver.flush())
    }
}
