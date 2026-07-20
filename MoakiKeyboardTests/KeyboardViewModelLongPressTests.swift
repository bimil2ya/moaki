import XCTest

@MainActor
final class KeyboardViewModelLongPressTests: XCTestCase {
    private var viewModel: KeyboardViewModel!
    private var delegate: SpyKeyboardDelegate!

    override func setUp() {
        super.setUp()
        viewModel = KeyboardViewModel(
            experimentalYVowelEnabledProvider: { false },
            experimentalYVowelRecorder: { _ in }
        )
        delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate
    }

    override func tearDown() {
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    func testLongPressNumberThenGestureEnd_insertsOnlyNumber() {
        viewModel.gestureStarted(row: 1, column: 1, at: .zero) // ㅂ key
        viewModel.inputLongPressNumber("1")
        viewModel.gestureEnded(row: 1, column: 1)

        XCTAssertEqual(delegate.insertedTexts, ["1"])
        XCTAssertTrue(delegate.composingUpdates.isEmpty)
    }

    func testNormalTapStillInputsConsonant() {
        viewModel.gestureStarted(row: 1, column: 1, at: .zero) // ㅂ key
        viewModel.gestureEnded(row: 1, column: 1)

        XCTAssertEqual(delegate.insertedTexts, [])
        XCTAssertEqual(delegate.composingUpdates.last?.current, "ㅂ")
    }

    func testLongPressSuppressionResetsForNextGesture() {
        viewModel.gestureStarted(row: 1, column: 1, at: .zero)
        viewModel.inputLongPressNumber("1")
        viewModel.gestureEnded(row: 1, column: 1)

        viewModel.gestureStarted(row: 1, column: 2, at: .zero) // ㅈ key
        viewModel.gestureEnded(row: 1, column: 2)

        XCTAssertEqual(delegate.insertedTexts, ["1"])
        XCTAssertEqual(delegate.composingUpdates.last?.current, "ㅈ")
    }

    /// 지구본 버튼: delegate로 전환을 위임하고 햅틱을 울린다. needsInputModeSwitchKey로
    /// 조건부 표시하지 않고 항상 노출하는 설계라, ViewModel 레벨에서는 이 pass-through만
    /// 검증하면 된다(실제 전환 동작은 실기기에서 확인).
    func testSwitchToNextKeyboardDelegatesAndTriggersHaptic() {
        viewModel.switchToNextKeyboard()

        XCTAssertEqual(delegate.switchKeyboardCount, 1)
        XCTAssertEqual(delegate.hapticCount, 1)
    }

    // MARK: - 백스페이스 반복 타이머 정지 회귀

    /// 실제로 의지하는 방어는 타이머 콜백 안의 isBackspacePressing 가드다. 초기
    /// 지연이 끝나기 전에 손을 떼면, 그 이후로 추가 삭제가 전혀 발생하지 않아야 한다.
    func testEndingPressBeforeInitialDelayElapsesPreventsFurtherDeletes() {
        let initialDelay: TimeInterval = 0.02
        let repeatInterval: TimeInterval = 0.01
        let localDelegate = SpyKeyboardDelegate()
        let localViewModel = KeyboardViewModel(
            backspaceRepeatInitialDelay: initialDelay,
            backspaceRepeatInterval: repeatInterval
        )
        localViewModel.delegate = localDelegate

        localViewModel.beginBackspacePress()
        localViewModel.endBackspacePress()

        let noMoreDeletes = expectation(description: "초기 지연 이후 추가 삭제 없음")
        noMoreDeletes.isInverted = true
        localDelegate.onDelete = { noMoreDeletes.fulfill() }
        defer { localDelegate.onDelete = nil }
        let observationWindow = max(initialDelay * 2, 0.05)
        wait(for: [noMoreDeletes], timeout: observationWindow)
    }

    /// 반복 삭제가 이미 시작된 뒤 손을 뗀 경우에도, 그 이후로 추가 삭제가 전혀
    /// 발생하지 않아야 한다.
    func testEndingPressAfterRepeatStartedStopsFurtherDeletes() {
        let initialDelay: TimeInterval = 0.02
        let repeatInterval: TimeInterval = 0.01
        let localDelegate = SpyKeyboardDelegate()
        let localViewModel = KeyboardViewModel(
            backspaceRepeatInitialDelay: initialDelay,
            backspaceRepeatInterval: repeatInterval
        )
        localViewModel.delegate = localDelegate

        // 1단계: 반복이 시작될 때까지 기다린다 (일반 expectation)
        let reachedThree = expectation(description: "반복 삭제 3회 도달")
        var fulfilledReachedThree = false
        localDelegate.onDelete = {
            if localDelegate.deleteCount >= 3 && !fulfilledReachedThree {
                fulfilledReachedThree = true
                reachedThree.fulfill()
            }
        }
        localViewModel.beginBackspacePress()
        defer { localViewModel.endBackspacePress() } // 안전망: 조기 실패로 빠져나가도 반드시 눌림 상태 해제
        wait(for: [reachedThree], timeout: 1.0)

        // 2단계: 손을 뗀 뒤로는 삭제가 다시는 발생하지 않아야 한다 (inverted expectation)
        localViewModel.endBackspacePress()
        let noMoreDeletes = expectation(description: "정지 후 추가 삭제 없음")
        noMoreDeletes.isInverted = true
        localDelegate.onDelete = { noMoreDeletes.fulfill() }
        defer { localDelegate.onDelete = nil }
        let noDeleteObservationWindow = max(repeatInterval * 3, 0.05)
        wait(for: [noMoreDeletes], timeout: noDeleteObservationWindow)
    }
}
