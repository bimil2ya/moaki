import XCTest

final class KeyboardViewModelCheonjiinTests: XCTestCase {
    private var viewModel: KeyboardViewModel!
    private var delegate: SpyKeyboardDelegate!

    override func setUp() {
        super.setUp()
        viewModel = KeyboardViewModel()
        delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate
    }

    override func tearDown() {
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    /// 회귀 테스트: ㅏ(ㅣㆍ)는 ㅑ(ㅣㆍㆍ)와 앞부분이 겹쳐서, 다른 입력 없이는 확정되지
    /// 않고 previewVowel로만 대기 상태가 보여야 한다.
    func testBasicVowelStaysPendingWithLivePreviewUntilFollowUpInput() {
        viewModel.inputConsonant(.ㄱ)
        viewModel.inputCheonjiinStroke(.i)
        viewModel.inputCheonjiinStroke(.dot)

        XCTAssertEqual(viewModel.previewVowel, .ㅏ)
        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "가" })

        // 다른 입력(자음)이 들어오면 대기 중이던 ㅏ가 그제서야 확정된다.
        viewModel.inputConsonant(.ㄴ)
        XCTAssertTrue(delegate.composingUpdates.contains { $0.current == "가" })
    }

    func testWaCompoundVowelFormsDirectlyFromCheonjiinTapsWithoutIntermediateCommit() {
        viewModel.inputConsonant(.ㄱ)
        [.dot, .eu, .i, .dot].forEach { viewModel.inputCheonjiinStroke($0) }

        // ㅗ나 ㅚ로 조급하게 확정되지 않고 ㅘ로 대기 중이어야 한다.
        XCTAssertEqual(viewModel.previewVowel, .ㅘ)
        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "고" })
        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "괴" })

        viewModel.inputConsonant(.ㄴ) // 대기 중이던 ㅘ 확정
        XCTAssertTrue(delegate.composingUpdates.contains { $0.current == "과" })
    }

    func testWeCompoundVowelFormsDirectlyFromCheonjiinTaps() {
        viewModel.inputConsonant(.ㄱ)
        [.eu, .dot, .dot, .i, .i].forEach { viewModel.inputCheonjiinStroke($0) }

        XCTAssertEqual(viewModel.previewVowel, .ㅞ)

        viewModel.inputConsonant(.ㄴ)
        XCTAssertTrue(delegate.composingUpdates.contains { $0.current == "궤" })
    }

    func testFlushPendingCheonjiinOnBackspaceCommitsThenDeletes() {
        viewModel.inputConsonant(.ㄱ)
        viewModel.inputCheonjiinStroke(.i)
        viewModel.inputCheonjiinStroke(.dot) // ㅏ 대기 중

        viewModel.deleteBackward()

        // 대기 중이던 ㅏ가 먼저 확정되어 "가"가 됐다가, 백스페이스로 모음이 지워진다.
        XCTAssertTrue(delegate.composingUpdates.contains { $0.current == "가" })
        XCTAssertEqual(delegate.composingUpdates.last?.current, "ㄱ")
    }

    /// 키보드 전환·백그라운드 전환 직전(KeyboardViewController.viewWillDisappear)에
    /// 호출되는 경로 — 천지인 조합 대기 중인 모음을 조용히 버리지 않고 확정해야 한다.
    func testFlushPendingStateBeforeDisappearingCommitsPendingCheonjiinVowel() {
        viewModel.inputConsonant(.ㄱ)
        viewModel.inputCheonjiinStroke(.i)
        viewModel.inputCheonjiinStroke(.dot) // ㅏ 대기 중, 아직 확정 안 됨

        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "가" })

        viewModel.flushPendingStateBeforeDisappearing()

        XCTAssertTrue(delegate.composingUpdates.contains { $0.current == "가" }, "사라지기 전에 대기 중이던 모음이 확정되어야 함")
        XCTAssertNil(viewModel.previewVowel)
    }

    /// 대기 중인 자동확정 타이머 자체도 함께 정리되어야, 화면이 사라진 뒤 엉뚱한
    /// 시점에 다시 입력이 실행되는 일이 없다(무효화하지 않으면 이미 flush로 확정된
    /// 모음을 나중에 타이머가 또 한 번 확정하려 들 수 있다).
    func testFlushPendingStateBeforeDisappearingDoesNotDoubleCommitLater() {
        viewModel.inputConsonant(.ㄴ)
        viewModel.inputCheonjiinStroke(.eu)
        viewModel.flushPendingStateBeforeDisappearing()

        let countAfterFlush = delegate.composingUpdates.count

        let expectation = expectation(description: "wait past the original auto-commit delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(delegate.composingUpdates.count, countAfterFlush, "타이머가 취소되지 않았다면 나중에 중복으로 더 입력됐을 것")
    }
}
