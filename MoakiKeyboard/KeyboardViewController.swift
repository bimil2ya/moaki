import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {

    private var keyboardView: UIViewController?
    private let viewModel = KeyboardViewModel()
    private var feedbackGenerator: UIImpactFeedbackGenerator?
    private var heightConstraint: NSLayoutConstraint?

    /// 이 확장 자체가 텍스트를 편집하는 동안(insertText/deleteBackward/커서 이동)만 true다.
    /// textDidChange/selectionDidChange가 우리 자신의 편집 때문에 불렸는지, 아니면
    /// 외부(자동완성, 붙여넣기, 호스트 앱, 커서를 직접 탭해서 옮기는 것 등) 때문에
    /// 불렸는지 구분하는 데 쓴다. 편집 호출 직후 다음 런루프로 미뤄서 0으로 되돌리는
    /// 이유는, textDidChange가 항상 같은 실행 컨텍스트에서 동기적으로 오지 않을 수
    /// 있어서 그 콜백이 실제로 오기 전에 플래그가 꺼지지 않게 하기 위함이다.
    private var ownEditDepth = 0
    private var isPerformingOwnEdit: Bool { ownEditDepth > 0 }

    override func viewDidLoad() {
        super.viewDidLoad()

        // 키보드 높이 설정 (iOS 키보드 익스텐션은 명시적 높이 필요)
        let heightConstraint = NSLayoutConstraint(
            item: view!,
            attribute: .height,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1.0,
            constant: 260
        )
        heightConstraint.priority = .required
        view.addConstraint(heightConstraint)
        self.heightConstraint = heightConstraint

        viewModel.delegate = self
        setupKeyboardView()
        setupHapticFeedback()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        heightConstraint?.constant = 260
        heightConstraint?.isActive = true
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // This runs on every keyboard appearance, not just after backgrounding.
        // Keyboard extensions can't reliably observe UIApplication lifecycle
        // notifications, so we apply these lightweight resets unconditionally.

        // Force UIHostingController to re-enable touch delivery.
        // After keyboard extension lifecycle transitions, the hosting view
        // can lose touch responsiveness. Toggling isUserInteractionEnabled
        // forces UIKit to re-attach the gesture recognizer hierarchy.
        // Tested on iOS 17/18. Re-evaluate if touch issues recur on future versions.
        if let hostingView = keyboardView?.view {
            hostingView.isUserInteractionEnabled = false
            hostingView.isUserInteractionEnabled = true
        }

        // Reset any stuck gesture state (e.g., user was mid-drag when backgrounding)
        viewModel.resetGestureState()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // 다른 키보드로 전환하거나 앱이 백그라운드로 갈 때, 천지인 조합 대기 중인
        // 모음이 있으면 이 시점에 확정한다(기존에 자음/기호 입력 등 다른 전환 시
        // flushPendingCheonjiin을 부르던 것과 동일한 원칙 — 대기 상태를 조용히
        // 버리지 않고 확정한다). 안 그러면 최대 0.45초짜리 자동확정 타이머가 화면이
        // 사라진 뒤에도 계속 살아있다가, 나중에 엉뚱한 시점에 입력을 실행할 수 있다.
        viewModel.flushPendingStateBeforeDisappearing()
    }

    private func setupKeyboardView() {
        let rootView = KeyboardView(viewModel: viewModel).ignoresSafeArea(.all)
        let hostingController = UIHostingController(rootView: rootView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        keyboardView = hostingController
    }

    private func setupHapticFeedback() {
        feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        feedbackGenerator?.prepare()
    }

    override func textWillChange(_ textInput: UITextInput?) {
        // Called when the text is about to change
    }

    override func textDidChange(_ textInput: UITextInput?) {
        guard !isPerformingOwnEdit else { return }

        // 우리가 시킨 게 아닌 텍스트 변경(자동완성, 붙여넣기, 호스트 앱이 직접
        // 텍스트를 바꾸는 경우 등) — 우리가 추적하던 조합 상태가 실제 텍스트와
        // 어긋났을 수 있으므로, 무언가를 더 지우거나 고치려 하지 않고 조용히
        // 내부 상태만 버린다.
        viewModel.resetComposer()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        guard !isPerformingOwnEdit else { return }

        // 우리가 시킨 게 아닌 커서 이동(사용자가 텍스트의 다른 위치를 직접 탭하는
        // 경우 등) — 조합 중이던 위치가 더 이상 유효하지 않으므로 안전하게 버린다.
        viewModel.resetComposer()
    }

    /// KeyboardViewModelDelegate의 텍스트 편집 메서드(insertText/deleteBackward/
    /// updateComposingText/moveCursor)를 감싸서, 그로 인해 발생하는
    /// textDidChange/selectionDidChange가 "우리 자신의 편집"으로 인식되게 한다.
    private func performOwnEdit(_ body: () -> Void) {
        ownEditDepth += 1
        body()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.ownEditDepth = max(0, self.ownEditDepth - 1)
        }
    }
}

// MARK: - KeyboardViewModelDelegate
extension KeyboardViewController: KeyboardViewModelDelegate {
    func insertText(_ text: String) {
        performOwnEdit {
            textDocumentProxy.insertText(text)
        }
    }

    func deleteBackward() {
        performOwnEdit {
            textDocumentProxy.deleteBackward()
        }
    }

    func updateComposingText(from previous: String, to current: String) {
        // iOS keyboard extensions don't support marked text directly,
        // so we simulate it by deleting the previous composing text
        // and inserting the new composing text.
        performOwnEdit {
            // Delete previous composing characters
            for _ in previous {
                textDocumentProxy.deleteBackward()
            }

            // Insert new composing characters
            if !current.isEmpty {
                textDocumentProxy.insertText(current)
            }
        }
    }

    func switchToNextKeyboard() {
        advanceToNextInputMode()
    }

    func triggerHapticFeedback() {
        feedbackGenerator?.impactOccurred()
        feedbackGenerator?.prepare()
    }

    func moveCursor(byCharacterOffset offset: Int) {
        performOwnEdit {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
        }
    }

    func characterBeforeCursor() -> Character? {
        textDocumentProxy.documentContextBeforeInput?.last
    }
}
