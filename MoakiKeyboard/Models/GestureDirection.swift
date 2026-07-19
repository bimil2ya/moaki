import Foundation
import CoreGraphics

enum GestureDirection: String, CaseIterable {
    case up        // ↑
    case down      // ↓
    case left      // ←
    case right     // →
    case upLeft    // ↖
    case upRight   // ↗
    case downLeft  // ↙
    case downRight // ↘

    /// 벡터의 각도를 0..<360도 범위로 반환한다(iOS 좌표계는 y축이 아래로 증가하므로
    /// `-dy`로 반전해서 계산). 방향 분류(`from(vector:threshold:)`)와, 이 각도값을
    /// 직접 필요로 하는 다른 코드(예: Y계열 원점 복귀 인식기의 각도 오차 비교)가
    /// 반드시 이 헬퍼 하나를 함께 호출해서, 두 계산이 서로 다른 좌표 변환으로
    /// 미묘하게 어긋나는 일이 없게 한다.
    static func angleDegrees(dx: CGFloat, dy: CGFloat) -> CGFloat {
        let angle = atan2(-dy, dx) // Negative dy because iOS y-axis is inverted
        let degrees = angle * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// - Parameter upSectorExpansionDegrees: 왼쪽 끝 자음 열(ㅃㅂㅁㅋ)에서 위로 드래그할 때
    ///   손동작이 화면 중앙(오른쪽)으로 휘어져 up이 upRight(ㅣ)로 잘못 분류되는 문제를
    ///   보정하기 위한 값. 0(기본값)이면 기존과 100% 동일한 경계. up과 upRight 사이의
    ///   "공유 경계"만 낮추고(80도 → 최소 50도까지), 그 외 모든 섹터(특히 down 계열)는
    ///   전혀 건드리지 않는다. 0...30으로 클램프한다 — 그 이상이면 upRight 대역(30도
    ///   하한)과 겹쳐 역전된 Range가 되어 크래시하기 때문이다.
    static func from(vector: CGVector, threshold: CGFloat = 20, upSectorExpansionDegrees: CGFloat = 0) -> GestureDirection? {
        let magnitude = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
        guard magnitude >= threshold else { return nil }

        let normalizedDegrees = angleDegrees(dx: vector.dx, dy: vector.dy)

        let expansion = min(max(upSectorExpansionDegrees, 0), 30)
        let upLowerBound: CGFloat = 80 - expansion

        // 8 directions with adjusted sectors (wider right-diagonals for ㅣ, ㅡ)
        switch normalizedDegrees {
        case 330...360, 0..<30:
            return .right
        case 30..<upLowerBound:
            return .upRight
        case upLowerBound..<120:
            return .up
        case 120..<150:
            return .upLeft
        case 150..<210:
            return .left
        case 210..<240:
            return .downLeft
        case 240..<280:
            return .down
        case 280..<330:
            return .downRight
        default:
            return .right
        }
    }

    var symbol: String {
        switch self {
        case .up: return "↑"
        case .down: return "↓"
        case .left: return "←"
        case .right: return "→"
        case .upLeft: return "↖"
        case .upRight: return "↗"
        case .downLeft: return "↙"
        case .downRight: return "↘"
        }
    }

    var isCardinal: Bool {
        switch self {
        case .up, .down, .left, .right: return true
        default: return false
        }
    }

    var isDiagonal: Bool {
        !isCardinal
    }

    /// The exact opposite direction (e.g. up <-> down, downRight <-> upLeft).
    var opposite: GestureDirection {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        case .upLeft: return .downRight
        case .downRight: return .upLeft
        case .upRight: return .downLeft
        case .downLeft: return .upRight
        }
    }

    /// Check if two directions are exactly opposite (e.g., up↔down, left↔right)
    func isOpposite(to other: GestureDirection) -> Bool {
        opposite == other
    }

    /// True when `self` is heading back toward `other` — either `other`'s exact
    /// opposite, or one of the two directions adjacent to that exact opposite.
    /// Real fingers rarely retrace the precise reverse angle, so reversal
    /// detection (and the lower reversal threshold it unlocks) treats both as
    /// "this is a reversal", not just the one exact angle.
    /// - Parameter isFirstStroke: whether `other` is the gesture's very first
    ///   recorded stroke. Only `.up` and `.down` as the *first* stroke are
    ///   genuinely ambiguous (↑ branches into ㅚ/ㅛ vs ㅘ/ㅙ depending on
    ///   whether the next stroke is ↓ or →; ↓ branches into ㅟ/ㅠ vs ㅝ/ㅞ the
    ///   same way) — everywhere else in this app's vowel patterns, once you
    ///   know `other`, there's only ever one meaningful stroke that can follow
    ///   it, so any sufficiently-different stroke can only mean that one thing.
    func isReversal(of other: GestureDirection, isFirstStroke: Bool) -> Bool {
        let needsExactAngle = isFirstStroke && (other == .up || other == .down)
        guard needsExactAngle else {
            // Real fingers reverse at all kinds of angles, not just the precise
            // 180° — accept anything that isn't basically still heading the
            // original way (same direction, or adjacent to it).
            return self != other && !isAdjacentTo(other)
        }

        let trueOpposite = other.opposite
        return self == trueOpposite || isAdjacentTo(trueOpposite)
    }

    /// Check if two directions are adjacent (e.g., up and upRight are adjacent)
    func isAdjacentTo(_ other: GestureDirection) -> Bool {
        let adjacencyMap: [GestureDirection: Set<GestureDirection>] = [
            .up: [.upLeft, .upRight],
            .down: [.downLeft, .downRight],
            .left: [.upLeft, .downLeft],
            .right: [.upRight, .downRight],
            .upLeft: [.up, .left],
            .upRight: [.up, .right],
            .downLeft: [.down, .left],
            .downRight: [.down, .right]
        ]
        return adjacencyMap[self]?.contains(other) ?? false
    }
}
