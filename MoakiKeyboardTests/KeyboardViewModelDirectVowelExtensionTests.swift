import XCTest

/// 드래그로 만든 기본 모음(ㅏㅓㅗㅜ) 뒤에 천지인 "점(ㆍ)"을 누르면 Y계열(ㅑㅕㅛㅠ)로
/// 바뀌는 단축 변환 테스트. 시간 제한이 아니라 "다음 입력이 정확히 점인지"라는 입력
/// 순서로 동작하므로, 타이머 관련 검증은 순수 천지인 자동확정 회귀에 한정한다.
@MainActor
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
        let viewModel = KeyboardViewModel(
            cheonjiinAutoCommitDelay: 0.05,
            experimentalYVowelEnabledProvider: { false },
            experimentalYVowelRecorder: { _ in }
        )
        let delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate
        performCardinalDrag(on: viewModel, row: 2, column: 5, dx: 40, dy: 0)
        return (viewModel, delegate)
    }

    // MARK: - 기본 매핑 (드래그 → 점)

    func testDragBasicVowelThenDotExtendsToYVariant() {
        for testCase in basicMappingCases {
            // 각 iteration마다 새 인스턴스 — 이전 케이스의 조합 상태·타이머가 남지 않게 한다.
            let viewModel = KeyboardViewModel(
                cheonjiinAutoCommitDelay: 0.05,
                experimentalYVowelEnabledProvider: { false },
                experimentalYVowelRecorder: { _ in }
            )
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
        let viewModel = KeyboardViewModel(
            cheonjiinAutoCommitDelay: 0.05,
            experimentalYVowelEnabledProvider: { false },
            experimentalYVowelRecorder: { _ in }
        )
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
        let viewModel = KeyboardViewModel(
            cheonjiinAutoCommitDelay: 0.05,
            experimentalYVowelEnabledProvider: { true },
            experimentalYVowelRecorder: { _ in }
        )
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
        let viewModel = KeyboardViewModel(
            cheonjiinAutoCommitDelay: 0.05,
            experimentalYVowelEnabledProvider: { false },
            experimentalYVowelRecorder: { _ in }
        )
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
        let viewModel = KeyboardViewModel(
            cheonjiinAutoCommitDelay: 0.05,
            experimentalYVowelEnabledProvider: { false },
            experimentalYVowelRecorder: { _ in },
            snippetsProvider: { ["테스트문구"] }
        )
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
