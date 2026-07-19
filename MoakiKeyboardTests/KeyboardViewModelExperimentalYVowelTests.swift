import XCTest

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
