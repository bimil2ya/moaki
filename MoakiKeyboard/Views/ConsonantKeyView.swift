import SwiftUI

/// 롱프레스로 상하좌우 4방향에 문장부호 등을 배치해 슬라이드로 고르는 옵션.
/// (예: ㅡ 키를 길게 누르면 뜨는 위/아래/왼쪽/오른쪽 후보)
struct DirectionalLongPressOptions {
    let up: String
    let down: String
    let left: String
    let right: String
}

struct KeyView: View {
    let content: KeyContent
    let keySize: CGSize
    let isPressed: Bool
    let previewVowel: Jungseong?
    let longPressNumber: String?
    let directionalLongPressOptions: DirectionalLongPressOptions?
    let onLongPress: ((String) -> Void)?
    let onBackspacePressStart: (() -> Void)?
    let onBackspacePressEnd: (() -> Void)?
    let onGestureStart: (CGPoint) -> Void
    let onGestureMove: (CGPoint) -> Void
    let onGestureEnd: () -> Void

    init(
        content: KeyContent,
        keySize: CGSize,
        isPressed: Bool,
        previewVowel: Jungseong?,
        longPressNumber: String?,
        directionalLongPressOptions: DirectionalLongPressOptions? = nil,
        onLongPress: ((String) -> Void)?,
        onBackspacePressStart: (() -> Void)?,
        onBackspacePressEnd: (() -> Void)?,
        onGestureStart: @escaping (CGPoint) -> Void,
        onGestureMove: @escaping (CGPoint) -> Void,
        onGestureEnd: @escaping () -> Void
    ) {
        self.content = content
        self.keySize = keySize
        self.isPressed = isPressed
        self.previewVowel = previewVowel
        self.longPressNumber = longPressNumber
        self.directionalLongPressOptions = directionalLongPressOptions
        self.onLongPress = onLongPress
        self.onBackspacePressStart = onBackspacePressStart
        self.onBackspacePressEnd = onBackspacePressEnd
        self.onGestureStart = onGestureStart
        self.onGestureMove = onGestureMove
        self.onGestureEnd = onGestureEnd
    }

    @State private var isHighlighted = false
    @State private var showNumberPopup = false
    @State private var longPressTimer: Timer?
    @State private var isShowingDirectionalPopup = false
    @State private var highlightedDirectionSymbol: String?

    /// 이 거리 이상 움직여야 방향이 "골라졌다"고 본다 (가운데 죽은 영역).
    private let directionalSelectDeadzone: CGFloat = 16

