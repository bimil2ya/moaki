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

/// 드래그로 만든 기본 모음(ㅏㅓㅗㅜ) 뒤에 천지인 "점(ㆍ)"을 누르면 Y계열(ㅑㅕㅛㅠ)로
/// 바뀌는 단축 변환 테스트. 시간 제한이 아니라 "다음 입력이 정확히 점인지"라는 입력
/// 순서로 동작하므로, 타이머 관련 검증은 순수 천지인 자동확정 회귀에 한정한다.
final class KeyboardViewModelDirectVowelExtensionTests: XCTestCase {

    private struct DragCase {
        let choseong: Choseong
        let row: Int
        let column: Int
        let dx: CGFloat
        let dy: CGFloat
        let before: String
        let after: String
    }

    /// 좌표·방향은 KeyboardMetrics.koreanLayout([111-115]), VowelPattern.swift([14-17])의
    /// 실제 값과 직접 대조해 고정했다: ㅎ(row2,col5)+오른쪽=ㅏ, ㄱ(row1,col4)+왼쪽=ㅓ,
    /// ㅁ(row2,col1)+위=ㅗ, ㅅ(row1,col5)+아래=ㅜ.
    private let basicMappingCases: [DragCase] = [
        DragCase(choseong: .ㅎ, row: 2, column: 5, dx: 40, dy: 0, before: "하", after: "햐"),
        DragCase(choseong: .ㄱ, row: 1, column: 4, dx: -40, dy: 0, before: "거", after: "겨"),
        DragCase(choseong: .ㅁ, row: 2, column: 1, dx: 0, dy: -40, before: "모", after: "묘"),
        DragCase(choseong: .ㅅ, row: 1, column: 5, dx: 0, dy: 40, before: "수", after: "슈"),
    ]

    /// viewModel.inputVowel(_:)을 직접 호출하지 않는다 — armDirectVowelExtensionIfEligible는
    /// handleKoreanModeGesture(제스처 공개 API 경로) 안에서만 호출되므로, 실제
    /// gestureStarted→gestureMoved→gestureEnded 흐름을 그대로 거쳐야 대기 상태가 걸린다.
    private func performCardinalDrag(on viewModel: KeyboardViewModel, row: Int, column: Int, dx: CGFloat, dy: CGFloat) {
        viewModel.gestureStarted(row: row, column: column, at: CGPoint(x: 0, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: dx, y: dy))
        viewModel.gestureEnded(row: row, column: column)
    }

    /// 드래그로 ㅎ+오른쪽="하"를 만든 새 viewModel/delegate 쌍을 반환한다. 무효화
    /// 시나리오 테스트들이 공통으로 재사용한다.
    private func makeViewModelDraggedToHa() -> (KeyboardViewModel, SpyKeyboardDelegate) {
        let viewModel = KeyboardViewModel(cheonjiinAutoCommitDelay: 0.05)
        let delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate
        performCardinalDrag(on: viewModel, row: 2, column: 5, dx: 40, dy: 0)
        return (viewModel, delegate)
    }

    // MARK: - 기본 매핑 (드래그 → 점)

    func testDragBasicVowelThenDotExtendsToYVariant() {
        for testCase in basicMappingCases {
            // 각 iteration마다 새 인스턴스 — 이전 케이스의 조합 상태·타이머가 남지 않게 한다.
            let viewModel = KeyboardViewModel(cheonjiinAutoCommitDelay: 0.05)
            let delegate = SpyKeyboardDelegate()
            viewModel.delegate = delegate

            performCardinalDrag(on: viewModel, row: testCase.row, column: testCase.column, dx: testCase.dx, dy: testCase.dy)
            XCTAssertEqual(delegate.composingUpdates.last?.current, testCase.before,
                           "드래그 직후 \(testCase.before) 상태여야 함")

            viewModel.inputCheonjiinStroke(.dot)

            XCTAssertEqual(delegate.composingUpdates.last?.current, testCase.after,
                           "점 입력 후 \(testCase.after)로 확장되어야 함")
        }
    }

    // MARK: - 순수 천지인 회귀 (기존 동작 불변)

    private struct PureCheonjiinCase {
        let strokes: [CheonjiinStroke]
        let expected: Jungseong
    }

