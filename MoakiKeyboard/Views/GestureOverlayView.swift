import SwiftUI

struct GestureOverlayView: View {
    let directions: [GestureDirection]
    let startPoint: CGPoint?
    let currentVowel: Jungseong?

    var body: some View {
        GeometryReader { geometry in
            // 드래그 제스처(방향이 있음) 또는 천지인 탭(방향 없이 대기 중인 모음만 있음)
            // 둘 중 하나라도 보여줄 내용이 있으면 그린다.
            if let start = startPoint, !directions.isEmpty || currentVowel != nil {
                ZStack {
                    // Direction indicator text
                    VStack(spacing: 4) {
                        if !directions.isEmpty {
                            Text(directions.map { $0.symbol }.joined())
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.blue)
                        }

                        if let vowel = currentVowel {
                            Text(String(vowel.compatibilityCharacter))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }
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
            directions: [.up, .right],
            startPoint: CGPoint(x: 150, y: 200),
            currentVowel: .ㅘ
        )
    }
    .frame(width: 300, height: 300)
}
