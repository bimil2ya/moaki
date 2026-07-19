import XCTest

/// VoiceOver 접근성 모음 선택 경로(드래그 제스처를 전혀 거치지 않는 별도 입력)가
/// 기존 inputConsonant/inputVowel을 그대로 재사용해 올바른 음절을 조합하는지 확인한다.
final class KeyboardViewModelAccessibilityVowelTests: XCTestCase {
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

    func testShowPickerThenSelectComposesConsonantAndVowelWithoutGesture() {
        viewModel.showAccessibilityVowelPicker(for: .ㄱ)
        XCTAssertEqual(viewModel.accessibilityVowelPickerConsonant, .ㄱ)

        viewModel.selectAccessibilityVowel(.ㅏ)

        XCTAssertEqual(delegate.composingUpdates.last?.current, "가")
        XCTAssertNil(viewModel.accessibilityVowelPickerConsonant, "선택 후에는 바가 닫혀야 함")
    }

    func testShowPickerThenSelectWorksForYVowelsTooWithoutAnyGesture() {
        viewModel.showAccessibilityVowelPicker(for: .ㅂ)
        viewModel.selectAccessibilityVowel(.ㅑ)
        XCTAssertEqual(delegate.composingUpdates.last?.current, "뱌")
    }

    func testCancelClosesPickerWithoutComposingAnything() {
        viewModel.showAccessibilityVowelPicker(for: .ㄱ)
        viewModel.dismissAccessibilityVowelPicker()

        XCTAssertNil(viewModel.accessibilityVowelPickerConsonant)
        XCTAssertTrue(delegate.composingUpdates.isEmpty)
    }

    /// 접근성 경로가 gestureAnalyzer/gestureDirections 등 기존 드래그 상태를 전혀
    /// 건드리지 않는지 확인 — 호출 전후로 진행 중이던 제스처 관련 published 상태가
    /// 그대로 유지되어야 한다.
    func testAccessibilityPathDoesNotDisturbInProgressGestureState() {
        viewModel.gestureStarted(row: 1, column: 1, at: CGPoint(x: 0, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 10, y: 0))
        let activeKeyBefore = viewModel.activeKey?.row
        let gestureStartBefore = viewModel.gestureStartPoint

        viewModel.showAccessibilityVowelPicker(for: .ㄴ)
        viewModel.selectAccessibilityVowel(.ㅓ)

        XCTAssertEqual(viewModel.activeKey?.row, activeKeyBefore)
        XCTAssertEqual(viewModel.gestureStartPoint, gestureStartBefore)
    }

    /// 한자/문구 후보 바가 떠 있으면 접근성 모음 선택 바를 열 때 서로 닫혀야
    /// (동시에 여러 오버레이가 뜨지 않아야) 한다.
    func testShowingPickerDismissesOtherCandidateBars() {
        delegate.characterBeforeCursorStub = "가"
        viewModel.showHanjaCandidates()
        XCTAssertFalse(viewModel.hanjaCandidates.isEmpty)

        viewModel.showAccessibilityVowelPicker(for: .ㄱ)

        XCTAssertTrue(viewModel.hanjaCandidates.isEmpty)
        XCTAssertEqual(viewModel.accessibilityVowelPickerConsonant, .ㄱ)
    }

    // MARK: - P1: 후보 바 ↔ 접근성 피커 상호배타 (반대 방향)
    // 위 testShowingPickerDismissesOtherCandidateBars는 "피커를 열 때 후보 바가
    // 닫히는지"만 확인한다. 반대로 "후보 바를 열 때 피커가 닫히는지"는 현재
    // showHanjaCandidates/showSnippetCandidates가 서로의 배열만 지우고
    // accessibilityVowelPickerConsonant는 건드리지 않아 실패한다(P1 버그).
    // 두 테스트 모두 "피커가 닫힘"뿐 아니라 "후보가 실제로 채워짐"까지 확인해,
    // 후보 표시 자체가 깨진 채로 통과해버리는 일이 없게 한다.

    func testShowingHanjaCandidatesClosesAccessibilityPicker() {
        delegate.characterBeforeCursorStub = "가"
        viewModel.showAccessibilityVowelPicker(for: .ㄱ)

        viewModel.showHanjaCandidates()

        XCTAssertNil(viewModel.accessibilityVowelPickerConsonant)
        XCTAssertFalse(viewModel.hanjaCandidates.isEmpty)
    }

    func testShowingSnippetCandidatesClosesAccessibilityPicker() {
        let localDelegate = SpyKeyboardDelegate()
        let localViewModel = KeyboardViewModel(snippetsProvider: { ["테스트 문구"] })
        localViewModel.delegate = localDelegate

        localViewModel.showAccessibilityVowelPicker(for: .ㄱ)
        localViewModel.showSnippetCandidates()

        XCTAssertNil(localViewModel.accessibilityVowelPickerConsonant)
        XCTAssertEqual(localViewModel.snippetCandidates, ["테스트 문구"])
    }
}
