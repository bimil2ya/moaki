import Foundation
import CoreGraphics

class GestureAnalyzer {
    private struct DirectionSegment {
        var direction: GestureDirection
        var magnitude: CGFloat
    }

    private var touchPoints: [CGPoint] = []
    private var directions: [GestureDirection] = []
    private var directionMagnitudes: [CGFloat] = []
    private var lastDirectionChangePoint: CGPoint?

    // MARK: - Y계열(ㅑㅕㅛㅠ) 원점 복귀 인식기 (실험적 기능)
    //
    // 기존 방향-시퀀스 추적과 완전히 독립된 상태다. 이 인식기는 설정값·앱그룹 등
    // 외부 상태를 전혀 참조하지 않고, 좌표만으로 항상 계산되는 결정적 상태머신이다
    // (토글에 따라 "쓸지 말지"는 KeyboardViewModel이 결정한다).
    private enum YVowelPhase {
        case idle
        case outbound
        case returned
        case confirmed
    }

    private var yVowelPhase: YVowelPhase = .idle
    private var yVowelOriginPoint: CGPoint?
    private var yVowelPreviousPoint: CGPoint?
    /// idle→outbound 진입 자격 검사에만 쓰인다(진입 이후에는 다시 참조하지 않는다).
    private var firstMeaningfulDirection: GestureDirection?
    private var firstMeaningfulAngle: CGFloat?
    /// outbound 진입이 실제로 성립한 순간 실측한 값 — 이후 재이탈 비교는 이 값 기준으로만 한다.
    private var yVowelOutboundDirection: GestureDirection?
    private var yVowelOutboundAngle: CGFloat?
    private var isExcludedFromYVowelCandidacy = false
    private(set) var confirmedYVowel: Jungseong?

    private var yVowelOutboundEntryDistance: CGFloat { threshold * 1.5 }
    private var yVowelReturnRadius: CGFloat { threshold * 0.4 }
    private var yVowelRedepartureDistance: CGFloat { threshold }
    private let yVowelAngleToleranceDegrees: CGFloat = 35

    private let threshold: CGFloat
    private let reversalThreshold: CGFloat
    private let directionChangeThreshold: CGFloat

    /// 인접한(예: ↑ 다음 ↗) 방향으로의 전환에 요구되는 거리. 손목을 돌리며 긋는
    /// 자연스러운 손동작은 완전히 다른 방향으로 튀는 일 없이 인접한 방향으로만
    /// 서서히 휘어지는 경우가 많아서, 일반 `directionChangeThreshold`보다 더 확실한
    /// 거리를 요구해야 "위로 곧게 긋다가 끝에서 살짝 휘어지는" 동작이 실수로 ㅘ
    /// 같은 2획 제스처로 오인되지 않는다.
    private let adjacentDirectionChangeThreshold: CGFloat

    init(threshold: CGFloat = KeyboardMetrics.gestureThreshold,
         reversalThreshold: CGFloat = KeyboardMetrics.reversalThreshold,
         directionChangeThreshold: CGFloat = KeyboardMetrics.directionChangeThreshold,
         adjacentDirectionChangeThreshold: CGFloat? = nil) {
        self.threshold = threshold
        self.reversalThreshold = reversalThreshold
        self.directionChangeThreshold = directionChangeThreshold
        self.adjacentDirectionChangeThreshold = adjacentDirectionChangeThreshold ?? directionChangeThreshold * 1.5
    }

    func reset() {
        touchPoints.removeAll()
        directions.removeAll()
        directionMagnitudes.removeAll()
        lastDirectionChangePoint = nil

        yVowelPhase = .idle
        yVowelOriginPoint = nil
        yVowelPreviousPoint = nil
        firstMeaningfulDirection = nil
        firstMeaningfulAngle = nil
        yVowelOutboundDirection = nil
        yVowelOutboundAngle = nil
        isExcludedFromYVowelCandidacy = false
        confirmedYVowel = nil
    }