    private let pureCheonjiinCases: [PureCheonjiinCase] = [
        PureCheonjiinCase(strokes: [.i, .dot, .dot], expected: .ㅑ),
        PureCheonjiinCase(strokes: [.dot, .dot, .i], expected: .ㅕ),
        PureCheonjiinCase(strokes: [.dot, .dot, .eu], expected: .ㅛ),
        PureCheonjiinCase(strokes: [.eu, .dot, .dot], expected: .ㅠ),
    ]

    func testPureCheonjiinYVowelsStillWorkUnaffected() {
        for testCase in pureCheonjiinCases {
            // 이 루프도 마찬가지로 iteration마다 새 인스턴스를 생성한다.
            let viewModel = KeyboardViewModel(cheonjiinAutoCommitDelay: 0.05)
            let delegate = SpyKeyboardDelegate()
            viewModel.delegate = delegate

            viewModel.inputConsonant(.ㅇ)
            testCase.strokes.forEach { viewModel.inputCheonjiinStroke($0) }

            let expectation = expectation(description: "auto-commit fires for \(testCase.expected)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)

            let expectedChar = HangulConstants.composeSyllable(choseong: .ㅇ, jungseong: testCase.expected)
            XCTAssertTrue(delegate.composingUpdates.contains { $0.current == String(expectedChar) },
                          "순수 천지인으로 \(testCase.expected)가 정상 확정되어야 함")
        }
    }

    /// 순수 천지인으로 만든 "거"는 드래그로 만든 게 아니므로, 이어지는 점 입력이
    /// "겨"로 잘못 확장되면 안 된다(교차오염 회귀).
    func testCrossContaminationPureCheonjiinSyllableIsNotAccidentallyExtended() {
        let viewModel = KeyboardViewModel(cheonjiinAutoCommitDelay: 0.05)
        let delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate

        viewModel.inputConsonant(.ㄱ)
        viewModel.inputCheonjiinStroke(.dot)
        viewModel.inputCheonjiinStroke(.i) // ㅓ 대기 중

        let expectation = expectation(description: "auto-commit fires for 거")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(delegate.composingUpdates.contains { $0.current == "거" })

        viewModel.inputCheonjiinStroke(.dot)
        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "겨" })
    }

    // MARK: - 일반 입력 무효화

    func testOtherConsonantInputInvalidatesExtension() {
        let (viewModel, delegate) = makeViewModelDraggedToHa()
        viewModel.inputConsonant(.ㄴ)
        viewModel.inputCheonjiinStroke(.dot)
        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "햐" })
    }

    func testBackspaceInvalidatesExtension() {
        let (viewModel, delegate) = makeViewModelDraggedToHa()
        viewModel.deleteBackward()
        viewModel.inputCheonjiinStroke(.dot)
        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "햐" })
    }

    func testSpaceInvalidatesExtension() {
        let (viewModel, delegate) = makeViewModelDraggedToHa()
        viewModel.inputSpace()
        XCTAssertEqual(delegate.insertedTexts, [" "])

        viewModel.inputCheonjiinStroke(.dot)
        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "햐" })
    }

    func testSymbolInvalidatesExtension() {
        let (viewModel, delegate) = makeViewModelDraggedToHa()
        viewModel.inputSymbol("!")
        XCTAssertEqual(delegate.insertedTexts, ["!"])

        viewModel.inputCheonjiinStroke(.dot)
        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "햐" })
    }

    func testNumberInvalidatesExtension() {
        let (viewModel, delegate) = makeViewModelDraggedToHa()
        viewModel.inputNumber("1")
        XCTAssertEqual(delegate.insertedTexts, ["1"])

        viewModel.inputCheonjiinStroke(.dot)
        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "햐" })
    }

    func testReturnInvalidatesExtension() {
        let (viewModel, delegate) = makeViewModelDraggedToHa()
        viewModel.inputReturn()
        XCTAssertEqual(delegate.insertedTexts, ["\n"])

        viewModel.inputCheonjiinStroke(.dot)
        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "햐" })
    }

    /// 점이 아닌 천지인 스트로크(ㅡ/ㅣ)가 끼어들면 무효화되고, 그 스트로크는 새
    /// 천지인 버퍼의 시작으로 처리되어 기존 "하"를 건드리지 않아야 한다.
    func testNonDotCheonjiinStrokeInvalidatesExtensionWithoutDisturbingExistingSyllable() {
        let (viewModel, delegate) = makeViewModelDraggedToHa()
        viewModel.inputCheonjiinStroke(.i)
        XCTAssertEqual(delegate.composingUpdates.last?.current, "하",
                       "새 천지인 버퍼 시작이 기존 글자를 건드리면 안 됨")

        viewModel.inputCheonjiinStroke(.dot)
        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "햐" })
    }

    /// 겹모음(예: 과)은 매핑 표에 없으므로 점을 눌러도 불변이어야 한다.
    func testDiphthongDragThenDotDoesNotChangeResult() {
        let viewModel = KeyboardViewModel(cheonjiinAutoCommitDelay: 0.05)
        let delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate

        viewModel.inputConsonant(.ㄱ)
        viewModel.gestureStarted(row: 1, column: 4, at: CGPoint(x: 0, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 0, y: -30)) // 위 30px
        viewModel.gestureMoved(to: CGPoint(x: 40, y: -30)) // 오른쪽 40px => ㅘ
        viewModel.gestureEnded(row: 1, column: 4)

        XCTAssertEqual(delegate.composingUpdates.last?.current, "과")

        viewModel.inputCheonjiinStroke(.dot)
        XCTAssertEqual(delegate.composingUpdates.last?.current, "과", "겹모음은 매핑 표에 없어 불변이어야 함")
    }

    /// 실험적 Y계열 인식기로 이미 확정된 ㅑ(뱌)는 매핑 표에 없으므로(ㅏ만 있고 ㅑ는 없음)
    /// 점을 눌러도 불변이어야 한다.
    func testExperimentalYVowelConfirmedSyllableIsNotAffectedByDot() {
        let delegate = SpyKeyboardDelegate()
        let viewModel = KeyboardViewModel(cheonjiinAutoCommitDelay: 0.05, experimentalYVowelEnabledProvider: { true })
        viewModel.delegate = delegate

        // ㅂ 키(row:1, column:1) 위에서 오른쪽으로 왕복 — confirmedYVowel == .ㅑ로 확정되는 경로.
        viewModel.gestureStarted(row: 1, column: 1, at: CGPoint(x: 0, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 20, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 40, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 20, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 5, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 25, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: 45, y: 0))
        viewModel.gestureEnded(row: 1, column: 1)

        XCTAssertEqual(delegate.composingUpdates.last?.current, "뱌")

        viewModel.inputCheonjiinStroke(.dot)
        XCTAssertEqual(delegate.composingUpdates.last?.current, "뱌", "ㅑ는 매핑 표에 없어 불변이어야 함")
    }

    // MARK: - 접근성 경로

    func testAccessibilityPathAlsoSupportsExtension() {
        let viewModel = KeyboardViewModel(cheonjiinAutoCommitDelay: 0.05)
        let delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate

        viewModel.showAccessibilityVowelPicker(for: .ㅎ)
        viewModel.selectAccessibilityVowel(.ㅏ)
        XCTAssertEqual(delegate.composingUpdates.last?.current, "하")

        viewModel.inputCheonjiinStroke(.dot)
        XCTAssertEqual(delegate.composingUpdates.last?.current, "햐")
    }

    // MARK: - resetGestureState 함정 재발 방지

    /// gestureEnded는 handleKoreanModeGesture 직후 곧바로 resetGestureState()를 호출한다.
    /// 이 테스트는 그 실제 순서를 그대로 거친 뒤에도 대기 상태가 살아있는지 확인한다 —
    /// resetGestureState()에 무효화 로직을 넣으면 이 테스트가 실패했을 것이다.
    func testPendingExtensionSurvivesRealGestureEndedCallOrder() {
        let (viewModel, delegate) = makeViewModelDraggedToHa()
        viewModel.inputCheonjiinStroke(.dot)
        XCTAssertEqual(delegate.composingUpdates.last?.current, "햐")
    }

    // MARK: - 타이머 관련

    func testSuccessfulExtensionDoesNotTriggerLaterAutoCommit() {
        let (viewModel, delegate) = makeViewModelDraggedToHa()
        viewModel.inputCheonjiinStroke(.dot)
        XCTAssertEqual(delegate.composingUpdates.last?.current, "햐")
        let countAfterExtension = delegate.composingUpdates.count

        let expectation = expectation(description: "wait past auto-commit delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(delegate.composingUpdates.count, countAfterExtension,
                       "확장 성공 후에는 천지인 타이머가 전혀 시작되지 않아야 함")
    }

    func testSecondDotAfterSuccessfulExtensionDoesNotAlterResult() {
        let (viewModel, delegate) = makeViewModelDraggedToHa()
        viewModel.inputCheonjiinStroke(.dot)
        XCTAssertEqual(delegate.composingUpdates.last?.current, "햐")

        viewModel.inputCheonjiinStroke(.dot) // 두 번째 점 — 이미 소비되어 새 천지인 버퍼 시작으로 처리됨
        XCTAssertEqual(delegate.composingUpdates.last?.current, "햐", "두 번째 점이 기존 결과를 바꾸면 안 됨")
    }

    // MARK: - 외부 상태 변화·소멸

    func testFlushPendingStateBeforeDisappearingInvalidatesExtension() {
        let (viewModel, delegate) = makeViewModelDraggedToHa()
        viewModel.flushPendingStateBeforeDisappearing()
        viewModel.inputCheonjiinStroke(.dot)
        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "햐" })
    }

    func testResetComposerInvalidatesExtensionWithoutTouchingAlreadyDisplayedText() {
        let (viewModel, delegate) = makeViewModelDraggedToHa()
        let countBeforeReset = delegate.composingUpdates.count

        viewModel.resetComposer() // 외부 텍스트 변경 감지 시나리오
        XCTAssertEqual(delegate.composingUpdates.count, countBeforeReset,
                       "resetComposer는 이미 화면에 표시된 텍스트를 지우지 않는다")

        viewModel.inputCheonjiinStroke(.dot)
        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "햐" })
    }

    // MARK: - 한자/문구 후보 (UX 회귀 — flushPendingCheonjiin의 무효화 로직 자체를
    // 증명하지는 못한다. showHanjaCandidates/showSnippetCandidates는 flushPendingCheonjiin
    // 직후 commitCurrent()를 호출해 조합기를 이미 커밋·리셋하므로, 이 테스트가 통과하는
    // 이유는 그 commitCurrent() 때문이지 여기 추가한 무효화 코드 때문이 아니다.)

    func testHanjaCandidatesUXRegressionDoesNotProduceExtendedComposingUpdate() {
        let viewModel = KeyboardViewModel(cheonjiinAutoCommitDelay: 0.05)
        let delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate

        performCardinalDrag(on: viewModel, row: 1, column: 4, dx: 40, dy: 0) // ㄱ+오른쪽 = 가
        XCTAssertEqual(delegate.composingUpdates.last?.current, "가")

        delegate.characterBeforeCursorStub = "가"
        viewModel.showHanjaCandidates()
        XCTAssertFalse(viewModel.hanjaCandidates.isEmpty, "한자 후보가 정상적으로 채워져야 함")

        viewModel.inputCheonjiinStroke(.dot)

        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "갸" })
        XCTAssertTrue(delegate.insertedTexts.isEmpty)
        XCTAssertEqual(delegate.deleteCount, 0)
    }

    func testSnippetCandidatesUXRegressionDoesNotProduceExtendedComposingUpdate() {
        let suite = UserDefaults(suiteName: AppGroupConstants.appGroupID)
        let keys = ["snippet.ㅋ", "snippet.ㅌ", "snippet.ㅊ", "snippet.ㅍ", "snippet.extra"]
        var existingValues: [String: Any] = [:]
        var absentKeys: [String] = []
        for key in keys {
            if let value = suite?.object(forKey: key) {
                existingValues[key] = value
            } else {
                absentKeys.append(key)
            }
        }
        defer {
            for (key, value) in existingValues { suite?.set(value, forKey: key) }
            for key in absentKeys { suite?.removeObject(forKey: key) }
        }
        suite?.set("테스트문구", forKey: "snippet.ㅋ")

        let viewModel = KeyboardViewModel(cheonjiinAutoCommitDelay: 0.05)
        let delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate

        performCardinalDrag(on: viewModel, row: 1, column: 4, dx: 40, dy: 0) // ㄱ+오른쪽 = 가
        XCTAssertEqual(delegate.composingUpdates.last?.current, "가")

        viewModel.showSnippetCandidates()
        XCTAssertFalse(viewModel.snippetCandidates.isEmpty, "문구 후보가 정상적으로 채워져야 함")

        viewModel.inputCheonjiinStroke(.dot)

        XCTAssertFalse(delegate.composingUpdates.contains { $0.current == "갸" })
        XCTAssertTrue(delegate.insertedTexts.isEmpty)
        XCTAssertEqual(delegate.deleteCount, 0)
    }
}

