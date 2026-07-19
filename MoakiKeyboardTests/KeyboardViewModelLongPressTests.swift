import XCTest

final class KeyboardViewModelLongPressTests: XCTestCase {
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
}

final class KeyboardViewModelSpaceCursorMoveTests: XCTestCase {
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

    func testSimpleTapInsertsSpace() {
        viewModel.beginSpacePress(at: CGPoint(x: 100, y: 20))
        viewModel.endSpacePress()

        XCTAssertEqual(delegate.insertedTexts, [" "])
        XCTAssertTrue(delegate.cursorOffsets.isEmpty)
    }

    func testJitterWithinDeadzoneStillInsertsSpace() {
        viewModel.beginSpacePress(at: CGPoint(x: 100, y: 20))
        viewModel.spacePressMoved(to: CGPoint(x: 103, y: 20)) // 데드존(12pt) 이내
        viewModel.endSpacePress()

        XCTAssertEqual(delegate.insertedTexts, [" "])
        XCTAssertTrue(delegate.cursorOffsets.isEmpty)
    }

    func testDragRightMovesCursorForwardWithoutInsertingSpace() {
        viewModel.beginSpacePress(at: CGPoint(x: 100, y: 20))
        viewModel.spacePressMoved(to: CGPoint(x: 115, y: 20)) // 데드존 통과 -> 커서 이동 모드 진입
        viewModel.spacePressMoved(to: CGPoint(x: 130, y: 20)) // 여기서 실제 커서 이동 발생

        XCTAssertTrue(delegate.insertedTexts.isEmpty)
        XCTAssertEqual(delegate.cursorOffsets, [1])

        viewModel.endSpacePress()
        XCTAssertTrue(delegate.insertedTexts.isEmpty) // 커서 이동 모드였으므로 스페이스는 입력되지 않는다
    }

    func testDragLeftMovesCursorBackward() {
        viewModel.beginSpacePress(at: CGPoint(x: 100, y: 20))
        viewModel.spacePressMoved(to: CGPoint(x: 85, y: 20))
        viewModel.spacePressMoved(to: CGPoint(x: 70, y: 20))
        viewModel.endSpacePress()

        XCTAssertTrue(delegate.insertedTexts.isEmpty)
        XCTAssertEqual(delegate.cursorOffsets, [-1])
    }

    func testMultipleStepsAccumulateMultipleCursorMoves() {
        viewModel.beginSpacePress(at: CGPoint(x: 0, y: 0))
        viewModel.spacePressMoved(to: CGPoint(x: 12, y: 0))  // 데드존 통과 (이동 모드 진입, 아직 커서는 안 움직임)
        viewModel.spacePressMoved(to: CGPoint(x: 37, y: 0))  // step(10)이 두 번 들어감

        XCTAssertEqual(delegate.cursorOffsets, [1, 1])
    }

    func testEndSpacePressResetsStateForNextPress() {
        viewModel.beginSpacePress(at: CGPoint(x: 0, y: 0))
        viewModel.spacePressMoved(to: CGPoint(x: 20, y: 0))
        viewModel.endSpacePress()

        // 새로운 프레스는 이전 커서 이동 상태에 영향받지 않고 단순 탭이면 스페이스를 입력한다.
        viewModel.beginSpacePress(at: CGPoint(x: 200, y: 0))
        viewModel.endSpacePress()

        XCTAssertEqual(delegate.insertedTexts, [" "])
    }
}

final class KeyboardViewModelHanjaTests: XCTestCase {
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
}

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
}

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

/// KVM: Y계열(ㅑㅕㅛㅠ) 원점 복귀 인식기(실험적 기능)의 KeyboardViewModel 연결 테스트.
/// GestureAnalyzer 자체의 상태머신 정확성은 GestureAnalyzerTests(GAT)에서 이미 검증했으므로,
/// 여기서는 오직 "토글 게이팅·캐시 시점·카운터 기록 시점"이라는 배선(wiring)만 다룬다.
final class KeyboardViewModelExperimentalYVowelTests: XCTestCase {
    private var delegate: SpyKeyboardDelegate!

