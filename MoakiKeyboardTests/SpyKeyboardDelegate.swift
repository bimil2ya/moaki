import XCTest

final class SpyKeyboardDelegate: KeyboardViewModelDelegate {
    struct ComposingUpdate: Equatable {
        let previous: String
        let current: String
    }

    var insertedTexts: [String] = []
    var deleteCount = 0
    var composingUpdates: [ComposingUpdate] = []
    var switchKeyboardCount = 0
    var hapticCount = 0
    var cursorOffsets: [Int] = []
    var characterBeforeCursorStub: Character?
    var onDelete: (() -> Void)?

    func insertText(_ text: String) {
        insertedTexts.append(text)
    }

    func deleteBackward() {
        deleteCount += 1
        onDelete?()
    }

    func updateComposingText(from previous: String, to current: String) {
        composingUpdates.append(.init(previous: previous, current: current))
    }

    func switchToNextKeyboard() {
        switchKeyboardCount += 1
    }

    func triggerHapticFeedback() {
        hapticCount += 1
    }

    func moveCursor(byCharacterOffset offset: Int) {
        cursorOffsets.append(offset)
    }

    func characterBeforeCursor() -> Character? {
        characterBeforeCursorStub
    }
}