    var body: some View {
        ZStack {
            // Key background
            RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius)
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.2), radius: isPressed ? 0 : 1, y: isPressed ? 0 : 1)

            // Key label
            keyLabel
        }
        .frame(width: keySize.width, height: keySize.height)
        .overlay(numberPopupOverlay, alignment: .top)
        .overlay(directionalPopupOverlay)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            activateForAccessibility()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isHighlighted {
                        isHighlighted = true
                        if isBackspaceKey {
                            onBackspacePressStart?()
                        } else {
                            onGestureStart(value.startLocation)
                            startLongPressTimer()
                        }
                    }

                    guard !isBackspaceKey else { return }

                    // 방향 선택 팝업이 떠 있으면, 일반 제스처 추적(모음 미리보기 등)은
                    // 건너뛰고 이 안에서만 방향을 판정한다.
                    if isShowingDirectionalPopup {
                        updateHighlightedDirection(translation: value.translation)
                        return
                    }

                    // Cancel long press if user moved significantly (for consonant gesture)
                    let distance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                    if distance > KeyboardMetrics.gestureThreshold {
                        cancelLongPressTimer()
                    }

                    onGestureMove(value.location)
                }
                .onEnded { _ in
                    isHighlighted = false
                    cancelLongPressTimer()
                    hideNumberPopup()

                    if isShowingDirectionalPopup {
                        if let selected = highlightedDirectionSymbol {
                            onLongPress?(selected)
                        }
                        isShowingDirectionalPopup = false
                        highlightedDirectionSymbol = nil
                    }

                    if isBackspaceKey {
                        onBackspacePressEnd?()
                    } else {
                        onGestureEnd()
                    }
                }
        )
        .onDisappear {
            if isHighlighted && isBackspaceKey {
                onBackspacePressEnd?()
            }
            cancelLongPressTimer()
            isHighlighted = false
            showNumberPopup = false
            isShowingDirectionalPopup = false
            highlightedDirectionSymbol = nil
        }
    }

    @ViewBuilder
    private var keyLabel: some View {
        switch content {
        case .consonant(let consonant):
            VStack(spacing: 2) {
                Text(String(consonant.compatibilityCharacter))
                    .font(.system(size: keySize.height * 0.4, weight: .medium))
                    .foregroundColor(textColor)

                // Show preview vowel when dragging
                if let vowel = previewVowel {
                    Text(String(vowel.compatibilityCharacter))
                        .font(.system(size: keySize.height * 0.25))
                        .foregroundColor(.blue)
                }
            }

        case .symbol(let symbol):
            Text(symbol)
                .font(.system(size: keySize.height * 0.4, weight: .medium))
                .foregroundColor(textColor)

        case .backspace:
            Image(systemName: "delete.left")
                .font(.system(size: keySize.height * 0.35))
                .foregroundColor(textColor)

        case .cheonjiinStroke(let stroke):
            Text(stroke.displayText)
                .font(.system(size: keySize.height * 0.4, weight: .medium))
                .foregroundColor(textColor)
        }
    }

    @ViewBuilder
    private var directionalPopupOverlay: some View {
        if isShowingDirectionalPopup, let options = directionalLongPressOptions {
            ZStack {
                directionLabel(options.up, isHighlighted: highlightedDirectionSymbol == options.up)
                    .offset(y: -keySize.height * 1.1)
                directionLabel(options.down, isHighlighted: highlightedDirectionSymbol == options.down)
                    .offset(y: keySize.height * 1.1)
                directionLabel(options.left, isHighlighted: highlightedDirectionSymbol == options.left)
                    .offset(x: -keySize.width * 1.1)
                directionLabel(options.right, isHighlighted: highlightedDirectionSymbol == options.right)
                    .offset(x: keySize.width * 1.1)
            }
        }
    }

    private func directionLabel(_ symbol: String, isHighlighted: Bool) -> some View {
        Text(symbol)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(isHighlighted ? .white : .primary)
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHighlighted ? Color.blue : Color(.systemBackground))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            )
            // 이 라벨은 드래그가 진행 중일 때만 잠깐 뜨는 시각적 힌트라 VoiceOver
            // 포커스 대상으로 노출하지 않는다 — 키 자체의 접근성 정보는 아래
            // body(메인 ZStack)에 붙어 있다.
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var numberPopupOverlay: some View {
        // 숫자 한 글자뿐 아니라 ㅋㅌㅊㅍ의 사용자 지정 문구(이메일 등 긴 텍스트)도
        // 이 팝업으로 보여주므로, 길어도 잘리지 않게 2줄까지 줄바꿈하고 필요하면 축소한다.
        if showNumberPopup, let number = longPressNumber {
            Text(number)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: 240)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                )
                .offset(y: -keySize.height * 0.8)
        }
    }

    private var backgroundColor: Color {
        switch content {
        case .backspace:
            return isPressed || isHighlighted ? Color(.systemGray3) : Color(.systemGray5)
        case .symbol, .cheonjiinStroke:
            return isPressed || isHighlighted ? Color(.systemGray3) : Color(.systemGray5)
        case .consonant:
            return isPressed || isHighlighted ? Color(.systemGray4) : Color(.secondarySystemBackground)
        }
    }

    private var textColor: Color {
        return .primary
    }

	private var accessibilityLabel: String {
		switch content {
		case .consonant(let consonant):
			return "\(consonant.compatibilityCharacter), 자음"
		case .symbol(let symbol):
			return "\(symbol), 기호"
		case .backspace:
			return "삭제"
		case .cheonjiinStroke(let stroke):
			return "천지인 모음, \(stroke.displayText)"
		}
	}

	private var accessibilityHint: String {
		switch content {
		case .consonant:
			return longPressNumber == nil
				? "두 번 탭하여 자음을 입력합니다. 모음은 천지인 키로 입력할 수 있습니다"
				: "두 번 탭하여 자음을 입력합니다. 길게 누르면 등록한 숫자 또는 문구를 입력합니다"
		case .symbol:
			return "두 번 탭하여 기호를 입력합니다"
		case .backspace:
			return "두 번 탭하여 한 글자를 삭제합니다"
		case .cheonjiinStroke:
			return "두 번 탭하여 천지인 모음 조합에 추가합니다"
		}
	}

	private func activateForAccessibility() {
		if isBackspaceKey {
			onBackspacePressStart?()
			onBackspacePressEnd?()
		} else {
			onGestureStart(.zero)
			onGestureEnd()
		}
	}

    private var isBackspaceKey: Bool {
        if case .backspace = content {
            return true
        }
        return false
    }

    private func startLongPressTimer() {
        guard longPressNumber != nil || directionalLongPressOptions != nil else { return }

        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            if directionalLongPressOptions != nil {
                // 방향 팝업은 여기서 바로 입력하지 않고, 손을 뗄 때 고른 방향을 넣는다.
                isShowingDirectionalPopup = true
            } else if let number = longPressNumber {
                showNumberPopup = true
                onLongPress?(number)
            }
        }
    }

    /// 방향 팝업이 뜬 상태에서 드래그 오프셋을 보고 상하좌우 중 어느 쪽에 가까운지 고른다.
    /// 가운데 죽은 영역(directionalSelectDeadzone) 안에 있으면 아직 고른 게 없는 상태로 둔다.
    private func updateHighlightedDirection(translation: CGSize) {
        guard let options = directionalLongPressOptions else { return }
        let dx = translation.width
        let dy = translation.height
        let magnitude = sqrt(dx * dx + dy * dy)

        guard magnitude >= directionalSelectDeadzone else {
            highlightedDirectionSymbol = nil
            return
        }

        if abs(dx) > abs(dy) {
            highlightedDirectionSymbol = dx > 0 ? options.right : options.left
        } else {
            highlightedDirectionSymbol = dy > 0 ? options.down : options.up
        }
    }

    private func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    private func hideNumberPopup() {
        showNumberPopup = false
    }
}

