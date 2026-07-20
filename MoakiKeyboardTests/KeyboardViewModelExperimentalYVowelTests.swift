import XCTest

/// KVM: Y계열(ㅑㅕㅛㅠ) 원점 복귀 인식기(실험적 기능)의 KeyboardViewModel 연결 테스트.
/// GestureAnalyzer 자체의 상태머신 정확성은 GestureAnalyzerTests(GAT)에서 이미 검증했으므로,
/// 여기서는 오직 "토글 게이팅·캐시 시점·카운터 기록 시점"이라는 배선(wiring)만 다룬다.
@MainActor
final class KeyboardViewModelExperimentalYVowelTests: XCTestCase {
    private var delegate: SpyKeyboardDelegate!
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        delegate = SpyKeyboardDelegate()
        suiteName = "test-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        delegate = nil
        if !suiteName.isEmpty {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }
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
        let viewModel = KeyboardViewModel(
            experimentalYVowelEnabledProvider: { true },
            experimentalYVowelRecorder: { [defaults] in ExperimentalYVowelSettings.recordApplied(wasConflictOverride: $0, defaults: defaults) }
        )
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
        let viewModelOff = KeyboardViewModel(
            experimentalYVowelEnabledProvider: { false },
            experimentalYVowelRecorder: { [defaults] in ExperimentalYVowelSettings.recordApplied(wasConflictOverride: $0, defaults: defaults) }
        )
        let delegateOff = SpyKeyboardDelegate()
        viewModelOff.delegate = delegateOff
        feedRightRoundTripGesture(on: viewModelOff)

        // 진짜 기본 provider(ExperimentalYVowelSettings.isEnabled())가 내부적으로
        // 위임하는 것과 정확히 같은 isEnabled(defaults:) 구현을, 항상 비어있는(false)
        // 임시 suite로 고정해 실행한다 — "같은 판독 구현을 격리된 빈 suite에서 실행해
        // 기본값 false를 안정적으로 재현한다"는 의도적으로 좁힌 경계다(실제 App Group의
        // 환경 의존적인 현재 값을 그대로 읽으면 테스트가 기기·시뮬레이터 상태에 따라
        // 흔들릴 수 있어서다).
        let viewModelDefault = KeyboardViewModel(
            experimentalYVowelEnabledProvider: { [defaults] in ExperimentalYVowelSettings.isEnabled(defaults: defaults) },
            experimentalYVowelRecorder: { [defaults] in ExperimentalYVowelSettings.recordApplied(wasConflictOverride: $0, defaults: defaults) }
        )
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
        let viewModel = KeyboardViewModel(
            experimentalYVowelEnabledProvider: { box.value },
            experimentalYVowelRecorder: { [defaults] in ExperimentalYVowelSettings.recordApplied(wasConflictOverride: $0, defaults: defaults) }
        )
        viewModel.delegate = delegate
        let before = ExperimentalYVowelSettings.appliedCount(defaults: defaults)

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

        XCTAssertEqual(ExperimentalYVowelSettings.appliedCount(defaults: defaults), before,
                       "제스처 시작 시점에 캐시된 값(false)이 유지되어 카운터가 늘면 안 됨")

        // 두 번째 제스처: 이번엔 시작 시점에 실제로 true이므로 새로 캐시되어 반영되어야 한다.
        feedRightRoundTripGesture(on: viewModel)
        XCTAssertEqual(ExperimentalYVowelSettings.appliedCount(defaults: defaults), before + 1,
                       "다음 제스처는 새로 캐시된 값(true)을 반영해야 함")
    }

    // KVM-2: 카운터는 handleKoreanModeGesture(실제 입력 확정 지점)에서만, 제스처당 정확히 1회 기록된다.

    func testAppliedCounterIncrementsExactlyOncePerGestureRegardlessOfPreviewCallCount() {
        let before = ExperimentalYVowelSettings.appliedCount(defaults: defaults)

        let viewModel = KeyboardViewModel(
            experimentalYVowelEnabledProvider: { true },
            experimentalYVowelRecorder: { [defaults] in ExperimentalYVowelSettings.recordApplied(wasConflictOverride: $0, defaults: defaults) }
        )
        viewModel.delegate = delegate

        // gestureMoved(미리보기 경로)는 여러 번 호출되지만, 카운터는 gestureEnded 시점에만 늘어야 한다.
        feedRightRoundTripGesture(on: viewModel)

        XCTAssertEqual(ExperimentalYVowelSettings.appliedCount(defaults: defaults), before + 1, "제스처당 정확히 1회만 증가해야 함")
    }

    func testCounterDoesNotIncrementWhenToggleIsOff() {
        let beforeApplied = ExperimentalYVowelSettings.appliedCount(defaults: defaults)
        let beforeConflict = ExperimentalYVowelSettings.conflictOverrideCount(defaults: defaults)

        let viewModel = KeyboardViewModel(
            experimentalYVowelEnabledProvider: { false },
            experimentalYVowelRecorder: { [defaults] in ExperimentalYVowelSettings.recordApplied(wasConflictOverride: $0, defaults: defaults) }
        )
        viewModel.delegate = delegate
        feedRightRoundTripGesture(on: viewModel)

        XCTAssertEqual(ExperimentalYVowelSettings.appliedCount(defaults: defaults), beforeApplied, "토글 OFF면 appliedCount가 늘면 안 됨")
        XCTAssertEqual(ExperimentalYVowelSettings.conflictOverrideCount(defaults: defaults), beforeConflict)
    }
}
