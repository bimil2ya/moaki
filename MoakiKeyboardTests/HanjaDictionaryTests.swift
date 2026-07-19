import XCTest

final class HanjaDictionaryTests: XCTestCase {

    func testKnownSyllableReturnsCandidatesWithReadings() {
        let candidates = HanjaDictionary.shared.candidates(for: "가")

        XCTAssertFalse(candidates.isEmpty)
        XCTAssertTrue(candidates.contains { $0.hanja == "可" && $0.reading == "옳을 가" })
        XCTAssertTrue(candidates.contains { $0.hanja == "家" })
    }

    func testUnknownCharacterReturnsEmpty() {
        XCTAssertTrue(HanjaDictionary.shared.candidates(for: "A").isEmpty)
        XCTAssertTrue(HanjaDictionary.shared.candidates(for: "🙂").isEmpty)
    }

    func testCandidatesHaveNoEmptyHanja() {
        // 사전 전체가 잘못 파싱돼 빈 항목이 섞여 들어가지 않는지 확인.
        let candidates = HanjaDictionary.shared.candidates(for: "가")
        for candidate in candidates {
            XCTAssertFalse(String(candidate.hanja).isEmpty)
        }
    }
}
