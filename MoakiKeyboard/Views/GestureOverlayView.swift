import SwiftUI

/// 천지인 스트로크(ㅣㅡㆍ)를 여러 번 눌러 모음을 조합하는 동안, 아직 확정되지 않고
/// 대기 중인 모음을 터치 지점 위에 띄워 보여준다.
///
/// 드래그 제스처(방향 화살표 + 예상 모음)를 보여주던 기능은 실사용에 도움이 안 된다는
/// 판단하에 제거했다 — 드래그가 인식되고 있다는 건 햅틱과 키 눌림 배경색 변화로만
/// 알려주고, 실제로 어떤 모음이 입력됐는지는 텍스트 필드에서 확인한다.
struct GestureOverlayView: View {
    let startPoint: CGPoint?
    let pendingVowel: Jungseong?

    var body: some View {
        GeometryReader { geometry in
            if let start = startPoint, let vowel = pendingVowel {
                ZStack {
                    Text(String(vowel.compatibilityCharacter))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.9))
                                .shadow(radius: 2)
                        )
                        .position(indicatorPosition(start: start, in: geometry.size))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func indicatorPosition(start: CGPoint, in size: CGSize) -> CGPoint {
        // Position the indicator above the touch point
        var x = start.x
        var y = start.y - 80

        // Keep within bounds
        x = max(50, min(size.width - 50, x))
        y = max(40, y)

        return CGPoint(x: x, y: y)
    }
}

#Preview {
    ZStack {
        Color(.systemGray6)

        GestureOverlayView(
            startPoint: CGPoint(x: 150, y: 200),
            pendingVowel: .ㅘ
        )
    }
    .frame(width: 300, height: 300)
}
