import SwiftUI

struct KeyGridView: View {
    let centerKeyWidth: CGFloat
    let keyHeight: CGFloat
    let totalWidth: CGFloat
    let isSymbolMode: Bool
    let activeKey: (row: Int, column: Int)?
    let previewVowel: Jungseong?
    let onConsonantTap: (Choseong) -> Void
    let onSymbolTap: (String) -> Void
    let onBackspacePressStart: () -> Void
    let onBackspacePressEnd: () -> Void
    let onLongPressNumber: (String) -> Void
    let onGestureStart: (Int, Int, CGPoint) -> Void
    let onGestureMove: (CGPoint) -> Void
    let onGestureEnd: (Int, Int) -> Void

    var body: some View {
        VStack(spacing: KeyboardMetrics.keySpacing) {
            ForEach(0..<KeyboardMetrics.gridRows, id: \.self) { row in
                HStack(spacing: KeyboardMetrics.keySpacing) {
                    let columnCount = KeyboardMetrics.columnCount(for: row, isSymbolMode: isSymbolMode)

                    ForEach(0..<columnCount, id: \.self) { column in
                        let content = KeyboardMetrics.keyContent(at: row, column: column, isSymbolMode: isSymbolMode)
                        let isActive = activeKey?.row == row && activeKey?.column == column
                        // 숫자 롱프레스가 없는 자음 키(ㅋㅌㅊㅍ)는 사용자 지정 문구로 대체한다.
                        let longPressNumber = isSymbolMode ? nil :
                            (KeyboardMetrics.longPressNumber(at: row, column: column) ?? snippetLongPressValue(for: content))
                        let width = KeyboardMetrics.keyWidth(
                            for: column,
                            row: row,
                            centerKeyWidth: centerKeyWidth,
                            isSymbolMode: isSymbolMode
                        )

                        KeyView(
                            content: content ?? .symbol(""),
                            keySize: CGSize(width: width, height: keyHeight),
                            isPressed: isActive,
                            previewVowel: isActive ? previewVowel : nil,
                            longPressNumber: longPressNumber,
                            directionalLongPressOptions: isSymbolMode ? nil : directionalLongPressOptions(for: content),
                            onLongPress: { number in
                                onLongPressNumber(number)
                            },
                            onBackspacePressStart: {
                                guard case .backspace = content else { return }
                                onBackspacePressStart()
                            },
                            onBackspacePressEnd: {
                                guard case .backspace = content else { return }
                                onBackspacePressEnd()
                            },
                            onGestureStart: { point in
                                onGestureStart(row, column, point)
                            },
                            onGestureMove: { point in
                                onGestureMove(point)
                            },
                            onGestureEnd: {
                                onGestureEnd(row, column)
                            }
                        )
                    }
                }
            }
        }
    }

    private func snippetLongPressValue(for content: KeyContent?) -> String? {
        guard case .consonant(let choseong) = content else { return nil }
        return SnippetSettings.snippet(for: choseong)
    }

    /// ㅡ 키를 길게 누르면 상하좌우에 문장부호 후보가 뜬다: 위=",", 아래=".", 왼쪽="!", 오른쪽="?".
    private func directionalLongPressOptions(for content: KeyContent?) -> DirectionalLongPressOptions? {
        guard case .cheonjiinStroke(.eu) = content else { return nil }
        return DirectionalLongPressOptions(up: ",", down: ".", left: "!", right: "?")
    }
}

// Legacy alias for compatibility
typealias ConsonantGridView = KeyGridView

#Preview {
    VStack(spacing: 20) {
        Text("Korean Mode")
            .font(.headline)
        KeyGridView(
            centerKeyWidth: 45,
            keyHeight: 50,
            totalWidth: 350,
            isSymbolMode: false,
            activeKey: (1, 2),
            previewVowel: .ㅏ,
            onConsonantTap: { _ in },
            onSymbolTap: { _ in },
            onBackspacePressStart: {},
            onBackspacePressEnd: {},
            onLongPressNumber: { _ in },
            onGestureStart: { _, _, _ in },
            onGestureMove: { _ in },
            onGestureEnd: { _, _ in }
        )

        Text("Symbol Mode")
            .font(.headline)
        KeyGridView(
            centerKeyWidth: 45,
            keyHeight: 50,
            totalWidth: 350,
            isSymbolMode: true,
            activeKey: nil,
            previewVowel: nil,
            onConsonantTap: { _ in },
            onSymbolTap: { _ in },
            onBackspacePressStart: {},
            onBackspacePressEnd: {},
            onLongPressNumber: { _ in },
            onGestureStart: { _, _, _ in },
            onGestureMove: { _ in },
            onGestureEnd: { _, _ in }
        )
    }
    .padding()
    .background(Color(.systemGray6))
}
