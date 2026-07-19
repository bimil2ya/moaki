import XCTest

final class HangulComposerTests: XCTestCase {

    var composer: HangulComposer!

    override func setUp() {
        super.setUp()
        composer = HangulComposer()
    }

    override func tearDown() {
        composer = nil
        super.tearDown()
    }

    // MARK: - Basic Composition Tests

    func testInitialState() {
        XCTAssertEqual(composer.state, .empty)
        XCTAssertNil(composer.currentComposingCharacter)
        XCTAssertEqual(composer.displayText, "")
    }

    func testSingleChoseong() {
        _ = composer.inputChoseong(.ㄱ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㄱ")
    }

    func testChoseongJungseong() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        XCTAssertEqual(composer.currentComposingCharacter, "가")
    }

    func testCompleteSyllable() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄴ)
        XCTAssertEqual(composer.currentComposingCharacter, "간")
    }

    func testSequentialSyllables() {
        // 안녕
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄴ)
        XCTAssertEqual(composer.currentComposingCharacter, "안")

        _ = composer.inputJungseong(.ㅕ)
        XCTAssertEqual(composer.composedText, "아")
        XCTAssertEqual(composer.currentComposingCharacter, "녀")

        _ = composer.inputChoseong(.ㅇ)
        XCTAssertEqual(composer.currentComposingCharacter, "녕")
    }

    // MARK: - Double Jongseong Tests

    func testDoubleJongseong() {
        // 값
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㅂ)
        _ = composer.inputChoseong(.ㅅ)
        XCTAssertEqual(composer.currentComposingCharacter, "값")
    }

    func testDoubleJongseongSplit() {
        // 읽다 -> 읽 + 다
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅣ)
        _ = composer.inputChoseong(.ㄹ)
        _ = composer.inputChoseong(.ㄱ)
        XCTAssertEqual(composer.currentComposingCharacter, "읽")

        _ = composer.inputJungseong(.ㅏ)
        XCTAssertEqual(composer.composedText, "일")
        XCTAssertEqual(composer.currentComposingCharacter, "가")
    }

    // MARK: - Delete Tests

    func testDeleteChoseong() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.deleteBackward()
        XCTAssertEqual(composer.state, .empty)
        XCTAssertNil(composer.currentComposingCharacter)
    }

    func testDeleteJungseong() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "ㄱ")
    }

    func testDeleteJongseong() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄴ)
        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "가")
    }

    func testDeleteDoubleJongseong() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㅂ)
        _ = composer.inputChoseong(.ㅅ)
        XCTAssertEqual(composer.currentComposingCharacter, "값")

        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "갑")
    }

    // MARK: - Edge Cases

    func testDoubleConsonantCannotBeJongseong() {
        // ㄸ, ㅃ, ㅉ cannot be jongseong
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄸ)

        XCTAssertEqual(composer.composedText, "가")
        XCTAssertEqual(composer.currentComposingCharacter, "ㄸ")
    }

    func testVowelWithoutConsonant() {
        _ = composer.inputJungseong(.ㅏ)
        XCTAssertEqual(composer.composedText, "ㅏ")
        XCTAssertEqual(composer.state, .empty)
    }

    // MARK: - Unicode Composition Tests

    func testUnicodeValues() {
        // 가 = 0xAC00
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        XCTAssertEqual(composer.currentComposingCharacter?.unicodeScalars.first?.value, 0xAC00)

        // 힣 = 0xD7A3 (last syllable)
        composer.reset()
        _ = composer.inputChoseong(.ㅎ)
        _ = composer.inputJungseong(.ㅣ)
        _ = composer.inputChoseong(.ㅎ)
        XCTAssertEqual(composer.currentComposingCharacter?.unicodeScalars.first?.value, 0xD7A3)
    }

    // MARK: - Complex Input Sequences

    func testHelloWorld() {
        // 안녕하세요
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄴ)
        _ = composer.inputChoseong(.ㄴ)
        _ = composer.inputJungseong(.ㅕ)
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputChoseong(.ㅎ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㅅ)
        _ = composer.inputJungseong(.ㅔ)
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅛ)

        composer.commitCurrent()

        XCTAssertEqual(composer.composedText, "안녕하세요")
    }

    func testThankYou() {
        // 감사합니다
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㅁ)
        _ = composer.inputChoseong(.ㅅ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㅎ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㅂ)
        _ = composer.inputChoseong(.ㄴ)
        _ = composer.inputJungseong(.ㅣ)
        _ = composer.inputChoseong(.ㄷ)
        _ = composer.inputJungseong(.ㅏ)

        composer.commitCurrent()

        XCTAssertEqual(composer.composedText, "감사합니다")
    }

    // MARK: - Vowel + Vowel Combination Tests (ㅣ-계 이중모음)

    func testCombineAWithIToAe() {
        // 개 = ㄱ + ㅏ + ㅣ(→ㅐ)
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "개")
    }

    func testCombineYaWithIToYae() {
        // 걔 = ㄱ + ㅑ + ㅣ(→ㅒ)
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅑ)
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "걔")
    }

    func testCombineEoWithIToE() {
        // 게 = ㄱ + ㅓ + ㅣ(→ㅔ)
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅓ)
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "게")
    }

    func testCombineYeoWithIToYe() {
        // 계 = ㄱ + ㅕ + ㅣ(→ㅖ)
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅕ)
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "계")
    }

    // MARK: - replaceCurrentSyllableVowel (드래그 모음 → 점 단축 변환용 엔진 API)

    func testReplaceCurrentSyllableVowelSucceedsWhenExpectedStateMatches() {
        _ = composer.inputChoseong(.ㅎ)
        _ = composer.inputJungseong(.ㅏ)
        guard case .update? = composer.replaceCurrentSyllableVowel(
            expectedChoseong: .ㅎ, expectedJungseong: .ㅏ, with: .ㅑ
        ) else {
            return XCTFail("모음 교체는 update여야 합니다")
        }
        XCTAssertEqual(composer.currentComposingCharacter, "햐")
    }

    func testReplaceCurrentSyllableVowelFailsOnJungseongMismatch() {
        _ = composer.inputChoseong(.ㅎ)
        _ = composer.inputJungseong(.ㅏ)
        let action = composer.replaceCurrentSyllableVowel(
            expectedChoseong: .ㅎ, expectedJungseong: .ㅓ, with: .ㅕ
        )
        XCTAssertNil(action)
        XCTAssertEqual(composer.currentComposingCharacter, "하")
    }

    func testReplaceCurrentSyllableVowelFailsOnChoseongMismatch() {
        _ = composer.inputChoseong(.ㅎ)
        _ = composer.inputJungseong(.ㅏ)
        let action = composer.replaceCurrentSyllableVowel(
            expectedChoseong: .ㄱ, expectedJungseong: .ㅏ, with: .ㅑ
        )
        XCTAssertNil(action)
        XCTAssertEqual(composer.currentComposingCharacter, "하")
    }

    func testReplaceCurrentSyllableVowelFailsOnEmptyState() {
        let action = composer.replaceCurrentSyllableVowel(
            expectedChoseong: .ㅎ, expectedJungseong: .ㅏ, with: .ㅑ
        )
        XCTAssertNil(action)
        XCTAssertNil(composer.currentComposingCharacter)
    }

    func testReplaceCurrentSyllableVowelFailsWhenOnlyChoseong() {
        _ = composer.inputChoseong(.ㅎ)
        let action = composer.replaceCurrentSyllableVowel(
            expectedChoseong: .ㅎ, expectedJungseong: .ㅏ, with: .ㅑ
        )
        XCTAssertNil(action)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅎ")
    }

    func testReplaceCurrentSyllableVowelFailsWhenJongseongPresent() {
        // 한 = ㅎ + ㅏ + ㄴ
        _ = composer.inputChoseong(.ㅎ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄴ)
        XCTAssertEqual(composer.currentComposingCharacter, "한")

        let action = composer.replaceCurrentSyllableVowel(
            expectedChoseong: .ㅎ, expectedJungseong: .ㅏ, with: .ㅑ
        )
        XCTAssertNil(action)
        XCTAssertEqual(composer.currentComposingCharacter, "한")
    }
}
