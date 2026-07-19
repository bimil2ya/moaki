import XCTest

final class GestureAnalyzerTests: XCTestCase {

    // MARK: - Reversal Threshold Tests

    func testReversalDetectedAtLowerThreshold() {
        // With reversalThreshold=10, opposite direction change should be detected at 10px
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        // Start at origin, move up 25px (above threshold=20)
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 75))  // 25px up (iOS y-axis: lower y = up)

        XCTAssertEqual(analyzer.getDirections(), [.up])

        // Now reverse down by only 12px from direction change point (above reversal=10, below threshold=20)
        analyzer.addPoint(CGPoint(x: 100, y: 87))  // 12px down from y=75

        XCTAssertEqual(analyzer.getDirections(), [.up, .down], "Opposite reversal should be detected at reversal threshold (10px)")
    }

    func testNonReversalRequiresFullThreshold() {
        // Non-opposite direction changes should still require the full threshold
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        // Start at origin, move up 25px
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 75))  // 25px up

        XCTAssertEqual(analyzer.getDirections(), [.up])

        // Try to move right by only 12px (non-opposite direction, below threshold=20)
        analyzer.addPoint(CGPoint(x: 112, y: 75))  // 12px right from direction change point

        XCTAssertEqual(analyzer.getDirections(), [.up], "Non-opposite direction change should require full threshold")
    }

    func testTripleReversalForYoVowel() {
        // Simulate ㅛ gesture: up → down → up with small amplitude
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        // First direction: up 25px
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 75))  // 25px up

        XCTAssertEqual(analyzer.getDirections(), [.up])

        // Second direction (reversal): down 12px
        analyzer.addPoint(CGPoint(x: 100, y: 87))  // 12px down from y=75

        XCTAssertEqual(analyzer.getDirections(), [.up, .down])

        // Third direction (reversal): up 12px
        analyzer.addPoint(CGPoint(x: 100, y: 75))  // 12px up from y=87

        let finalDirs = analyzer.finalizeGesture()
        XCTAssertEqual(finalDirs, [.up, .down, .up], "Triple reversal should produce ㅛ pattern (↑↓↑)")
    }

    func testTripleReversalForYuVowel() {
        // Simulate ㅠ gesture: down → up → down with small amplitude
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        // First direction: down 25px
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 125))  // 25px down

        XCTAssertEqual(analyzer.getDirections(), [.down])

        // Second direction (reversal): up 12px
        analyzer.addPoint(CGPoint(x: 100, y: 113))  // 12px up from y=125

        XCTAssertEqual(analyzer.getDirections(), [.down, .up])

        // Third direction (reversal): down 12px
        analyzer.addPoint(CGPoint(x: 100, y: 125))  // 12px down from y=113

        let finalDirs = analyzer.finalizeGesture()
        XCTAssertEqual(finalDirs, [.down, .up, .down], "Triple reversal should produce ㅠ pattern (↓↑↓)")
    }

    func testFirstDirectionAlwaysRequiresFullThreshold() {
        // First direction should always need the full threshold, never reversal threshold
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        // Move only 12px (above reversal=10 but below threshold=20)
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 88))  // 12px up

        XCTAssertEqual(analyzer.getDirections(), [], "First direction should require full threshold")
    }

    // MARK: - Finalize Gesture Normalization Tests

    func testFinalizeKeepsMeaningfulMiddleDiagonalForThreeStrokeTurn() {
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 126))   // ↓
        analyzer.addPoint(CGPoint(x: 122, y: 148))   // ↘
        analyzer.addPoint(CGPoint(x: 96, y: 148))    // ←

        XCTAssertEqual(analyzer.getDirections(), [.down, .downRight, .left])
        XCTAssertEqual(analyzer.finalizeGesture(), [.down, .downRight, .left])
    }

    func testFinalizeCollapsesTinyDiagonalJitterWhenPathReturnsToSameDirection() {
        let analyzer = GestureAnalyzer(threshold: 8, reversalThreshold: 6, directionChangeThreshold: 8)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 70))    // ↑
        analyzer.addPoint(CGPoint(x: 109, y: 61))    // small ↗ jitter
        analyzer.addPoint(CGPoint(x: 109, y: 45))    // back to ↑

        XCTAssertEqual(analyzer.getDirections(), [.up, .upRight, .up])
        XCTAssertEqual(analyzer.finalizeGesture(), [.up])
    }

    // MARK: - GAT-20: Y계열 상태머신 도입 이후에도 첫 좌표가 기존 인식 경로에서
    // 누락되지 않음을 공개 API로만 검증 (private touchPoints를 직접 조회하지 않음)

    func testFirstPointIsRecordedAsStartPointAfterYVowelStateMachineAdded() {
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
        let origin = CGPoint(x: 100, y: 100)

        analyzer.addPoint(origin)
        XCTAssertEqual(analyzer.getStartPoint(), origin, "첫 점이 시작점으로 정확히 기록되어야 함")

        analyzer.addPoint(CGPoint(x: 100, y: 75))
        XCTAssertEqual(analyzer.getStartPoint(), origin, "이후 좌표가 추가돼도 시작점은 첫 점 그대로여야 함")
    }

    /// 단모음 대표 경로(ㅗ: 위 25px)가 이 기능 추가 전의 기대값과 동일한지 확인.
    func testSimpleVowelPathUnaffectedByYVowelStateMachine() {
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 75)) // 25px 위 => ㅗ

        let directions = analyzer.finalizeGesture()
        XCTAssertEqual(directions, [.up])

        let resolver = VowelResolver()
        let resolution = resolver.resolve(directions: directions)
        XCTAssertEqual(resolution.vowel, .ㅗ)
    }

    /// 겹모음 대표 경로(ㅘ: 위 → 오른쪽)가 이 기능 추가 전의 기대값과 동일한지 확인.
    func testDiphthongPathUnaffectedByYVowelStateMachine() {
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 70))  // 30px 위
        analyzer.addPoint(CGPoint(x: 140, y: 70))  // 40px 오른쪽 => ㅘ

        let directions = analyzer.finalizeGesture()
        XCTAssertEqual(directions, [.up, .right])

        let resolver = VowelResolver()
        let resolution = resolver.resolve(directions: directions)
        XCTAssertEqual(resolution.vowel, .ㅘ)
    }

    func testFinalizeKeepsDownRightLeftSequenceForWePattern() {
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 128))   // ↓
        analyzer.addPoint(CGPoint(x: 124, y: 152))   // ↘
        analyzer.addPoint(CGPoint(x: 98, y: 152))    // ←

        XCTAssertEqual(analyzer.finalizeGesture(), [.down, .downRight, .left])
    }

    // MARK: - Realistic Multi-Sample Drag Tests (ㅢ regression)

    /// 실제 터치는 addPoint가 몇 번만 호출되는 게 아니라, 드래그 경로를 따라
    /// 촘촘한 간격으로 수십 번 호출된다. 예전 코드는 한 방향이 threshold보다
    /// 길게 이어지면 기준점이 "처음 threshold를 넘은 지점"에 멈춰있어서,
    /// 그 이후 남은 거리가 다음 방향 전환(특히 되돌아오는 ㅢ의 두 번째 획)이
    /// 갚아야 할 "빚"으로 남아 되돌리는 획이 실제보다 훨씬 길어야만 인식됐다.
    private func simulateDrag(_ analyzer: GestureAnalyzer, start: CGPoint, legs: [(angleDegrees: Double, distance: CGFloat, steps: Int)]) {
        var current = start
        analyzer.addPoint(current)
        for leg in legs {
            let rad = leg.angleDegrees * .pi / 180
            let dx = cos(rad)
            let dy = -sin(rad)
            let stepDist = leg.distance / CGFloat(leg.steps)
            for _ in 0..<leg.steps {
                current = CGPoint(x: current.x + dx * stepDist, y: current.y + dy * stepDist)
                analyzer.addPoint(current)
            }
        }
    }

    func testLongFirstLegDoesNotBlockShortReversalForEui() {
        // 45도 아래-오른쪽으로 30px, 다시 원래 방향(위-왼쪽)으로 15px만 돌아와도
        // ㅢ(↘↖)로 인식되어야 한다 — 되돌리는 획이 첫 획만큼 길 필요는 없다.
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
        simulateDrag(analyzer, start: CGPoint(x: 100, y: 100), legs: [
            (angleDegrees: 305, distance: 30, steps: 15),
            (angleDegrees: 125, distance: 15, steps: 8)
        ])

        let finalDirections = analyzer.finalizeGesture()
        XCTAssertEqual(finalDirections, [.downRight, .upLeft])
        XCTAssertEqual(VowelResolver().resolve(directions: finalDirections).vowel, .ㅢ)
    }

    func testVeryLongFirstLegStillAllowsMinimalReversalForEui() {
        // 첫 획이 훨씬 길어도(100px) 되돌리는 획은 reversalThreshold를 살짝
        // 넘는 정도(11px)면 충분해야 한다 — 첫 획 길이에 비례해서 "빚"이
        // 쌓이면 안 된다.
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
        simulateDrag(analyzer, start: CGPoint(x: 100, y: 100), legs: [
            (angleDegrees: 305, distance: 100, steps: 50),
            (angleDegrees: 125, distance: 11, steps: 6)
        ])

        let finalDirections = analyzer.finalizeGesture()
        XCTAssertEqual(VowelResolver().resolve(directions: finalDirections).vowel, .ㅢ)
    }

    func testReversalAcceptsWideAngularRangeForEui() {
        // ↘로 시작한 다음에 오는 다른 방향은 ㅢ 말고는 의미가 없으므로, 되돌리는
        // 획이 ↖(정확한 반대 방향, 135도)이 아니어도 인식돼야 한다. 원래 방향
        // (305도) 기준 약 ±40도(즉 265~345도) 안쪽만 "아직 같은 방향으로
        // 가는 중"으로 보고 제외하고, 그 밖의 거의 모든 각도는 되돌리는
        // 획으로 받아들인다.
        for angle in stride(from: 35.0, through: 230.0, by: 15.0) {
            let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
            simulateDrag(analyzer, start: CGPoint(x: 200, y: 200), legs: [
                (angleDegrees: 305, distance: 30, steps: 15),
                (angleDegrees: angle, distance: 22, steps: 11)
            ])
            let vowel = VowelResolver().resolve(directions: analyzer.finalizeGesture()).vowel
            XCTAssertEqual(vowel, .ㅢ, "return angle \(angle)도 에서 ㅢ가 인식되지 않음")
        }
    }

    func testReversalNearOriginalDirectionStaysEuNotEui() {
        // 반대로, 원래 방향(↘, 305도)에서 크게 벗어나지 않은 각도(즉 계속
        // 같은 방향으로 가는 것에 가까운 경우)는 ㅢ로 오인되면 안 되고 ㅡ로
        // 남아야 한다.
        for angle in [260.0, 300.0, 350.0] {
            let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
            simulateDrag(analyzer, start: CGPoint(x: 100, y: 100), legs: [
                (angleDegrees: 305, distance: 30, steps: 15),
                (angleDegrees: angle, distance: 22, steps: 11)
            ])
            let vowel = VowelResolver().resolve(directions: analyzer.finalizeGesture()).vowel
            XCTAssertNotEqual(vowel, .ㅢ, "return angle \(angle)도 에서 ㅢ로 잘못 인식됨")
        }
    }

    func testSingleSustainedDragStaysEuNotEui() {
        // 한 방향으로만 쭉 그은 경우엔(방향 전환이 전혀 없으면) ㅡ로 남아야 하고,
        // 인접 방향 허용 폭이 넓어졌다고 해서 우연히 ㅢ로 잘못 인식되면 안 된다.
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
        simulateDrag(analyzer, start: CGPoint(x: 100, y: 100), legs: [
            (angleDegrees: 305, distance: 40, steps: 20)
        ])

        let finalDirections = analyzer.finalizeGesture()
        XCTAssertEqual(finalDirections, [.downRight])
        XCTAssertEqual(VowelResolver().resolve(directions: finalDirections).vowel, .ㅡ)
    }

    // MARK: - Same Wide-Angle Relaxation for the Other Single-Continuation Nodes
    //
    // ㅢ 말고도, "지금 상태에서 다음에 올 수 있는 의미 있는 획이 단 하나뿐인"
    // 지점은 전부 같은 방식으로 넓혀져 있다: ㅐㅑㅒ, ㅔㅕㅖ (→←/←→ 반복 계열),
    // 그리고 ㅚ→ㅛ, ㅟ→ㅠ, ㅘ→ㅙ, ㅝ→ㅞ로 이어지는 마지막 획. 반대로 ↑/↓가
    // "첫 획"으로 나오는 순간(ㅚ/ㅛ 계열이냐 ㅘ/ㅙ 계열이냐, ㅟ/ㅠ 계열이냐
    // ㅝ/ㅞ 계열이냐)은 진짜 갈림길이라 방향을 반드시 지켜야 한다.

    func testWideAngleAcceptedForAeYaYaeFamily() {
        for angle in stride(from: 15.0, through: 345.0, by: 15.0) {
            guard abs(angle) > 90, abs(angle - 360) > 90 else { continue } // → 근처(계속 가는 중)는 제외
            let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
            simulateDrag(analyzer, start: CGPoint(x: 300, y: 300), legs: [
                (angleDegrees: 0, distance: 30, steps: 15), // →
                (angleDegrees: angle, distance: 22, steps: 11)
            ])
            let vowel = VowelResolver().resolve(directions: analyzer.finalizeGesture()).vowel
            XCTAssertEqual(vowel, .ㅐ, "→ 다음 \(angle)도 되돌림에서 ㅐ가 인식되지 않음")
        }
    }

    func testWideAngleAcceptedForYoAfterOe() {
        // ㅚ(↑↓)까지는 이미 확정된 상태 — 세 번째 획은 ㅛ 말고는 뜻이 없다.
        for angle in stride(from: 15.0, through: 345.0, by: 30.0) {
            guard abs(angle - 270) > 90 else { continue } // ↓ 근처(계속 가는 중)는 제외
            let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
            simulateDrag(analyzer, start: CGPoint(x: 300, y: 300), legs: [
                (angleDegrees: 90, distance: 30, steps: 15),  // ↑
                (angleDegrees: 270, distance: 25, steps: 12), // ↓ (ㅚ 확정)
                (angleDegrees: angle, distance: 22, steps: 11)
            ])
            let vowel = VowelResolver().resolve(directions: analyzer.finalizeGesture()).vowel
            XCTAssertEqual(vowel, .ㅛ, "↑↓ 다음 \(angle)도에서 ㅛ가 인식되지 않음")
        }
    }

    func testFirstStrokeUpStillRequiresExactAngleToDisambiguateOeVsWa() {
        // ↑가 "첫 획"일 때는 진짜 갈림길이다 — ↓쪽이면 ㅚ/ㅛ 계열, →쪽이면
        // ㅘ/ㅙ 계열이라 정확한 방향이 필요하다.
        let toOe = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
        simulateDrag(toOe, start: CGPoint(x: 100, y: 100), legs: [
            (angleDegrees: 90, distance: 30, steps: 15),
            (angleDegrees: 270, distance: 25, steps: 12)
        ])
        XCTAssertEqual(VowelResolver().resolve(directions: toOe.finalizeGesture()).vowel, .ㅚ)

        let toWa = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
        simulateDrag(toWa, start: CGPoint(x: 100, y: 100), legs: [
            (angleDegrees: 90, distance: 30, steps: 15),
            (angleDegrees: 0, distance: 25, steps: 12)
        ])
        XCTAssertEqual(VowelResolver().resolve(directions: toWa.finalizeGesture()).vowel, .ㅘ)
    }

    func testFirstStrokeDownStillRequiresExactAngleToDisambiguateWiVsWeo() {
        // ↓가 "첫 획"일 때도 마찬가지로 갈림길이다 — ↑쪽이면 ㅟ/ㅠ 계열,
        // ←쪽이면 ㅝ/ㅞ 계열.
        let toWi = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
        simulateDrag(toWi, start: CGPoint(x: 100, y: 100), legs: [
            (angleDegrees: 270, distance: 30, steps: 15),
            (angleDegrees: 90, distance: 25, steps: 12)
        ])
        XCTAssertEqual(VowelResolver().resolve(directions: toWi.finalizeGesture()).vowel, .ㅟ)

        let toWeo = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
        simulateDrag(toWeo, start: CGPoint(x: 100, y: 100), legs: [
            (angleDegrees: 270, distance: 30, steps: 15),
            (angleDegrees: 180, distance: 25, steps: 12)
        ])
        XCTAssertEqual(VowelResolver().resolve(directions: toWeo.finalizeGesture()).vowel, .ㅝ)
    }

    // MARK: - Gentle Curve at Stroke End Should Not Register a Second Stroke

    /// 회귀 테스트: 자음 위에서 위로 곧게 긋다가 손목이 자연스럽게 돌아가면서
    /// 끝부분이 완만하게 오른쪽(인접 방향, ↗)으로 휘어지는 경우, "위" 스트로크
    /// 하나로만 남아야 한다. 예전에는 이 잔여 커브가 오른쪽 스트로크로 잘못
    /// 확정되어 ㅗ(오)가 아니라 ㅘ(와)로 오인식됐다.
    func testGentleCurveAtEndOfUpStrokeDoesNotBecomeSecondStroke() {
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
        var current = CGPoint(x: 100, y: 300)
        analyzer.addPoint(current)
        let totalSteps = 60
        for i in 1...totalSteps {
            let t = Double(i) / Double(totalSteps)
            let angle = 90.0 - 20.0 * t // 90도(↑)에서 70도까지 완만하게 휘어짐
            let rad = angle * .pi / 180
            let stepDist: CGFloat = 1.5
            current = CGPoint(x: current.x + CGFloat(cos(rad)) * stepDist, y: current.y - CGFloat(sin(rad)) * stepDist)
            analyzer.addPoint(current)
        }
        let finalDirections = analyzer.finalizeGesture()
        XCTAssertEqual(finalDirections, [.up], "완만한 커브가 두 번째 스트로크로 오인식됨")
        XCTAssertEqual(VowelResolver().resolve(directions: finalDirections).vowel, .ㅗ)
    }

    /// 반대로, 진짜로 확실하게 방향을 꺾어 긋는 ㅘ(↑→) 제스처는 여전히 인식돼야 한다 —
    /// 인접 방향 전환에 더 큰 거리를 요구하게 됐다고 해서 의도된 2획 제스처까지
    /// 막으면 안 된다.
    func testDeliberateTwoStrokeWaGestureStillWorksAfterCurveFix() {
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
        simulateDrag(analyzer, start: CGPoint(x: 100, y: 300), legs: [
            (angleDegrees: 90, distance: 40, steps: 20),
            (angleDegrees: 0, distance: 30, steps: 15)
        ])
        let vowel = VowelResolver().resolve(directions: analyzer.finalizeGesture()).vowel
        XCTAssertEqual(vowel, .ㅘ)
    }

    /// 실제 손동작은 완만한 아치형보다, 대부분 곧게 올라가다가 손을 떼기 직전
    /// 끝부분에서만 확 꺾이는 "훅(hook)" 모양에 가깝다. 자주 쓰는 자음일수록
    /// 빠르고 습관적인 손동작이 되어 이 훅이 더 짧고 급격해지는 경향이 있는데,
    /// 이런 경우에도 ㅗ가 ㅘ로 오인식되면 안 된다.
    private func hookArc(startAngle: Double, endAngle: Double, totalDistance: CGFloat, straightFraction: Double, steps: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        var current = CGPoint(x: 200, y: 300)
        points.append(current)
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let angle: Double
            if t < straightFraction {
                angle = startAngle
            } else {
                let curveT = (t - straightFraction) / (1 - straightFraction)
                angle = startAngle + (endAngle - startAngle) * curveT
            }
            let rad = angle * .pi / 180
            let stepDist = totalDistance / CGFloat(steps)
            current = CGPoint(x: current.x + CGFloat(cos(rad)) * stepDist, y: current.y - CGFloat(sin(rad)) * stepDist)
            points.append(current)
        }
        return points
    }

    func testShortSharpHookAtEndOfUpStrokeStaysOh() {
        // 짧고(30~45px) 손목이 꽤 급격하게(끝에서 30~50도까지) 꺾이는 현실적인
        // 훅 모양 다수를 스윕해서, 전부 ㅗ로 남는지 확인한다.
        for distance: CGFloat in [30, 35, 40, 45] {
            for straightFraction in [0.5, 0.6, 0.7, 0.8] {
                for endAngle in [50.0, 40.0, 30.0] {
                    let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
                    for p in hookArc(startAngle: 90, endAngle: endAngle, totalDistance: distance, straightFraction: straightFraction, steps: 80) {
                        analyzer.addPoint(p)
                    }
                    let vowel = VowelResolver().resolve(directions: analyzer.finalizeGesture()).vowel
                    XCTAssertEqual(
                        vowel, .ㅗ,
                        "distance=\(distance) straight=\(straightFraction) endAngle=\(endAngle)에서 ㅗ가 아닌 \(String(describing: vowel))로 인식됨"
                    )
                }
            }
        }
    }

    // MARK: - isOpposite Tests

    func testIsOpposite() {
        XCTAssertTrue(GestureDirection.up.isOpposite(to: .down))
        XCTAssertTrue(GestureDirection.down.isOpposite(to: .up))
        XCTAssertTrue(GestureDirection.left.isOpposite(to: .right))
        XCTAssertTrue(GestureDirection.right.isOpposite(to: .left))
        XCTAssertTrue(GestureDirection.upLeft.isOpposite(to: .downRight))
        XCTAssertTrue(GestureDirection.downRight.isOpposite(to: .upLeft))
        XCTAssertTrue(GestureDirection.upRight.isOpposite(to: .downLeft))
        XCTAssertTrue(GestureDirection.downLeft.isOpposite(to: .upRight))
    }

    func testIsNotOpposite() {
        XCTAssertFalse(GestureDirection.up.isOpposite(to: .right))
        XCTAssertFalse(GestureDirection.up.isOpposite(to: .upRight))
        XCTAssertFalse(GestureDirection.downRight.isOpposite(to: .upRight))
        XCTAssertFalse(GestureDirection.left.isOpposite(to: .downLeft))
    }

    // MARK: - Y계열(ㅑㅕㅛㅠ) 원점 복귀 인식기 테스트 (실험적 기능, 기본 OFF)
    //
    // GestureAnalyzer는 토글과 무관하게 항상 이 상태머신을 계산한다(3절 원칙).
    // 아래 테스트는 GestureAnalyzer 레벨에서 이 계산 자체가 올바른지만 검증하며,
    // KeyboardViewModel의 토글 게이팅은 별도 테스트(KeyboardViewModelLongPressTests)에서 다룬다.

    private func makeYVowelTestAnalyzer() -> GestureAnalyzer {
        GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
    }

    private func feedYVowelRoundTrip(
        _ analyzer: GestureAnalyzer,
        origin: CGPoint,
        outVector: CGVector,
        backVector: CGVector,
        steps: Int = 10
    ) {
        analyzer.addPoint(origin)
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            analyzer.addPoint(CGPoint(x: origin.x + outVector.dx * t, y: origin.y + outVector.dy * t))
        }
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            analyzer.addPoint(CGPoint(x: origin.x + outVector.dx * (1 - t), y: origin.y + outVector.dy * (1 - t)))
        }
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            analyzer.addPoint(CGPoint(x: origin.x + backVector.dx * t, y: origin.y + backVector.dy * t))
        }
    }

    // GAT-1~4: 방향별 왕복이 정확한 모음으로 확정되는지(구체적 값까지 확인)

    func testYVowelRightRoundTripConfirmsYa() {
        let analyzer = makeYVowelTestAnalyzer()
        feedYVowelRoundTrip(analyzer, origin: CGPoint(x: 200, y: 200),
                            outVector: CGVector(dx: 40, dy: 0), backVector: CGVector(dx: 40, dy: 0))
        XCTAssertEqual(analyzer.confirmedYVowel, .ㅑ)
    }

    func testYVowelLeftRoundTripConfirmsYeo() {
        let analyzer = makeYVowelTestAnalyzer()
        feedYVowelRoundTrip(analyzer, origin: CGPoint(x: 200, y: 200),
                            outVector: CGVector(dx: -40, dy: 0), backVector: CGVector(dx: -40, dy: 0))
        XCTAssertEqual(analyzer.confirmedYVowel, .ㅕ)
    }

    func testYVowelUpRoundTripConfirmsYo() {
        let analyzer = makeYVowelTestAnalyzer()
        feedYVowelRoundTrip(analyzer, origin: CGPoint(x: 200, y: 200),
                            outVector: CGVector(dx: 0, dy: -40), backVector: CGVector(dx: 0, dy: -40))
        XCTAssertEqual(analyzer.confirmedYVowel, .ㅛ)
    }

    func testYVowelDownRoundTripConfirmsYu() {
        let analyzer = makeYVowelTestAnalyzer()
        feedYVowelRoundTrip(analyzer, origin: CGPoint(x: 200, y: 200),
                            outVector: CGVector(dx: 0, dy: 40), backVector: CGVector(dx: 0, dy: 40))
        XCTAssertEqual(analyzer.confirmedYVowel, .ㅠ)
    }

    // GAT-5: 짧은 복귀(허용치 안)/헐렁한 복귀(허용치 밖)/각도 이탈

    func testYVowelTightReturnWithinRadiusStillConfirms() {
        let analyzer = makeYVowelTestAnalyzer()
        let origin = CGPoint(x: 100, y: 100)
        analyzer.addPoint(origin)
        analyzer.addPoint(CGPoint(x: 140, y: 100)) // out right 40px
        analyzer.addPoint(CGPoint(x: 105, y: 100)) // 원점에서 5px (반경 8 이내)
        analyzer.addPoint(CGPoint(x: 145, y: 100)) // 같은 방향으로 재이탈
        XCTAssertEqual(analyzer.confirmedYVowel, .ㅑ)
    }

    func testYVowelLooseReturnOutsideRadiusDoesNotConfirm() {
        let analyzer = makeYVowelTestAnalyzer()
        let origin = CGPoint(x: 100, y: 100)
        analyzer.addPoint(origin)
        analyzer.addPoint(CGPoint(x: 140, y: 100))
        analyzer.addPoint(CGPoint(x: 125, y: 100)) // 원점에서 25px, 반경(8) 밖
        analyzer.addPoint(CGPoint(x: 165, y: 100))
        XCTAssertNil(analyzer.confirmedYVowel)
    }

    func testYVowelAngleDriftOnRedepartureDoesNotConfirm() {
        let analyzer = makeYVowelTestAnalyzer()
        let origin = CGPoint(x: 100, y: 100)
        analyzer.addPoint(origin)
        analyzer.addPoint(CGPoint(x: 140, y: 100)) // out right (0도)
        analyzer.addPoint(CGPoint(x: 105, y: 100)) // 복귀
        analyzer.addPoint(CGPoint(x: 145, y: 140)) // 재이탈이 아래쪽으로 크게 휨(약 45도) — 허용치(35도) 밖
        XCTAssertNil(analyzer.confirmedYVowel)
    }

    // GAT-6: 단순 직선(ㅏㅓㅗㅜ)은 outbound엔 들어가되 confirmed엔 도달 안 함

    func testYVowelSimpleStraightDragNeverConfirms() {
        let analyzer = makeYVowelTestAnalyzer()
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 60)) // 위로 40px, 복귀 없음
        XCTAssertNil(analyzer.confirmedYVowel)
    }

    // GAT-7: 대각선 시작(ㅢ류)은 즉시 영구 배제

    func testYVowelDiagonalStartIsPermanentlyExcluded() {
        let analyzer = makeYVowelTestAnalyzer()
        let origin = CGPoint(x: 100, y: 100)
        analyzer.addPoint(origin)
        analyzer.addPoint(CGPoint(x: 130, y: 70))  // 45도 대각선으로 이탈
        analyzer.addPoint(origin)                  // 원점 복귀
        analyzer.addPoint(CGPoint(x: 130, y: 70))  // 같은 대각선으로 재이탈
        XCTAssertNil(analyzer.confirmedYVowel)
    }

    // GAT-8: 대각선 시작 후 1.5배 거리 시점엔 수평/수직처럼 보이는 경로도 영구배제 유지

    func testYVowelDiagonalStartStaysExcludedEvenIfLaterLooksCardinal() {
        let analyzer = makeYVowelTestAnalyzer()
        let origin = CGPoint(x: 100, y: 100)
        analyzer.addPoint(origin)
        // 최초 유효 이탈(거리>=threshold=20)이 대각선 방향(약 45도)으로 기록됨
        analyzer.addPoint(CGPoint(x: 115, y: 85))
        // 이후 거리가 1.5배(30) 이상이 되는 시점엔 벡터가 거의 수평(오른쪽)처럼 보이더라도
        // 이미 영구 배제됐으므로 outbound에 진입하지 않아야 함
        analyzer.addPoint(CGPoint(x: 145, y: 87))
        XCTAssertNil(analyzer.confirmedYVowel)
    }

    // GAT-9: 짧은 흔들림(거리 미달) 후 방향 전환은 idle 유지

    func testYVowelSmallJitterBelowThresholdStaysIdle() {
        let analyzer = makeYVowelTestAnalyzer()
        let origin = CGPoint(x: 100, y: 100)
        analyzer.addPoint(origin)
        analyzer.addPoint(CGPoint(x: 105, y: 100)) // 5px, threshold(20) 미달
        analyzer.addPoint(CGPoint(x: 100, y: 105)) // 방향이 바뀌어도 여전히 미달
        // 아직 firstMeaningfulDirection도 기록되지 않았어야 하므로, 이후 정상 왕복을 마저 진행하면
        // 그 시점부터 새로 시작된 것처럼 정상 확정되어야 한다(=idle 유지의 간접 확인).
        analyzer.addPoint(CGPoint(x: 140, y: 105))
        analyzer.addPoint(CGPoint(x: 105, y: 105))
        analyzer.addPoint(CGPoint(x: 145, y: 105))
        // 첫 흔들림이 원점을 오염시키지 않았다면, 원래 origin(100,100) 기준으로도
        // 우측 왕복 조건을 만족해 확정될 수 있다.
        XCTAssertNotNil(analyzer.confirmedYVowel)
    }

    // GAT-10: 초반 방향 이탈 후 1.5배 거리 전 다른 축으로 휘면 outbound 진입 안 함

    func testYVowelCurveTowardDifferentAxisBeforeOutboundEntryFailsToEnter() {
        let analyzer = makeYVowelTestAnalyzer()
        let origin = CGPoint(x: 100, y: 100)
        analyzer.addPoint(origin)
        analyzer.addPoint(CGPoint(x: 100, y: 78))  // 위로 22px (>= threshold 20, 방향=up 기록)
        analyzer.addPoint(CGPoint(x: 140, y: 78))  // 이제 오른쪽으로 크게 휘어 ㅘ 경로가 됨
        // 1.5배 거리(30) 도달 시점 방향이 up과 다르므로(오른쪽에 가까움) outbound 진입 실패해야 함.
        // 이후 원점 복귀 비슷한 동작을 흉내내도 절대 확정되지 않아야 한다.
        analyzer.addPoint(CGPoint(x: 105, y: 78))
        analyzer.addPoint(CGPoint(x: 100, y: 40))
        XCTAssertNil(analyzer.confirmedYVowel)
    }

    // GAT-11: 원형 각도 차이 wraparound (350도 -> 10도, 원형 거리 20도)

    func testYVowelWraparoundAngleDifferenceStillConfirms() {
        let analyzer = makeYVowelTestAnalyzer()
        let origin = CGPoint(x: 200, y: 200)
        func vec(degrees: CGFloat, magnitude: CGFloat) -> CGVector {
            let radians = degrees * .pi / 180
            return CGVector(dx: magnitude * cos(radians), dy: -magnitude * sin(radians))
        }
        feedYVowelRoundTrip(analyzer, origin: origin,
                            outVector: vec(degrees: 350, magnitude: 40),
                            backVector: vec(degrees: 10, magnitude: 40))
        XCTAssertEqual(analyzer.confirmedYVowel, .ㅑ, "350도->10도는 원형 거리 20도로 허용치 이내여야 함")
    }

    // GAT-12: 각도 경계(원형 거리 정확히 35도, 둘 다 right 섹터) — 통과 / 초과 — 거부

    func testYVowelAngleDifferenceExactlyAtToleranceStillConfirms() {
        let analyzer = makeYVowelTestAnalyzer()
        let origin = CGPoint(x: 200, y: 200)
        func vec(degrees: CGFloat, magnitude: CGFloat) -> CGVector {
            let radians = degrees * .pi / 180
            return CGVector(dx: magnitude * cos(radians), dy: -magnitude * sin(radians))
        }
        // 330.5도 -> 5.5도: 원형 거리 정확히 35도, 정수 섹터 경계(330/30)에서 안전 여유를 둠
        feedYVowelRoundTrip(analyzer, origin: origin,
                            outVector: vec(degrees: 330.5, magnitude: 40),
                            backVector: vec(degrees: 5.5, magnitude: 40))
        XCTAssertEqual(analyzer.confirmedYVowel, .ㅑ, "정확히 35도 차이는 허용(≤35)되어야 함")
    }

    func testYVowelAngleDifferenceBeyondToleranceDoesNotConfirm() {
        let analyzer = makeYVowelTestAnalyzer()
        let origin = CGPoint(x: 200, y: 200)
        func vec(degrees: CGFloat, magnitude: CGFloat) -> CGVector {
            let radians = degrees * .pi / 180
            return CGVector(dx: magnitude * cos(radians), dy: -magnitude * sin(radians))
        }
        // 335도 -> 25도: 둘 다 right 섹터지만 원형 거리 50도로 허용치 초과
        feedYVowelRoundTrip(analyzer, origin: origin,
                            outVector: vec(degrees: 335, magnitude: 40),
                            backVector: vec(degrees: 25, magnitude: 40))
        XCTAssertNil(analyzer.confirmedYVowel, "같은 카디널이어도 각도차 35도 초과면 미확정이어야 함")
    }

    // GAT-13: 카디널 enum과 실제 각도 이중 조건 — 각도차가 작아도 다른 섹터면 거부

    func testYVowelSameAngleCloseButDifferentCardinalDoesNotConfirm() {
        let analyzer = makeYVowelTestAnalyzer()
        let origin = CGPoint(x: 200, y: 200)
        func vec(degrees: CGFloat, magnitude: CGFloat) -> CGVector {
            let radians = degrees * .pi / 180
            return CGVector(dx: magnitude * cos(radians), dy: -magnitude * sin(radians))
        }
        // 29도(right 섹터 끝자락) -> 31도(upRight 섹터로 갓 넘어감): 각도차 2도로 작지만
        // GestureDirection 분류상 서로 다른 카디널이므로 확정되면 안 된다.
        feedYVowelRoundTrip(analyzer, origin: origin,
                            outVector: vec(degrees: 28.9, magnitude: 40),
                            backVector: vec(degrees: 30.1, magnitude: 40))
        XCTAssertNil(analyzer.confirmedYVowel, "각도차가 작아도 카디널 섹터가 다르면 미확정이어야 함")
    }

    // GAT-14: yVowelOutboundAngle이 firstMeaningfulAngle이 아니라 outbound 진입 시점 실측값임을 검증

    func testYVowelOutboundAngleUsesEntryTimeMeasurementNotFirstMeaningfulAngle() {
        let analyzer = makeYVowelTestAnalyzer()
        let origin = CGPoint(x: 100, y: 100)
        analyzer.addPoint(origin)
        // 최초 유효 방향은 정확히 0도(오른쪽)로 기록됨(거리 20)
        analyzer.addPoint(CGPoint(x: 120, y: 100))
        // 그러나 outbound 진입(거리 30 이상) 시점에는 약간 위로 휜 각도(약 9.5도)로 실측됨 —
        // 여전히 firstMeaningfulAngle(0도)과 35도 이내라 outbound 진입 자체는 성립.
        analyzer.addPoint(CGPoint(x: 130, y: 95))
        // 복귀
        analyzer.addPoint(CGPoint(x: 105, y: 100))
        // 재이탈을 outbound 진입 시점의 실측 각도(9.5도 부근)와 비슷하게 주면 확정되어야 하고,
        // 이는 yVowelOutboundAngle이 진입 시점 실측값을 기준으로 삼는다는 뜻이다.
        analyzer.addPoint(CGPoint(x: 145, y: 92))
        XCTAssertEqual(analyzer.confirmedYVowel, .ㅑ)
    }

    // GAT-15: 촘촘한 샘플 vs 성긴 샘플(원점을 가로지르는 경로) 동등성

    func testYVowelDenseAndSparseSamplingProduceSameResult() {
        let origin = CGPoint(x: 100, y: 100)

        let dense = makeYVowelTestAnalyzer()
        feedYVowelRoundTrip(dense, origin: origin,
                            outVector: CGVector(dx: 40, dy: 0), backVector: CGVector(dx: 50, dy: 0))

        let sparse = makeYVowelTestAnalyzer()
        sparse.addPoint(origin)
        sparse.addPoint(CGPoint(x: 140, y: 100)) // out right 40px
        sparse.addPoint(CGPoint(x: 50, y: 100))  // 한 번에 원점을 관통하는 점프(선분이 원점을 정확히 지남)
        sparse.addPoint(CGPoint(x: 150, y: 100)) // 재이탈

        XCTAssertEqual(dense.confirmedYVowel, .ㅑ)
        XCTAssertEqual(sparse.confirmedYVowel, .ㅑ)
        XCTAssertEqual(dense.confirmedYVowel, sparse.confirmedYVowel)
    }

    // GAT-16: 선분 근접-실패(반경 초과) / 근접-성공(반경 이내) 경계

    func testYVowelSegmentDistanceBeyondReturnRadiusDoesNotConfirm() {
        let analyzer = makeYVowelTestAnalyzer()
        let origin = CGPoint(x: 100, y: 100)
        analyzer.addPoint(origin)
        analyzer.addPoint(CGPoint(x: 140, y: 90))  // out
        analyzer.addPoint(CGPoint(x: 50, y: 90))   // 선분이 원점에서 정확히 10px(반경 8 초과)
        analyzer.addPoint(CGPoint(x: 150, y: 90))
        XCTAssertNil(analyzer.confirmedYVowel)
    }

    func testYVowelSegmentDistanceWithinReturnRadiusConfirms() {
        let analyzer = makeYVowelTestAnalyzer()
        let origin = CGPoint(x: 100, y: 100)
        analyzer.addPoint(origin)
        analyzer.addPoint(CGPoint(x: 140, y: 100))
        analyzer.addPoint(CGPoint(x: 140, y: 95))
        analyzer.addPoint(CGPoint(x: 50, y: 95))   // 선분이 원점에서 정확히 5px(반경 8 이내)
        analyzer.addPoint(CGPoint(x: 150, y: 95))
        XCTAssertEqual(analyzer.confirmedYVowel, .ㅑ)
    }

    // GAT-17: 중복 좌표·0 길이 선분 — 크래시나 NaN 없이 점 거리 기준으로 정상 폴백

    func testYVowelDuplicateCoordinatesDoNotCrashOrProduceNaN() {
        let analyzer = makeYVowelTestAnalyzer()
        let origin = CGPoint(x: 100, y: 100)
        analyzer.addPoint(origin)
        analyzer.addPoint(CGPoint(x: 140, y: 100))
        analyzer.addPoint(CGPoint(x: 140, y: 100)) // 중복(0 길이 선분)
        analyzer.addPoint(CGPoint(x: 105, y: 100))
        analyzer.addPoint(CGPoint(x: 105, y: 100)) // 중복
        analyzer.addPoint(CGPoint(x: 145, y: 100))
        XCTAssertEqual(analyzer.confirmedYVowel, .ㅑ)
    }

    // GAT-18: GestureAnalyzer.reset()이 Y계열 상태를 전부 초기화하는지(취소·연속 제스처 대비)

    func testYVowelResetClearsStateSoNextGestureStartsClean() {
        let analyzer = makeYVowelTestAnalyzer()
        feedYVowelRoundTrip(analyzer, origin: CGPoint(x: 100, y: 100),
                            outVector: CGVector(dx: 40, dy: 0), backVector: CGVector(dx: 40, dy: 0))
        XCTAssertEqual(analyzer.confirmedYVowel, .ㅑ)

        analyzer.reset()
        XCTAssertNil(analyzer.confirmedYVowel, "reset() 이후 확정값이 남아있으면 안 됨")

        // reset() 이후 다른 방향(위쪽)으로 완전히 새 제스처를 시작해도 정상 동작해야 한다.
        feedYVowelRoundTrip(analyzer, origin: CGPoint(x: 300, y: 300),
                            outVector: CGVector(dx: 0, dy: -40), backVector: CGVector(dx: 0, dy: -40))
        XCTAssertEqual(analyzer.confirmedYVowel, .ㅛ, "이전 제스처의 확정 상태가 새지 않아야 함")
    }

    // GAT-19: .confirmed 도달 후 추가 좌표가 들어와도 confirmedYVowel 불변(종결성 불변조건)

    func testYVowelConfirmedValueIsImmutableAfterConfirmation() {
        let analyzer = makeYVowelTestAnalyzer()
        feedYVowelRoundTrip(analyzer, origin: CGPoint(x: 100, y: 100),
                            outVector: CGVector(dx: 40, dy: 0), backVector: CGVector(dx: 40, dy: 0))
        XCTAssertEqual(analyzer.confirmedYVowel, .ㅑ)

        // 확정 후 흔들림이 이어져도 값이 변하면 안 된다.
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 300, y: 300))
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        XCTAssertEqual(analyzer.confirmedYVowel, .ㅑ, "확정 후에는 reset() 전까지 값이 바뀌면 안 됨")
    }

    // threshold를 다른 값으로 주입해도 비율이 스케일되는지(전역 참조가 아님을 검증)

    func testYVowelRatiosScaleWithInjectedThresholdNotGlobal() {
        // threshold=40이면 outbound 진입 거리는 60, 복귀 반경은 16, 재이탈 거리는 40이어야 한다.
        let analyzer = GestureAnalyzer(threshold: 40, reversalThreshold: 20, directionChangeThreshold: 30)
        let origin = CGPoint(x: 200, y: 200)
        analyzer.addPoint(origin)
        analyzer.addPoint(CGPoint(x: 280, y: 200)) // out right 80px (>= 60 진입 거리)
        analyzer.addPoint(CGPoint(x: 210, y: 200)) // 원점에서 10px (< 16 복귀 반경)
        analyzer.addPoint(CGPoint(x: 290, y: 200)) // 재이탈 90px (>= 40 재이탈 거리)
        XCTAssertEqual(analyzer.confirmedYVowel, .ㅑ, "threshold=40 기준으로 스케일된 비율에서도 정상 확정되어야 함")

        // threshold=20(기본)이었다면 복귀 반경(8)을 만족 못 했을 거리(10px)로,
        // threshold=40에서는 복귀 반경(16) 이내이므로 확정된다 — 즉 전역이 아니라
        // 인스턴스 threshold를 기준으로 계산됨을 보여준다.
        let smallThresholdAnalyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
        smallThresholdAnalyzer.addPoint(origin)
        smallThresholdAnalyzer.addPoint(CGPoint(x: 240, y: 200)) // out right 40px (>= 30)
        smallThresholdAnalyzer.addPoint(CGPoint(x: 210, y: 200)) // 원점에서 10px (>= 8, 반경 밖!)
        smallThresholdAnalyzer.addPoint(CGPoint(x: 250, y: 200))
        XCTAssertNil(smallThresholdAnalyzer.confirmedYVowel, "threshold=20 기준에서는 같은 10px 복귀가 반경 밖이라 미확정이어야 함")
    }

    // MARK: - upSectorExpansionDegrees (왼쪽 끝 자음 열 위쪽 드래그 오인식 보정)

    /// 70도(왼쪽 끝 열에서 위로 드래그할 때 화면 중앙 쪽으로 휘어진 각도)로 위-아래-위
    /// 왕복. 두 번째 다리는 정확히 270도(순수 아래)가 아니라 첫 70도의 정반대인 250도여야
    /// 한다 — 270도로 두면 두 번째 다리 전체가 원점에서 최소 약 10.7pt 떨어진 수직선이 되어
    /// 복귀 반경(threshold 20 기준 8pt) 안에 못 들어와 confirmedYVowel이 .outbound에 갇혀
    /// nil로 남는다(직접 좌표 계산으로 확인). 첫 다리도 정확히 30pt(outbound 진입 경계값)가
    /// 아니라 32pt로 여유를 둬 부동소수점 누적 오차로 경계 바로 아래 걸리는 것을 방지한다.
    func testExpansion20AllowsLeftEdgeColumnRoundTripToProduceYo() {
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
        analyzer.reset(upSectorExpansionDegrees: 20)
        simulateDrag(analyzer, start: CGPoint(x: 300, y: 300), legs: [
            (angleDegrees: 70, distance: 32, steps: 16),
            (angleDegrees: 250, distance: 25, steps: 12),
            (angleDegrees: 70, distance: 22, steps: 11),
        ])

        let directions = analyzer.finalizeGesture()
        XCTAssertEqual(directions, [.up, .down, .up], "확장 적용 시 70도 왕복이 일반 경로에서 [up,down,up]으로 분류되어야 함")
        XCTAssertEqual(VowelResolver().resolve(directions: directions).vowel, .ㅛ, "일반 경로(VowelResolver)도 ㅛ로 해석해야 함")
        // directions/resolver 검증만으로는 Y계열 상태기계(idle 2곳 + returned 1곳)에
        // 확장값이 실제로 전달됐는지 결정적으로 증명하지 못한다 — 그 셋은 analyzeLatestMovement와
        // 완전히 별개 경로이므로, confirmedYVowel까지 확인해야 6곳 전체가 뒷받침된다.
        XCTAssertEqual(analyzer.confirmedYVowel, .ㅛ, "실험적 원점 복귀 인식기(Y계열 상태기계)도 확장값을 받아 ㅛ를 확정해야 함")
    }

    /// 대조군: 확장 없이 같은 70도 왕복을 시도하면 첫 방향부터 upRight(ㅣ)로 잘못
    /// 분류되어야 한다 — 보정이 실제로 필요했음을 직접 증명한다. 대각선(upRight)으로
    /// 시작한 제스처는 Y계열 후보에서 영구 배제되므로 confirmedYVowel도 nil이어야 한다.
    func testWithoutExpansionSameRoundTripStaysUpRightAndFailsToProduceYo() {
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
        analyzer.reset() // upSectorExpansionDegrees: 0(기본값)
        simulateDrag(analyzer, start: CGPoint(x: 300, y: 300), legs: [
            (angleDegrees: 70, distance: 32, steps: 16),
            (angleDegrees: 250, distance: 25, steps: 12),
            (angleDegrees: 70, distance: 22, steps: 11),
        ])

        let directions = analyzer.finalizeGesture()
        XCTAssertEqual(directions.first, .upRight, "보정 없이는 70도 첫 방향이 upRight(ㅣ)로 잘못 분류되어야 함")
        XCTAssertNotEqual(VowelResolver().resolve(directions: directions).vowel, .ㅛ)
        XCTAssertNil(analyzer.confirmedYVowel, "대각선으로 시작한 제스처는 Y계열 후보에서 영구 배제되어 nil이어야 함")
    }

    /// "같은 방향 계속" 판정(analyzeLatestMovement 3곳 중 나머지 1곳)에 확장값이 전달되지
    /// 않으면, 긴 첫 획 도중 기준점이 갱신되지 않아 짧은 되돌림이 등록되지 않는 회귀가
    /// 생길 수 있다. 기존 testLongFirstLegDoesNotBlockShortReversalForEui 패턴을 좌측 열
    /// 보정 각도(70도)에 적용한다. 두 번째 다리(12pt)는 표준 방향 분류 임계값(20pt)보다
    /// 짧지만 reversal 임계값(10pt)보다 길다 — 첫 up에 대한 down은 반전이므로, 표준
    /// 경로가 아니라 reversal 전용 경로로만 등록되어야 하는 지점을 정확히 시험한다.
    func testExpansion20LongFirstLegStillRegistersShortReversal() {
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)
        analyzer.reset(upSectorExpansionDegrees: 20)
        simulateDrag(analyzer, start: CGPoint(x: 300, y: 300), legs: [
            (angleDegrees: 70, distance: 70, steps: 35),
            (angleDegrees: 250, distance: 12, steps: 6),
        ])

        XCTAssertEqual(analyzer.finalizeGesture(), [.up, .down], "긴 첫 획 뒤 짧은 되돌림도 정상 등록되어야 함")
    }
}
