import XCTest

/// 왼쪽 끝 자음 열(ㅃㅂㅁㅋ, column 1)에서 위로 드래그할 때 손동작이 화면 중앙(오른쪽)으로
/// 휘어져 ㅗ가 ㅣ로 잘못 인식되는 문제의 열 기반 보정 테스트. 아래는 전부 반드시
/// gestureStarted → gestureMoved → gestureEnded 공개 API 흐름을 거친다 — GestureAnalyzer나
/// inputVowel을 직접 호출하면 gestureStarted가 column에 따라
/// gestureAnalyzer.reset(upSectorExpansionDegrees:)를 호출하는 실제 배선을 건너뛰어
/// 이 보정이 KeyboardViewModel에 제대로 연결됐는지 검증하지 못한다.
@MainActor
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
        let viewModel = KeyboardViewModel(
            experimentalYVowelEnabledProvider: { false },
            experimentalYVowelRecorder: { _ in }
        )
        let delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate

        performSingleDrag(on: viewModel, row: 2, column: 1, angleDegrees: 70) // ㅁ

        XCTAssertEqual(delegate.composingUpdates.last?.current, "모", "왼쪽 끝 열에서 70도로 드래그해도 ㅗ로 보정되어야 함")
    }

    func testNonLeftEdgeColumnSameDriftedAngleStillProducesI() {
        let viewModel = KeyboardViewModel(
            experimentalYVowelEnabledProvider: { false },
            experimentalYVowelRecorder: { _ in }
        )
        let delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate

        performSingleDrag(on: viewModel, row: 1, column: 4, angleDegrees: 70) // ㄱ, 왼쪽 끝 아님

        XCTAssertEqual(delegate.composingUpdates.last?.current, "기", "왼쪽 끝 열이 아니면 보정이 적용되지 않아야 함")
    }

    func testLeftEdgeColumnExactDownAngleStillProducesU() {
        let viewModel = KeyboardViewModel(
            experimentalYVowelEnabledProvider: { false },
            experimentalYVowelRecorder: { _ in }
        )
        let delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate

        performSingleDrag(on: viewModel, row: 2, column: 1, angleDegrees: 270) // ㅁ, 정확히 아래

        XCTAssertEqual(delegate.composingUpdates.last?.current, "무", "down 계열 분류는 전혀 영향받지 않아야 함")
    }

    /// 트레이드오프 문서화: 확장으로 좁아진 upRight 유효 범위(30..<60) 안에서는
    /// 명확한 대각선 의도가 여전히 ㅣ로 인식되어야 한다.
    func testLeftEdgeColumnClearDiagonalIntentStillProducesI() {
        let viewModel = KeyboardViewModel(
            experimentalYVowelEnabledProvider: { false },
            experimentalYVowelRecorder: { _ in }
        )
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
        let viewModel = KeyboardViewModel(
            experimentalYVowelEnabledProvider: { false },
            experimentalYVowelRecorder: { _ in }
        )
        let delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate

        performSingleDrag(on: viewModel, row: 2, column: 1, angleDegrees: 70) // ㅁ → 모
        XCTAssertEqual(delegate.composingUpdates.last?.current, "모")

        performSingleDrag(on: viewModel, row: 1, column: 4, angleDegrees: 70) // 같은 인스턴스, ㄱ → 기
        XCTAssertEqual(delegate.composingUpdates.last?.current, "기", "이전 제스처의 확장값이 다음 제스처로 새면 안 됨")
    }
}
