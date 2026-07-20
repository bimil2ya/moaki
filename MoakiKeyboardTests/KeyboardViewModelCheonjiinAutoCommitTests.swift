import XCTest

@MainActor
final class KeyboardViewModelCheonjiinAutoCommitTests: XCTestCase {
    private var viewModel: KeyboardViewModel!
    private var delegate: SpyKeyboardDelegate!

    override func setUp() {
        super.setUp()
        viewModel = KeyboardViewModel(cheonjiinAutoCommitDelay: 0.05)
        delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate
    }

    override func tearDown() {
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    /// 실제 천지인 키패드처럼, 스트로크 입력이 멈추고 일정 시간이 지나면 뒤따르는
    /// 입력 없이도 대기 중이던 모음이 저절로 확정되어야 한다.
    func testPendingVowelAutoCommitsAfterIdleDelayWithoutFollowUpInput() {
        viewModel.inputConsonant(.ㄱ)
        viewModel.inputCheonjiinStroke(.i)
        viewModel.inputCheonjiinStroke(.dot)

        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "가" })

        let expectation = expectation(description: "auto-commit fires")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(delegate.composingUpdates.contains { $0.current == "가" })
        XCTAssertNil(viewModel.previewVowel)
    }

    /// 회귀 테스트: 자동확정 딜레이가 너무 짧으면, 두 번째 스트로크가 도착하기 전에
    /// 첫 스트로크가 조급하게 확정되어 조합이 깨진다("ㄹ+ㅡ+ㆍ"가 "루"가 아니라 "르"로
    /// 끊기는 버그가 실제로 있었다 — 딜레이를 0.45초에서 0.3초로 줄였다가 발생). 이 테스트는
    /// 딜레이 안에 두 번째 스트로크가 도착하면 반드시 조합(ㅡ+ㆍ=ㅜ)이 성립해야 함을 고정한다.
    func testSecondStrokeArrivingBeforeAutoCommitStillCombinesCorrectly() {
        let comboViewModel = KeyboardViewModel(cheonjiinAutoCommitDelay: 0.3)
        let comboDelegate = SpyKeyboardDelegate()
        comboViewModel.delegate = comboDelegate

        comboViewModel.inputConsonant(.ㄹ)
        comboViewModel.inputCheonjiinStroke(.eu) // ㅡ 대기 중

        let expectation = expectation(description: "second stroke arrives before auto-commit")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            comboViewModel.inputCheonjiinStroke(.dot) // 딜레이(0.3초)가 끝나기 전에 도착 -> ㅜ로 조합돼야 함
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(comboViewModel.previewVowel, .ㅜ, "ㅡ가 조급하게 확정되지 않고 ㆍ와 결합해 ㅜ 대기 상태여야 함")
        XCTAssertFalse(comboDelegate.composingUpdates.contains { $0.current == "르" }, "ㅡ가 단독으로 먼저 확정되면 안 됨")
    }
}
