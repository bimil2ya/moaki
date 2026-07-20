import XCTest

@MainActor
final class KeyboardViewModelHanjaTests: XCTestCase {
    private var viewModel: KeyboardViewModel!
    private var delegate: SpyKeyboardDelegate!

    override func setUp() {
        super.setUp()
        viewModel = KeyboardViewModel(snippetsProvider: { [] })
        delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate
    }

    override func tearDown() {
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    func testShowHanjaCandidatesPopulatesCandidatesForKnownSyllable() {
        delegate.characterBeforeCursorStub = "가"
        viewModel.showHanjaCandidates()

        XCTAssertFalse(viewModel.hanjaCandidates.isEmpty)
        XCTAssertTrue(viewModel.hanjaCandidates.contains { $0.hanja == "可" })
    }

    func testShowHanjaCandidatesEmptyForNonHangulCharacter() {
        delegate.characterBeforeCursorStub = "A"
        viewModel.showHanjaCandidates()

        XCTAssertTrue(viewModel.hanjaCandidates.isEmpty)
    }

    func testShowHanjaCandidatesEmptyWhenNoCharacterBeforeCursor() {
        delegate.characterBeforeCursorStub = nil
        viewModel.showHanjaCandidates()

        XCTAssertTrue(viewModel.hanjaCandidates.isEmpty)
    }

    func testSelectHanjaCandidateReplacesCharacter() {
        delegate.characterBeforeCursorStub = "가"
        viewModel.showHanjaCandidates()
        guard let candidate = viewModel.hanjaCandidates.first(where: { $0.hanja == "家" }) else {
            XCTFail("expected 家 candidate for 가")
            return
        }

        viewModel.selectHanjaCandidate(candidate)

        XCTAssertEqual(delegate.deleteCount, 1)
        XCTAssertEqual(delegate.insertedTexts, ["家"])
        XCTAssertTrue(viewModel.hanjaCandidates.isEmpty)
    }

    func testTypingConsonantDismissesHanjaCandidates() {
        delegate.characterBeforeCursorStub = "가"
        viewModel.showHanjaCandidates()
        XCTAssertFalse(viewModel.hanjaCandidates.isEmpty)

        viewModel.inputConsonant(.ㄴ)

        XCTAssertTrue(viewModel.hanjaCandidates.isEmpty)
    }

    // MARK: - 코드 중복 정리(prepareForRegularInputAction) 사전 예외 회귀 테스트
    // 아래 4개는 리팩터링/P1 수정 전 코드에서도 이미 성립하는 계약을 고정한다.
    // "묶으면 안 되는" 예외(inputSymbol의 순환 리셋 제외, 한자/문구 배열 상호정리)가
    // 이후 작업 내내 깨지지 않는지 지켜주는 안전망이다.

    /// inputSymbol이 resetPunctuationCycle()을 의도적으로 안 부르는 이유가 이 순환이
    /// 깨지지 않기 위해서이므로, 이 테스트가 그 존재 이유를 직접 증명한다.
    func testPunctuationClusterCyclesThroughAllFourSymbols() {
        for _ in 0..<5 {
            viewModel.inputPunctuationCluster()
        }
        XCTAssertEqual(delegate.insertedTexts, [".", ",", "?", "!", "."])
    }

    /// showHanjaCandidates()가 이미 채워진 문구 후보 배열을 비우는지 확인한다("배열이
    /// 원래 비어있었다"가 아니라 "실제로 비워졌다"를 증명하기 위해 문구를 먼저 채운다).
    func testShowingHanjaCandidatesClearsSnippetCandidateArray() {
        let localDelegate = SpyKeyboardDelegate()
        let localViewModel = KeyboardViewModel(snippetsProvider: { ["테스트 문구"] })
        localViewModel.delegate = localDelegate

        localViewModel.showSnippetCandidates()
        XCTAssertFalse(localViewModel.snippetCandidates.isEmpty)

        localDelegate.characterBeforeCursorStub = "가"
        localViewModel.showHanjaCandidates()

        XCTAssertTrue(localViewModel.snippetCandidates.isEmpty)
    }

    /// showSnippetCandidates()가 이미 채워진 한자 후보 배열을 비우는지 확인한다.
    func testShowingSnippetCandidatesClearsHanjaCandidateArray() {
        delegate.characterBeforeCursorStub = "가"
        viewModel.showHanjaCandidates()
        XCTAssertFalse(viewModel.hanjaCandidates.isEmpty)

        viewModel.showSnippetCandidates()

        XCTAssertTrue(viewModel.hanjaCandidates.isEmpty)
    }

    /// inputConsonant가 resetPunctuationCycle()을 부른다는 계약: 문장부호를 입력해
    /// 순환 인덱스를 이동시킨 뒤 자음을 입력하면, 그다음 문장부호는 처음(".")부터
    /// 다시 시작해야 한다.
    func testInputConsonantResetsPunctuationCycle() {
        viewModel.inputPunctuationCluster() // "."
        viewModel.inputPunctuationCluster() // ","
        viewModel.inputConsonant(.ㄱ)
        viewModel.inputPunctuationCluster()

        XCTAssertEqual(delegate.insertedTexts.last, ".")
    }
}
