import XCTest

final class HangulConstantsTests: XCTestCase {
    func testComposeSyllableBoundaryValues() {
        XCTAssertEqual(HangulConstants.composeSyllable(choseong: .ㄱ, jungseong: .ㅏ), "가")
        XCTAssertEqual(
            HangulConstants.composeSyllable(choseong: .ㅎ, jungseong: .ㅣ, jongseong: .ㅎ),
            "힣"
        )
    }

    func testDecomposeSyllableBoundaryValuesRoundTrip() throws {
        let ga = try XCTUnwrap(HangulConstants.decomposeSyllable("가"))
        XCTAssertEqual(ga.0, .ㄱ)
        XCTAssertEqual(ga.1, .ㅏ)
        XCTAssertEqual(ga.2, Jongseong.none)

        let hih = try XCTUnwrap(HangulConstants.decomposeSyllable("힣"))
        XCTAssertEqual(hih.0, .ㅎ)
        XCTAssertEqual(hih.1, .ㅣ)
        XCTAssertEqual(hih.2, .ㅎ)
    }

    func testDecomposeSyllableReturnsNilOutsideHangulSyllableRange() {
        XCTAssertNil(HangulConstants.decomposeSyllable("a"))
        XCTAssertNil(HangulConstants.decomposeSyllable("ㄱ")) // 호환 자모, 완성형 음절 아님
        XCTAssertNil(HangulConstants.decomposeSyllable("可")) // 한자
    }

    func testIsHangulSyllable() {
        XCTAssertTrue(HangulConstants.isHangulSyllable("가"))
        XCTAssertTrue(HangulConstants.isHangulSyllable("힣"))
        XCTAssertFalse(HangulConstants.isHangulSyllable("ㄱ"))
        XCTAssertFalse(HangulConstants.isHangulSyllable("a"))
        XCTAssertFalse(HangulConstants.isHangulSyllable("可"))
    }

    func testIsHangulJamo() {
        XCTAssertTrue(HangulConstants.isHangulJamo("ㄱ"))
        XCTAssertFalse(HangulConstants.isHangulJamo("가"))
        XCTAssertFalse(HangulConstants.isHangulJamo("a"))
    }

    /// 완성형 한글 11,172자(19×21×28) 전수 round-trip 검증. 이 함수가 다루는 전체
    /// 공간이 작아 전수 검사 비용이 매우 낮고, Choseong/Jungseong/Jongseong enum의
    /// rawValue 순서나 오프셋 계산 오류를 한꺼번에 잡아준다.
    func testComposeDecomposeRoundTripForAllSyllables() throws {
        for codePoint in HangulConstants.syllableBase...HangulConstants.syllableEnd {
            let character = Character(UnicodeScalar(codePoint)!)
            let codePointDescription = "U+\(String(codePoint, radix: 16, uppercase: true))"
            let parts = try XCTUnwrap(
                HangulConstants.decomposeSyllable(character),
                "\(codePointDescription)를 분해하지 못함"
            )
            XCTAssertEqual(
                HangulConstants.composeSyllable(choseong: parts.0, jungseong: parts.1, jongseong: parts.2),
                character,
                "\(codePointDescription) round-trip 실패"
            )
        }
    }
}