    override func setUp() {
        super.setUp()
        delegate = SpyKeyboardDelegate()
    }

    override func tearDown() {
        delegate = nil
        super.tearDown()
    }

    /// ㅂ 키(row:1, column:1) 위에서 오른쪽으로 왕복하는 제스처 — GAT 레벨에서
    /// 이미 confirmedYVowel == .ㅑ로 확정됨을 검증한 것과 동일한 경로.
    private func feedRightRoundTripGesture(on viewModel: KeyboardViewModel) {
        viewModel.gestureStarted(row: 1, column: 1, at: CGPoint(x: 0, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 20, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 40, y: 0))  // out right 40 (outbound 진입 >= 30)
        viewModel.gestureMoved(to: CGPoint(x: 20, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 5, y: 0))   // 원점 5px 이내 (복귀 반경 8 이내)
        viewModel.gestureMoved(to: CGPoint(x: 25, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 45, y: 0))  // 재이탈 45px (>= 20)
        viewModel.gestureEnded(row: 1, column: 1)
    }

    func testToggleOnAppliesYVowelAndProducesExpectedSyllable() {
        let viewModel = KeyboardViewModel(experimentalYVowelEnabledProvider: { true })
        viewModel.delegate = delegate

        feedRightRoundTripGesture(on: viewModel)

        XCTAssertEqual(delegate.composingUpdates.last?.current, "뱌", "토글 ON이면 Y계열 확정값(ㅑ)이 그대로 채택되어야 함")
    }

    /// 참고: 오른쪽 왕복 경로는 이 실험 기능과 무관하게 기존 인식기의 "3획 반전"
    /// 메커니즘(테스트 파일 GestureAnalyzerTests의 testTripleReversalForYoVowel 등 참고)
    /// 으로도 이미 ㅑ에 해당하는 결과를 낼 수 있다 — 즉 이 경로에서는 OFF/ON 결과가
    /// 우연히 같아질 수 있으므로, "다르다"가 아니라 "OFF는 기본 설정과 동일하게
    /// 동작한다"만 검증한다. 게이팅 자체는 카운터 기반 테스트(아래)로 별도 검증한다.
    func testToggleOffMatchesDefaultBehavior() {
        let viewModelOff = KeyboardViewModel(experimentalYVowelEnabledProvider: { false })
        let delegateOff = SpyKeyboardDelegate()
        viewModelOff.delegate = delegateOff
        feedRightRoundTripGesture(on: viewModelOff)

        // 기본 생성자(진짜 설정을 읽음, 테스트 환경에서는 기본 OFF)와 결과가 완전히 같아야
        // "이 기능이 존재하기 전과 100% 동일하게 동작한다"는 것을 보여줄 수 있다.
        let viewModelDefault = KeyboardViewModel()
        let delegateDefault = SpyKeyboardDelegate()
        viewModelDefault.delegate = delegateDefault
        feedRightRoundTripGesture(on: viewModelDefault)

        XCTAssertEqual(delegateOff.composingUpdates.last?.current, delegateDefault.composingUpdates.last?.current)
    }

    /// 제스처 시작 시점에 캐시된 토글 값만 참조하고, 도중에 provider가 바뀌어도
    /// 이미 시작된 제스처에는 영향이 없어야 한다(다음 제스처부터 반영). 위 참고와
    /// 같은 이유로 최종 문자 대신, 실험 적용 여부에만 반응하는 카운터로 검증한다.
    func testToggleIsCachedAtGestureStartAndIgnoresMidGestureChanges() {
        final class ToggleBox { var value = false }
        let box = ToggleBox()
        let viewModel = KeyboardViewModel(experimentalYVowelEnabledProvider: { box.value })
        viewModel.delegate = delegate
        let suite = UserDefaults(suiteName: AppGroupConstants.appGroupID)
        let before = ExperimentalYVowelSettings.appliedCount()

        // 첫 제스처: 시작 시점엔 false로 캐시됨.
        viewModel.gestureStarted(row: 1, column: 1, at: CGPoint(x: 0, y: 0))
        box.value = true // 제스처 도중 값이 바뀜 — 이미 캐시된 이 제스처엔 영향 없어야 함
        viewModel.gestureMoved(to: CGPoint(x: 20, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 40, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 20, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 5, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 25, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 45, y: 0))
        viewModel.gestureEnded(row: 1, column: 1)

        XCTAssertEqual(ExperimentalYVowelSettings.appliedCount(), before,
                       "제스처 시작 시점에 캐시된 값(false)이 유지되어 카운터가 늘면 안 됨")

        // 두 번째 제스처: 이번엔 시작 시점에 실제로 true이므로 새로 캐시되어 반영되어야 한다.
        feedRightRoundTripGesture(on: viewModel)
        XCTAssertEqual(ExperimentalYVowelSettings.appliedCount(), before + 1,
                       "다음 제스처는 새로 캐시된 값(true)을 반영해야 함")

        suite?.set(before, forKey: ExperimentalYVowelSettings.appliedCountKey)
    }