    func addPoint(_ point: CGPoint) {
        // 기존 방향-시퀀스 인식 경로는 무조건, 이 실험 기능과 무관하게 그대로 실행한다.
        touchPoints.append(point)
        analyzeLatestMovement()

        // 새 Y계열 인식기 분석. 아래 "첫 호출" 조기 종료는 이 서브루틴 안에서만
        // 끝나는 것이며, addPoint 함수 자체를 빠져나가는 것이 아니다 — 위의 기존
        // 로직은 이미 실행이 끝난 뒤이므로 영향을 받지 않는다.
        updateYVowelState(with: point)
    }

    func getDirections() -> [GestureDirection] {
        return directions
    }

    func getStartPoint() -> CGPoint? {
        return touchPoints.first
    }

    private func analyzeLatestMovement() {
        guard touchPoints.count >= 2 else { return }

        let referencePoint = lastDirectionChangePoint ?? touchPoints.first!
        let currentPoint = touchPoints.last!

        let vector = CGVector(
            dx: currentPoint.x - referencePoint.x,
            dy: currentPoint.y - referencePoint.y
        )

        let magnitude = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)

        // Try detecting direction with standard threshold first
        var newDirection = GestureDirection.from(vector: vector, threshold: threshold)

        // If standard threshold fails, try lower reversal threshold for opposite directions.
        // Real fingers rarely retrace the exact reverse angle, so this also accepts a
        // candidate that's adjacent to the true opposite (see `isReversal(of:)`).
        if newDirection == nil, let lastDirection = directions.last, magnitude >= reversalThreshold {
            if let candidate = GestureDirection.from(vector: vector, threshold: reversalThreshold),
               candidate.isReversal(of: lastDirection, isFirstStroke: directions.count == 1) {
                newDirection = candidate
            }
        }

        guard let newDirection else {
            // No new/opposite direction confirmed yet this sample. If we're still
            // heading the same way as the last confirmed stroke, drag the reference
            // point along anyway (angle-only check, no magnitude gate) so a long
            // straight drag doesn't leave "unspent" distance behind once the
            // direction was confirmed. Without this, a leg longer than `threshold`
            // freezes the reference point at the exact spot where it first crossed
            // the threshold, and the leftover distance becomes debt that the next
            // stroke's reversal has to pay off before it can register at all —
            // this is what made short return-strokes (e.g. the ㅢ gesture's second
            // leg) fail unpredictably depending on exactly how far the first leg
            // overshot the threshold before turning.
            if let lastDirection = directions.last,
               magnitude > 0,
               GestureDirection.from(vector: vector, threshold: 0.01) == lastDirection {
                lastDirectionChangePoint = currentPoint
            }
            return
        }