/// 왼쪽 끝 자음 열(ㅃㅂㅁㅋ, column 1)에서 위로 드래그할 때 손동작이 화면 중앙(오른쪽)으로
/// 휘어져 ㅗ가 ㅣ로 잘못 인식되는 문제의 열 기반 보정 테스트. 아래는 전부 반드시
/// gestureStarted → gestureMoved → gestureEnded 공개 API 흐름을 거친다 — GestureAnalyzer나
/// inputVowel을 직접 호출하면 gestureStarted가 column에 따라
/// gestureAnalyzer.reset(upSectorExpansionDegrees:)를 호출하는 실제 배선을 건너뛰어
/// 이 보정이 KeyboardViewModel에 제대로 연결됐는지 검증하지 못한다.
final class KeyboardViewModelLeftEdgeColumnGestureTests: XCTestCase {

    private func performSingleDrag(on viewModel: KeyboardViewModel, row: Int, column: Int, angleDegrees: Double, magnitude: CGFloat = 40) {
        let rad = angleDegrees * .pi / 180
        let dx = magnitude * CGFloat(cos(rad))
        let dy = -magnitude * CGFloat(sin(rad))
        viewModel.gestureStarted(row: row, column: column, at: CGPoint(x: 0, y: 0))
        viewModel.gestureMoved(to: CGPoint(x: dx, y: dy))
        viewModel.gestureEnded(row: row, column: column)
    }

