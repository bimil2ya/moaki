import XCTest

final class KeyboardMetricsTests: XCTestCase {
    // MARK: - koreanLayout 좌표 고정 (왼쪽 열 보정 작업 근거)

    func testKoreanLayoutConsonantCoordinates() {
        XCTAssertEqual(KeyboardMetrics.consonant(at: 2, column: 5), .ㅎ)
        XCTAssertEqual(KeyboardMetrics.consonant(at: 1, column: 4), .ㄱ)
        XCTAssertEqual(KeyboardMetrics.consonant(at: 2, column: 1), .ㅁ)
        XCTAssertEqual(KeyboardMetrics.consonant(at: 1, column: 5), .ㅅ)
    }

    func testConsonantReturnsNilAtSymbolKeyPosition() {
        XCTAssertNil(KeyboardMetrics.consonant(at: 1, column: 0))
    }

    // MARK: - longPressNumber 매핑

    func testLongPressNumberMappingForConsonantRows() {
        XCTAssertEqual(KeyboardMetrics.longPressNumber(at: 1, column: 1), "1") // ㅂ
        XCTAssertEqual(KeyboardMetrics.longPressNumber(at: 2, column: 5), "0") // ㅎ
    }

    func testLongPressNumberIsNilOutsideConsonantRows() {
        for column in 0..<KeyboardMetrics.gridColumns {
            XCTAssertNil(KeyboardMetrics.longPressNumber(at: 0, column: column), "row 0, column \(column)")
            XCTAssertNil(KeyboardMetrics.longPressNumber(at: 3, column: column), "row 3, column \(column)")
        }
    }

    // MARK: - keyContent 범위 방어

    func testKeyContentReturnsNilOutsideGridBounds() {
        XCTAssertNil(KeyboardMetrics.keyContent(at: -1, column: 0, isSymbolMode: false))
        XCTAssertNil(KeyboardMetrics.keyContent(at: KeyboardMetrics.koreanLayout.count, column: 0, isSymbolMode: false))
        XCTAssertNil(KeyboardMetrics.keyContent(at: 0, column: -1, isSymbolMode: false))
        XCTAssertNil(KeyboardMetrics.keyContent(at: 0, column: KeyboardMetrics.koreanLayout[0].count, isSymbolMode: false))
    }

    // MARK: - 레이아웃 형태 불변식

    func testKoreanLayoutHasFourRowsOfSevenColumns() {
        XCTAssertEqual(KeyboardMetrics.koreanLayout.count, 4)
        for row in 0..<4 {
            XCTAssertEqual(KeyboardMetrics.columnCount(for: row, isSymbolMode: false), 7, "row \(row)")
        }
    }

    func testSymbolLayoutLastRowHasSixColumns() {
        XCTAssertEqual(KeyboardMetrics.symbolLayout.count, 4)
        for row in 0..<3 {
            XCTAssertEqual(KeyboardMetrics.columnCount(for: row, isSymbolMode: true), 7, "row \(row)")
        }
        XCTAssertEqual(KeyboardMetrics.columnCount(for: 3, isSymbolMode: true), 6)
    }

    func testKeyContentIsNonNilExactlyWithinColumnCountForEachLayout() {
        for isSymbolMode in [false, true] {
            let layout = isSymbolMode ? KeyboardMetrics.symbolLayout : KeyboardMetrics.koreanLayout
            for row in 0..<layout.count {
                let count = KeyboardMetrics.columnCount(for: row, isSymbolMode: isSymbolMode)
                for column in 0..<count {
                    XCTAssertNotNil(
                        KeyboardMetrics.keyContent(at: row, column: column, isSymbolMode: isSymbolMode),
                        "isSymbolMode=\(isSymbolMode) row=\(row) column=\(column)"
                    )
                }
            }
        }
    }

    /// "범위 밖은 전부 nil"은 정수 좌표 전체를 검사할 수 없으므로 유한한 경계
    /// 케이스로 명시한다. 특히 심볼 모드 마지막 행의 column 6은 일반 행 기준으로는
    /// 유효해 보이지만(다른 행은 7열) 실제로는 범위 밖인 핵심 경계다.
    func testKeyContentIsNilAtBoundaryCases() {
        // row 경계
        XCTAssertNil(KeyboardMetrics.keyContent(at: -1, column: 0, isSymbolMode: false))
        XCTAssertNil(KeyboardMetrics.keyContent(at: KeyboardMetrics.koreanLayout.count, column: 0, isSymbolMode: false))

        // column 경계 (각 레이아웃, 각 행)
        for isSymbolMode in [false, true] {
            let layout = isSymbolMode ? KeyboardMetrics.symbolLayout : KeyboardMetrics.koreanLayout
            for row in 0..<layout.count {
                XCTAssertNil(
                    KeyboardMetrics.keyContent(at: row, column: -1, isSymbolMode: isSymbolMode),
                    "isSymbolMode=\(isSymbolMode) row=\(row) column=-1"
                )
                let count = KeyboardMetrics.columnCount(for: row, isSymbolMode: isSymbolMode)
                XCTAssertNil(
                    KeyboardMetrics.keyContent(at: row, column: count, isSymbolMode: isSymbolMode),
                    "isSymbolMode=\(isSymbolMode) row=\(row) column=\(count)"
                )
            }
        }

        // 심볼 모드 마지막 행의 column 6: 다른 행은 7열이라 유효해 보이지만 실제 범위 밖
        XCTAssertNil(KeyboardMetrics.keyContent(at: 3, column: 6, isSymbolMode: true))
    }

    // MARK: - 제스처 민감도 배율

    /// KeyboardMetrics.gestureThreshold(계산 프로퍼티)는 GestureSensitivitySettings.multiplier()를
    /// 인자 없이 호출하므로 App Group 값을 우회해서 테스트할 방법이 없다. 배율을 직접
    /// 받는 순수 함수(gestureThreshold(multiplier:) 등)로 비례 관계만 검증한다.
    func testThresholdsScaleLinearlyWithMultiplier() {
        let base = KeyboardMetrics.gestureThreshold(multiplier: 1.0)
        XCTAssertEqual(KeyboardMetrics.gestureThreshold(multiplier: 1.5), base * 1.5)

        let reversalBase = KeyboardMetrics.reversalThreshold(multiplier: 1.0)
        XCTAssertEqual(KeyboardMetrics.reversalThreshold(multiplier: 1.5), reversalBase * 1.5)

        let directionChangeBase = KeyboardMetrics.directionChangeThreshold(multiplier: 1.0)
        XCTAssertEqual(KeyboardMetrics.directionChangeThreshold(multiplier: 1.5), directionChangeBase * 1.5)
    }
}
