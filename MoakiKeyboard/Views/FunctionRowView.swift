import SwiftUI

struct FunctionRowView: View {
    let totalWidth: CGFloat
    let isSymbolMode: Bool
    let onToggleModePressed: () -> Void
    let onSnippetsPressed: () -> Void
    let onHanjaPressed: () -> Void
    let onSpaceDragStart: (CGPoint) -> Void
    let onSpaceDragMove: (CGPoint) -> Void
    let onSpaceDragEnd: () -> Void
    let onPunctuationPressed: () -> Void
    let onReturnPressed: () -> Void

    private let spacing: CGFloat = KeyboardMetrics.keySpacing
    private let height: CGFloat = KeyboardMetrics.functionRowHeight

    var body: some View {
        HStack(spacing: spacing) {
            // 123/한글 toggle button
            FunctionKeyView(
                content: AnyView(
                    Text(isSymbolMode ? "한글" : "123")
                        .font(.system(size: 16, weight: .medium))
                ),
                width: toggleWidth,
                height: height,
                action: onToggleModePressed,
                accessibilityLabel: isSymbolMode ? "한글 키보드로 전환" : "숫자 및 기호 키보드로 전환"
            )

            // 문구: 등록해둔 문구를 후보 바로 보여주는 버튼
            // (지구본은 iOS가 서드파티 키보드에 강제로 붙이는 하단 시스템 바로도
            // 이미 전환이 가능해서, 기능행에서는 빼고 이 자리를 문구 단축키로 쓴다)
            FunctionKeyView(
                content: AnyView(
                    Text("문구")
                        .font(.system(size: 15, weight: .medium))
                ),
                width: sideWidth,
                height: height,
                action: onSnippetsPressed,
                accessibilityLabel: "문구"
            )

            // 한자 변환 (커서 앞 음절의 한자 후보 표시)
            FunctionKeyView(
                content: AnyView(
                    Text("한자")
                        .font(.system(size: 15, weight: .medium))
                ),
                width: sideWidth,
                height: height,
                action: onHanjaPressed,
                accessibilityLabel: "한자 변환",
                accessibilityHint: "커서 앞 한글 음절의 한자 후보를 표시합니다"
            )

            // Space bar (길게 드래그하면 트랙패드처럼 커서 이동)
            FunctionKeyView(
                content: AnyView(
                    Text("space")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                ),
                width: spaceWidth,
                height: height,
                action: onSpaceDragEnd,
				accessibilityLabel: "스페이스",
				accessibilityHint: "두 번 탭하면 공백을 입력합니다. 드래그하면 커서를 이동합니다",
                onDragStart: onSpaceDragStart,
                onDragMove: onSpaceDragMove,
				onDragEnd: onSpaceDragEnd
            )

            // Punctuation cluster (. , ? ! 순환 입력)
            FunctionKeyView(
                content: AnyView(
                    Text(".")
                        .font(.system(size: 20))
                ),
                width: sideWidth,
                height: height,
                action: onPunctuationPressed,
                accessibilityLabel: "문장 부호",
                accessibilityHint: "탭할 때마다 마침표, 쉼표, 물음표, 느낌표 순서로 입력합니다"
            )

            // Return button
            FunctionKeyView(
                content: AnyView(
                    Image(systemName: "return")
                        .font(.system(size: 20))
                ),
                width: returnWidth,
                height: height,
                action: onReturnPressed,
                accessibilityLabel: "줄 바꿈"
            )
        }
    }

    private var sideWidth: CGFloat {
        KeyboardMetrics.minimumInteractiveKeyWidth
    }

    private var returnWidth: CGFloat {
        sideWidth
    }

    // 6개 버튼: 문구/한자/punctuation/return은 고정(sideWidth), toggle/space가 나머지를 나눠 가진다.
    private var remainingWidth: CGFloat {
        totalWidth - sideWidth * 4 - spacing * 7
    }

    private var toggleWidth: CGFloat {
        max(KeyboardMetrics.minimumInteractiveKeyWidth, remainingWidth * 0.35)
    }

    private var spaceWidth: CGFloat {
        remainingWidth - toggleWidth
    }
}

struct FunctionKeyView: View {
    let content: AnyView
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void
	var accessibilityLabel: String = ""
	var accessibilityHint: String? = nil
    var onDragStart: ((CGPoint) -> Void)? = nil
    var onDragMove: ((CGPoint) -> Void)? = nil
    var onDragEnd: (() -> Void)? = nil

    @State private var isPressed = false

    var body: some View {
        content
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius)
                    .fill(isPressed ? Color(.systemGray4) : Color(.systemGray5))
            )
        .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isPressed {
                            isPressed = true
                            onDragStart?(value.location)
                        }
                        onDragMove?(value.location)
                    }
                    .onEnded { _ in
                        isPressed = false
                        if let onDragEnd {
                            onDragEnd()
                        } else {
                            action()
                        }
                    }
            )
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(accessibilityLabel)
		.accessibilityHint(accessibilityHint ?? "두 번 탭하여 실행합니다")
		.accessibilityAddTraits(.isButton)
		.accessibilityAction {
			action()
		}
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Korean Mode")
            .font(.headline)
        FunctionRowView(
            totalWidth: 350,
            isSymbolMode: false,
            onToggleModePressed: { print("Toggle") },
            onSnippetsPressed: { print("Snippets") },
            onHanjaPressed: { print("Hanja") },
            onSpaceDragStart: { _ in print("Space drag start") },
            onSpaceDragMove: { _ in print("Space drag move") },
            onSpaceDragEnd: { print("Space drag end") },
            onPunctuationPressed: { print("Punctuation") },
            onReturnPressed: { print("Return") }
        )

        Text("Symbol Mode")
            .font(.headline)
        FunctionRowView(
            totalWidth: 350,
            isSymbolMode: true,
            onToggleModePressed: { print("Toggle") },
            onSnippetsPressed: { print("Snippets") },
            onHanjaPressed: { print("Hanja") },
            onSpaceDragStart: { _ in print("Space drag start") },
            onSpaceDragMove: { _ in print("Space drag move") },
            onSpaceDragEnd: { print("Space drag end") },
            onPunctuationPressed: { print("Punctuation") },
            onReturnPressed: { print("Return") }
        )
    }
    .padding()
    .background(Color(.systemGray6))
}