    func testLeftEdgeColumnDriftedUpAngleProducesO() {
        let viewModel = KeyboardViewModel()
        let delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate

        performSingleDrag(on: viewModel, row: 2, column: 1, angleDegrees: 70) // ㅁ

        XCTAssertEqual(delegate.composingUpdates.last?.current, "모", "왼쪽 끝 열에서 70도로 드래그해도 ㅗ로 보정되어야 함")
    }

    func testNonLeftEdgeColumnSameDriftedAngleStillProducesI() {
        let viewModel = KeyboardViewModel()
        let delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate

        performSingleDrag(on: viewModel, row: 1, column: 4, angleDegrees: 70) // ㄱ, 왼쪽 끝 아님

        XCTAssertEqual(delegate.composingUpdates.last?.current, "기", "왼쪽 끝 열이 아니면 보정이 적용되지 않아야 함")
    }

    func testLeftEdgeColumnExactDownAngleStillProducesU() {
        let viewModel = KeyboardViewModel()
        let delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate

        performSingleDrag(on: viewModel, row: 2, column: 1, angleDegrees: 270) // ㅁ, 정확히 아래

        XCTAssertEqual(delegate.composingUpdates.last?.current, "무", "down 계열 분류는 전혀 영향받지 않아야 함")
    }

