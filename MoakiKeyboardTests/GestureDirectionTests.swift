import XCTest
import CoreGraphics

/// GDT-1: 공유 각도 헬퍼(`angleDegrees(dx:dy:)`) 도입 및 `from(vector:)` 리팩터링이
/// 기존 섹터 경계에서의 분류 결과를 절대 바꾸지 않았는지 확인하는 회귀 테스트.
/// 기존 전체 제스처 인식이 이 분류 함수 하나에 의존하므로, 신규 기능 테스트가 아니라
/// 기존 동작 보존을 위한 최우선 안전장치다.
final class GestureDirectionTests: XCTestCase {

    private func vector(forDegrees degrees: CGFloat, magnitude: CGFloat = 100) -> CGVector {
        // from(vector:)의 각도 계산은 atan2(-dy, dx)이므로, 원하는 각도를 만들려면
        // dy 부호를 반전해서 넣어야 한다.
        let radians = degrees * .pi / 180
        return CGVector(dx: magnitude * cos(radians), dy: -magnitude * sin(radians))
    }

    private func assertDirection(_ degrees: CGFloat, is expected: GestureDirection, line: UInt = #line) {
        let result = GestureDirection.from(vector: vector(forDegrees: degrees))
        XCTAssertEqual(result, expected, "각도 \(degrees)도가 \(expected)로 분류되어야 함", line: line)
    }

    // 실제 GestureDirection.swift의 섹터 경계: right(330-360, 0-30), upRight(30-80),
    // up(80-120), upLeft(120-150), left(150-210), downLeft(210-240), down(240-280),
    // downRight(280-330).

    func testBoundary0DegreesIsRight() {
        assertDirection(0, is: .right)
    }

    // 참고: 30·120·210·240·330 등 무리수 삼각비가 끼는 각도는 degrees→벡터→atan2
    // 왕복 과정에서 부동소수점 오차(예: 30도가 29.999999999999993으로 계산됨)가 생겨
    // 정확히 그 정수 각도에서 테스트하면 실제 분류 로직과 무관하게 실패할 수 있다.
    // 이는 리팩터링과 무관한, 각도 재구성 자체의 정밀도 한계이므로, 경계에서 0.1도
    // 안전 여유를 두고 테스트한다(±0.1도는 위 정밀도 오차보다 훨씬 크므로 실제
    // 섹터 경계 검증 목적은 그대로 유지된다).

    func testBoundary29And30DegreesAcrossRightToUpRight() {
        assertDirection(28.9, is: .right)
        assertDirection(30.1, is: .upRight)
    }

    func testBoundary79And80DegreesAcrossUpRightToUp() {
        assertDirection(78.9, is: .upRight)
        assertDirection(80.1, is: .up)
    }

    func testBoundary119And120DegreesAcrossUpToUpLeft() {
        assertDirection(118.9, is: .up)
        assertDirection(120.1, is: .upLeft)
    }

    func testBoundary149And150DegreesAcrossUpLeftToLeft() {
        assertDirection(148.9, is: .upLeft)
        assertDirection(150.1, is: .left)
    }

    func testBoundary209And210DegreesAcrossLeftToDownLeft() {
        assertDirection(208.9, is: .left)
        assertDirection(210.1, is: .downLeft)
    }

    func testBoundary239And240DegreesAcrossDownLeftToDown() {
        assertDirection(238.9, is: .downLeft)
        assertDirection(240.1, is: .down)
    }

    func testBoundary279And280DegreesAcrossDownToDownRight() {
        assertDirection(278.9, is: .down)
        assertDirection(280.1, is: .downRight)
    }

    func testBoundary329And330DegreesAcrossDownRightToRight() {
        assertDirection(328.9, is: .downRight)
        assertDirection(330.1, is: .right)
    }

    func testMagnitudeBelowThresholdReturnsNil() {
        let result = GestureDirection.from(vector: CGVector(dx: 5, dy: 5), threshold: 20)
        XCTAssertNil(result)
    }

    /// 각도 헬퍼가 from(vector:)와 동일한 좌표 변환(iOS y축 반전 포함)을 쓰는지 직접 확인.
    func testAngleDegreesHelperMatchesFromVectorClassificationBoundaries() {
        // up의 중심(90도)에서 angleDegrees가 90을 반환하고, from(vector:)도 .up을 반환해야 함.
        let v = vector(forDegrees: 90)
        XCTAssertEqual(GestureDirection.angleDegrees(dx: v.dx, dy: v.dy), 90, accuracy: 0.001)
        XCTAssertEqual(GestureDirection.from(vector: v), .up)
    }
}