// Legacy alias for compatibility
typealias ConsonantKeyView = KeyView

#Preview {
    HStack {
        KeyView(
            content: .consonant(.ㄱ),
            keySize: CGSize(width: 50, height: 50),
            isPressed: false,
            previewVowel: nil,
            longPressNumber: "4",
            onLongPress: { _ in },
            onBackspacePressStart: nil,
            onBackspacePressEnd: nil,
            onGestureStart: { _ in },
            onGestureMove: { _ in },
            onGestureEnd: {}
        )

        KeyView(
            content: .consonant(.ㄴ),
            keySize: CGSize(width: 50, height: 50),
            isPressed: true,
            previewVowel: .ㅏ,
            longPressNumber: "7",
            onLongPress: { _ in },
            onBackspacePressStart: nil,
            onBackspacePressEnd: nil,
            onGestureStart: { _ in },
            onGestureMove: { _ in },
            onGestureEnd: {}
        )

        KeyView(
            content: .symbol("!"),
            keySize: CGSize(width: 50, height: 50),
            isPressed: false,
            previewVowel: nil,
            longPressNumber: nil,
            onLongPress: nil,
            onBackspacePressStart: nil,
            onBackspacePressEnd: nil,
            onGestureStart: { _ in },
            onGestureMove: { _ in },
            onGestureEnd: {}
        )

        KeyView(
            content: .backspace,
            keySize: CGSize(width: 50, height: 50),
            isPressed: false,
            previewVowel: nil,
            longPressNumber: nil,
            onLongPress: nil,
            onBackspacePressStart: {},
            onBackspacePressEnd: {},
            onGestureStart: { _ in },
            onGestureMove: { _ in },
            onGestureEnd: {}
        )
    }
    .padding()
    .background(Color(.systemGray6))
}