    // KVM-2: 카운터는 handleKoreanModeGesture(실제 입력 확정 지점)에서만, 제스처당 정확히 1회 기록된다.

    func testAppliedCounterIncrementsExactlyOncePerGestureRegardlessOfPreviewCallCount() {
        let suite = UserDefaults(suiteName: AppGroupConstants.appGroupID)
        let before = ExperimentalYVowelSettings.appliedCount()

        let viewModel = KeyboardViewModel(experimentalYVowelEnabledProvider: { true })
        viewModel.delegate = delegate

        // gestureMoved(미리보기 경로)는 여러 번 호출되지만, 카운터는 gestureEnded 시점에만 늘어야 한다.
        feedRightRoundTripGesture(on: viewModel)

        XCTAssertEqual(ExperimentalYVowelSettings.appliedCount(), before + 1, "제스처당 정확히 1회만 증가해야 함")

        // 정리: 테스트가 전역 앱그룹 카운터를 오염시키지 않도록 원래 값으로 되돌린다.
        suite?.set(before, forKey: ExperimentalYVowelSettings.appliedCountKey)
    }

    func testCounterDoesNotIncrementWhenToggleIsOff() {
        let suite = UserDefaults(suiteName: AppGroupConstants.appGroupID)
        let beforeApplied = ExperimentalYVowelSettings.appliedCount()
        let beforeConflict = ExperimentalYVowelSettings.conflictOverrideCount()

        let viewModel = KeyboardViewModel(experimentalYVowelEnabledProvider: { false })
        viewModel.delegate = delegate
        feedRightRoundTripGesture(on: viewModel)

        XCTAssertEqual(ExperimentalYVowelSettings.appliedCount(), beforeApplied, "토글 OFF면 appliedCount가 늘면 안 됨")
        XCTAssertEqual(ExperimentalYVowelSettings.conflictOverrideCount(), beforeConflict)

        suite?.set(beforeApplied, forKey: ExperimentalYVowelSettings.appliedCountKey)
        suite?.set(beforeConflict, forKey: ExperimentalYVowelSettings.conflictOverrideCountKey)
    }
}

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
}

private final class SpyKeyboardDelegate: KeyboardViewModelDelegate {
    struct ComposingUpdate: Equatable {
        let previous: String
        let current: String
    }

    var insertedTexts: [String] = []
    var deleteCount = 0
    var composingUpdates: [ComposingUpdate] = []
    var switchKeyboardCount = 0
    var hapticCount = 0
    var cursorOffsets: [Int] = []
    var characterBeforeCursorStub: Character?

    func insertText(_ text: String) {
        insertedTexts.append(text)
    }

    func deleteBackward() {
        deleteCount += 1
    }

    func updateComposingText(from previous: String, to current: String) {
        composingUpdates.append(.init(previous: previous, current: current))
    }

    func switchToNextKeyboard() {
        switchKeyboardCount += 1
    }

    func triggerHapticFeedback() {
        hapticCount += 1
    }

    func moveCursor(byCharacterOffset offset: Int) {
        cursorOffsets.append(offset)
    }

    func characterBeforeCursor() -> Character? {
        characterBeforeCursorStub
    }
}
