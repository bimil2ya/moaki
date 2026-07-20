import XCTest

@MainActor
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