        // Check if this is a new direction or continuation
        if let lastDirection = directions.last {
            // Only add if direction changed
            if newDirection != lastDirection {
                let isAdjacent = newDirection.isAdjacentTo(lastDirection)
                // ↑/↓가 첫 획일 때는 그 다음 방향이 ㅚ/ㅛ 계열이냐 ㅘ/ㅙ 계열이냐(또는
                // ㅟ/ㅠ냐 ㅝ/ㅞ냐)를 가르는 진짜 갈림길이라, 다른 경우보다 더 확실한
                // 거리를 요구해서 손목이 돌아가며 자연스럽게 휘어지는 정도로는 이 갈림길이
                // 함부로 넘어가지 않게 한다.
                let isAmbiguousFirstStroke = directions.count == 1 && (lastDirection == .up || lastDirection == .down)
                // Make sure we've moved enough from the last direction change.
                // 인접한 방향으로의 전환, 또는 위/아래가 첫 획일 때는 더 확실한 거리
                // (adjacentDirectionChangeThreshold)를 요구한다.
                let requiredMagnitude = (isAdjacent || isAmbiguousFirstStroke) ? adjacentDirectionChangeThreshold : directionChangeThreshold
                if magnitude >= requiredMagnitude || (newDirection.isReversal(of: lastDirection, isFirstStroke: directions.count == 1) && magnitude >= reversalThreshold) {
                    directions.append(newDirection)
                    directionMagnitudes.append(magnitude)
                    lastDirectionChangePoint = currentPoint
                } else if isAdjacent {
                    // 아직 새 스트로크로 확정할 만큼 멀리 가진 않았지만, 인접한(거의 같은)
                    // 방향으로 손가락이 자연스럽게 휘어지는 중이다. 여기서도 기준점을 끌고
                    // 가지 않으면, 위 guard 분기와 같은 이유로 "빚"이 쌓인다 — 예를 들어
                    // 위로 긋다가 끝에서 살짝 오른쪽으로 휘어지는 손동작이, 인접 구간에서
                    // 멈춘 기준점 때문에 나중에 진짜 "오른쪽" 스트로크(ㅘ)로 잘못 확정되는
                    // 문제가 있었다. 완전히 다른(인접하지 않은) 방향은 기준점을 끌고 가지
                    // 않는다 — 그러면 진짜 다른 방향으로 이동한 거리가 누적되지 못해
                    // 의도된 2획 제스처(ㅘ/ㅝ 등)까지 막아버리기 때문이다.
                    lastDirectionChangePoint = currentPoint
                }
            } else {
                // Still moving in the same confirmed direction: keep dragging the
                // reference point forward for the same reason as above.
                lastDirectionChangePoint = currentPoint
            }
        } else {
            // First direction
            directions.append(newDirection)
            directionMagnitudes.append(magnitude)
            lastDirectionChangePoint = currentPoint
        }
    }

    func finalizeGesture() -> [GestureDirection] {
        let segments = zip(directions, directionMagnitudes).map {
            DirectionSegment(direction: $0.0, magnitude: $0.1)
        }
        return normalizeSegments(segments).map { $0.direction }
    }

    // MARK: - Y계열(ㅑㅕㅛㅠ) 원점 복귀 인식기 (실험적 기능)

    /// 오른쪽=ㅑ, 왼쪽=ㅕ, 위=ㅛ, 아래=ㅠ. 기존 기본 방향 관례(오른쪽=ㅏ, 왼쪽=ㅓ,
    /// 위=ㅗ, 아래=ㅜ)를 그대로 따라, 각 기본 모음의 Y계열 쌍으로 대응시킨다.
    private static func yVowel(for direction: GestureDirection) -> Jungseong? {
        switch direction {
        case .right: return .ㅑ
        case .left: return .ㅕ
        case .up: return .ㅛ
        case .down: return .ㅠ
        default: return nil
        }
    }

    private func updateYVowelState(with point: CGPoint) {
        guard yVowelOriginPoint != nil else {
            // 이번 제스처의 첫 호출: 원점과 이전 점을 함께 초기화하고, 아직 이탈
            // 거리를 계산할 대상이 없으므로 Y 분석은 건너뛴다(이 리턴은 이 서브루틴
            // 안에서만 끝나는 것이며, addPoint 함수 전체를 빠져나가는 게 아니다).
            yVowelOriginPoint = point
            yVowelPreviousPoint = point
            return
        }

        defer { yVowelPreviousPoint = point }
        analyzeYVowelMovement(currentPoint: point)
    }

    private func analyzeYVowelMovement(currentPoint: CGPoint) {
        guard let origin = yVowelOriginPoint else { return }
        guard !isExcludedFromYVowelCandidacy else { return }
        // 종결성 불변조건: 확정 후에는 reset() 전까지 절대 재계산하지 않는다.
        guard yVowelPhase != .confirmed else { return }

        let dx = currentPoint.x - origin.x
        let dy = currentPoint.y - origin.y
        let distanceFromOrigin = sqrt(dx * dx + dy * dy)

        switch yVowelPhase {
        case .idle:
            handleYVowelIdlePhase(dx: dx, dy: dy, distanceFromOrigin: distanceFromOrigin)
        case .outbound:
            handleYVowelOutboundPhase(currentPoint: currentPoint, origin: origin, distanceFromOrigin: distanceFromOrigin)
        case .returned:
            handleYVowelReturnedPhase(dx: dx, dy: dy, distanceFromOrigin: distanceFromOrigin)
        case .confirmed:
            break
        }
    }

    /// 규칙1(최초 유효 방향 기록) + 규칙2(idle→outbound 전환)를 순서대로 검사한다.
    /// 한 번의 호출로 거리가 두 임계값을 동시에 넘어도 정상 동작하도록, 최초 방향을
    /// 막 기록한 직후 같은 호출 안에서 곧바로 outbound 진입 여부까지 확인한다.
    private func handleYVowelIdlePhase(dx: CGFloat, dy: CGFloat, distanceFromOrigin: CGFloat) {
        if firstMeaningfulDirection == nil {
            guard distanceFromOrigin >= threshold else { return }
            guard let direction = GestureDirection.from(vector: CGVector(dx: dx, dy: dy), threshold: threshold) else {
                return
            }
            firstMeaningfulAngle = GestureDirection.angleDegrees(dx: dx, dy: dy)
            firstMeaningfulDirection = direction

            if direction.isDiagonal {
                // 대각선으로 시작한 제스처(예: ㅢ)는 이후 방향이 어떻게 바뀌어도
                // 절대 outbound에 진입하지 않도록 영구 배제한다.
                isExcludedFromYVowelCandidacy = true
                return
            }
        }

        guard let firstDirection = firstMeaningfulDirection,
              let firstAngle = firstMeaningfulAngle,
              distanceFromOrigin >= yVowelOutboundEntryDistance,
              let currentDirection = GestureDirection.from(vector: CGVector(dx: dx, dy: dy), threshold: threshold) else {
            return
        }

        let currentAngle = GestureDirection.angleDegrees(dx: dx, dy: dy)
        guard currentDirection == firstDirection,
              circularAngleDifference(currentAngle, firstAngle) <= yVowelAngleToleranceDegrees else {
            // 초반과 다른 축으로 휘었으면(예: 위로 이탈하다 오른쪽으로 휘어 ㅘ 경로가
            // 되는 경우) outbound 진입이 무산된다 — 이 제스처는 Y 후보가 될 수 없다.
            return
        }

        yVowelOutboundDirection = currentDirection
        yVowelOutboundAngle = currentAngle
        yVowelPhase = .outbound
    }

    /// 복귀 판정: 현재 점이 복귀 반경 안이거나, 직전 점→현재 점 선분이 원점에
    /// 복귀 반경 이하로 근접하면 복귀로 인정한다(빠른 왕복으로 샘플이 원점 근처를
    /// 건너뛰는 경우를 보완).
    private func handleYVowelOutboundPhase(currentPoint: CGPoint, origin: CGPoint, distanceFromOrigin: CGFloat) {
        let returnRadius = yVowelReturnRadius
        if distanceFromOrigin <= returnRadius {
            yVowelPhase = .returned
            return
        }

        let previous = yVowelPreviousPoint ?? origin
        let segmentDistance = segmentToPointDistance(from: previous, to: currentPoint, point: origin)
        if segmentDistance <= returnRadius {
            yVowelPhase = .returned
        }
    }

    private func handleYVowelReturnedPhase(dx: CGFloat, dy: CGFloat, distanceFromOrigin: CGFloat) {
        guard distanceFromOrigin >= yVowelRedepartureDistance,
              let outboundDirection = yVowelOutboundDirection,
              let outboundAngle = yVowelOutboundAngle,
              let currentDirection = GestureDirection.from(vector: CGVector(dx: dx, dy: dy), threshold: threshold) else {
            return
        }

        let currentAngle = GestureDirection.angleDegrees(dx: dx, dy: dy)
        guard currentDirection == outboundDirection,
              circularAngleDifference(currentAngle, outboundAngle) <= yVowelAngleToleranceDegrees else {
            return
        }

        yVowelPhase = .confirmed
        confirmedYVowel = Self.yVowel(for: outboundDirection)
    }

    /// 선분(previous→current)과 원점 사이의 최단거리. 선분 길이의 제곱이 아주
    /// 작으면(중복 좌표) 0 나누기로 NaN이 되는 것을 막기 위해 점 거리로 폴백한다.
    private func segmentToPointDistance(from previous: CGPoint, to current: CGPoint, point: CGPoint) -> CGFloat {
        let vx = current.x - previous.x
        let vy = current.y - previous.y
        let segmentLengthSquared = vx * vx + vy * vy

        guard segmentLengthSquared > 1e-9 else {
            let ox = point.x - current.x
            let oy = point.y - current.y
            return sqrt(ox * ox + oy * oy)
        }

        var t = ((point.x - previous.x) * vx + (point.y - previous.y) * vy) / segmentLengthSquared
        t = min(max(t, 0), 1)

        let closestX = previous.x + t * vx
        let closestY = previous.y + t * vy
        let dx = point.x - closestX
        let dy = point.y - closestY
        return sqrt(dx * dx + dy * dy)
    }

    /// 0..<360도 범위 두 각도의 원형 거리(예: 359도와 1도의 차이는 2도).
    private func circularAngleDifference(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let diff = abs(a - b)
        return min(diff, 360 - diff)
    }

    /// Keep intentional turns for 3-stroke gestures (important for ㅙ/ㅞ),
    /// while removing duplicate and jitter-only segments.
    private func normalizeSegments(_ segments: [DirectionSegment]) -> [DirectionSegment] {
        guard !segments.isEmpty else { return [] }

        var collapsed = collapseConsecutiveDuplicates(segments)
        collapsed = collapseTinyOscillations(collapsed)
        collapsed = trimTinyLeadingAndTrailingNoise(collapsed)
        return collapsed
    }

    private func collapseConsecutiveDuplicates(_ segments: [DirectionSegment]) -> [DirectionSegment] {
        guard !segments.isEmpty else { return [] }

        var result: [DirectionSegment] = [segments[0]]
        for segment in segments.dropFirst() {
            if segment.direction == result.last?.direction {
                if segment.magnitude > (result.last?.magnitude ?? 0) {
                    result[result.count - 1].magnitude = segment.magnitude
                }
                continue
            }
            result.append(segment)
        }
        return result
    }

    private func collapseTinyOscillations(_ segments: [DirectionSegment]) -> [DirectionSegment] {
        guard segments.count >= 3 else { return segments }

        var result = segments
        var index = 1

        let jitterMagnitudeCap = max(reversalThreshold, directionChangeThreshold * 0.8)
        // 0.75 was cutting it too close for a genuine small return-to-same-direction
        // jitter right at the boundary (see testFinalizeCollapsesTinyDiagonalJitter...);
        // 0.8 gives that case comfortable margin without affecting any pattern where
        // the path doesn't return to the same direction (that's gated separately by
        // `returnsToPrevious` above).
        let jitterRatio: CGFloat = 0.8

        while index < result.count - 1 {
            let previous = result[index - 1]
            let current = result[index]
            let next = result[index + 1]

            let returnsToPrevious = previous.direction == next.direction
            let isAdjacentJitter = current.direction.isAdjacentTo(previous.direction)
            let isTinySegment = current.magnitude <= jitterMagnitudeCap ||
                current.magnitude <= min(previous.magnitude, next.magnitude) * jitterRatio

            if returnsToPrevious && isAdjacentJitter && isTinySegment {
                result[index - 1].magnitude = max(previous.magnitude, next.magnitude)
                result.remove(at: index + 1)
                result.remove(at: index)
                if index > 1 {
                    index -= 1
                }
                continue
            }

            index += 1
        }

        return result
    }

    private func trimTinyLeadingAndTrailingNoise(_ segments: [DirectionSegment]) -> [DirectionSegment] {
        guard segments.count > 1 else { return segments }

        var result = segments
        let edgeNoiseCap = max(reversalThreshold, directionChangeThreshold * 0.8)

        if let first = result.first, let second = result.dropFirst().first {
            if first.magnitude <= edgeNoiseCap && first.direction.isAdjacentTo(second.direction) {
                result.removeFirst()
            }
        }

        if result.count > 1, let last = result.last, let previous = result.dropLast().last {
            if last.magnitude <= edgeNoiseCap && last.direction.isAdjacentTo(previous.direction) {
                result.removeLast()
            }
        }

        return result
    }
}

// Extension to help with gesture visualization
extension GestureAnalyzer {
    var directionString: String {
        directions.map { $0.symbol }.joined()
    }

    var hasGesture: Bool {
        !directions.isEmpty
    }
}