    /// 트레이드오프 문서화: 확장으로 좁아진 upRight 유효 범위(30..<60) 안에서는
    /// 명확한 대각선 의도가 여전히 ㅣ로 인식되어야 한다.
    func testLeftEdgeColumnClearDiagonalIntentStillProducesI() {
        let viewModel = KeyboardViewModel()
        let delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate

        performSingleDrag(on: viewModel, row: 2, column: 1, angleDegrees: 47) // ㅁ, 명확한 대각선 의도

        XCTAssertEqual(delegate.composingUpdates.last?.current, "미")
    }

    /// 실사용과 가장 가까운 시나리오: gestureAnalyzer는 키보드 세션 내내 재사용되는
    /// 단일 인스턴스이므로, 같은 KeyboardViewModel로 왼쪽 끝 열 제스처 이후 일반 열
    /// 제스처를 이어서 수행해도 확장값이 새면 안 된다. reset(upSectorExpansionDegrees:)가
    /// 매번 저장값을 확실히 덮어쓰지 못하면(예: 조건부 대입) 이 테스트가 실패한다.
    func testExpansionDoesNotLeakToSubsequentGestureOnDifferentColumn() {
        let viewModel = KeyboardViewModel()
        let delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate

        performSingleDrag(on: viewModel, row: 2, column: 1, angleDegrees: 70) // ㅁ → 모
        XCTAssertEqual(delegate.composingUpdates.last?.current, "모")

        performSingleDrag(on: viewModel, row: 1, column: 4, angleDegrees: 70) // 같은 인스턴스, ㄱ → 기
        XCTAssertEqual(delegate.composingUpdates.last?.current, "기", "이전 제스처의 확장값이 다음 제스처로 새면 안 됨")
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
