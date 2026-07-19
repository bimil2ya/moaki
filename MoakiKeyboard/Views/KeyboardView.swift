import SwiftUI
import Combine

struct KeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel

    var body: some View {
        GeometryReader { geometry in
            let centerKeyWidth = KeyboardMetrics.centerKeyWidth(for: geometry.size.width)
            let keyHeight = KeyboardMetrics.keyHeight(for: geometry.size.height)

            ZStack {
                VStack(spacing: KeyboardMetrics.keySpacing) {
                    // Key grid (consonants or symbols based on mode)
                    KeyGridView(
                        centerKeyWidth: centerKeyWidth,
                        keyHeight: keyHeight,
                        totalWidth: geometry.size.width,
                        isSymbolMode: viewModel.isSymbolMode,
                        activeKey: viewModel.activeKey,
                        // 드래그로 만들어질 모음을 미리 보여주는 건 도움이 안 된다는 판단하에
                        // 뺐다 — 방향 제스처가 진행 중(gestureDirections가 비어있지 않음)일 때는
                        // previewVowel을 안 보여주고, 천지인 스트로크 대기 중(방향 없이 대기
                        // 모음만 있는 경우)에는 그대로 보여준다.
                        previewVowel: viewModel.gestureDirections.isEmpty ? viewModel.previewVowel : nil,
                        onConsonantTap: { consonant in
                            viewModel.inputConsonant(consonant)
                        },
                        onSymbolTap: { symbol in
                            viewModel.inputSymbol(symbol)
                        },
                        onBackspacePressStart: {
                            viewModel.beginBackspacePress()
                        },
                        onBackspacePressEnd: {
                            viewModel.endBackspacePress()
                        },
                        onLongPressNumber: { number in
                            viewModel.inputLongPressNumber(number)
                        },
                        onGestureStart: { row, column, point in
                            viewModel.gestureStarted(row: row, column: column, at: point)
                        },
                        onGestureMove: { point in
                            viewModel.gestureMoved(to: point)
                        },
                        onGestureEnd: { row, column in
                            viewModel.gestureEnded(row: row, column: column)
                        },
                        onRequestAccessibilityVowelPicker: { consonant in
                            viewModel.showAccessibilityVowelPicker(for: consonant)
                        }
                    )

                    // Function row
                    FunctionRowView(
                        totalWidth: geometry.size.width,
                        isSymbolMode: viewModel.isSymbolMode,
                        onToggleModePressed: {
                            viewModel.toggleMode()
                        },
                        onSnippetsPressed: {
                            viewModel.showSnippetCandidates()
                        },
                        onHanjaPressed: {
                            viewModel.showHanjaCandidates()
                        },
                        onSpaceDragStart: { point in
                            viewModel.beginSpacePress(at: point)
                        },
                        onSpaceDragMove: { point in
                            viewModel.spacePressMoved(to: point)
                        },
                        onSpaceDragEnd: {
                            viewModel.endSpacePress()
                        },
                        onPunctuationPressed: {
                            viewModel.inputPunctuationCluster()
                        },
                        onReturnPressed: {
                            viewModel.inputReturn()
                        }
                    )
                }
                .padding(KeyboardMetrics.keySpacing)

                // 드래그 방향 화살표 + 예상 모음을 띄우는 건 실사용에 도움이 안 된다는
                // 판단하에 제거했다 — 실제로 입력됐는지는 텍스트 필드에서 확인하면 충분하고,
                // 드래그 자체가 인식되고 있다는 건 햅틱(gestureMoved 참고)과 키 눌림
                // 배경색 변화로만 알려준다. 천지인 스트로크 대기 모음 미리보기(방향 없이
                // previewVowel만 있는 경우)는 여러 탭을 조합하는 동안 꼭 필요해서 유지한다.
                let isCheonjiinPreview = viewModel.gestureDirections.isEmpty && viewModel.previewVowel != nil
                if isCheonjiinPreview && !viewModel.isSymbolMode {
                    GestureOverlayView(
                        startPoint: viewModel.gestureStartPoint,
                        pendingVowel: viewModel.previewVowel
                    )
                }

                // 한자 후보 바 (커서 앞 음절에 대응하는 한자가 있을 때만 상단에 표시)
                if !viewModel.hanjaCandidates.isEmpty {
                    VStack(spacing: 0) {
                        HanjaCandidateBar(
                            candidates: viewModel.hanjaCandidates,
                            onSelect: { candidate in
                                viewModel.selectHanjaCandidate(candidate)
                            }
                        )
                        Spacer()
                    }
                }

                // 문구 후보 바 ("문구" 버튼을 탭했을 때 등록해둔 문구가 있으면 상단에 표시)
                if !viewModel.snippetCandidates.isEmpty {
                    VStack(spacing: 0) {
                        SnippetCandidateBar(
                            snippets: viewModel.snippetCandidates,
                            onSelect: { snippet in
                                viewModel.selectSnippetCandidate(snippet)
                            }
                        )
                        Spacer()
                    }
                }

                // VoiceOver 접근성 모음 선택 바 (자음 키의 커스텀 액션으로 진입)
                if let consonant = viewModel.accessibilityVowelPickerConsonant {
                    VStack(spacing: 0) {
                        AccessibilityVowelPickerBar(
                            consonant: consonant,
                            onSelect: { vowel in
                                viewModel.selectAccessibilityVowel(vowel)
                            },
                            onCancel: {
                                viewModel.dismissAccessibilityVowelPicker()
                            }
                        )
                        Spacer()
                    }
                }
            }
            .background(Color(.systemGray6))
        }
    }
}

// ViewModel to handle keyboard logic
class KeyboardViewModel: ObservableObject {
    @Published var activeKey: (row: Int, column: Int)?
    @Published var previewVowel: Jungseong?
    @Published var gestureDirections: [GestureDirection] = []
    @Published var gestureStartPoint: CGPoint?
    @Published var isSymbolMode: Bool = false
    @Published var hanjaCandidates: [HanjaDictionary.Candidate] = []
    @Published var snippetCandidates: [String] = []
    /// VoiceOver 접근성 모음 선택 바가 표시 중이면 대상 자음, 아니면 nil.
    @Published var accessibilityVowelPickerConsonant: Choseong?

    private let composer = HangulComposer()
    private let gestureAnalyzer = GestureAnalyzer()
    private let vowelResolver = VowelResolver()
    private let cheonjiinResolver = CheonjiinResolver()

    private var punctuationCycleIndex = 0
    private let punctuationCycleValues = [".", ",", "?", "!"]

    private var spacePressStartPoint: CGPoint?
    private var isSpaceCursorMoveActive = false
    private var lastSpaceCursorMoveX: CGFloat = 0

    /// Tracks the last composing text to enable incremental updates
    private var lastComposingText: String = ""

    private let backspaceRepeatInitialDelay: TimeInterval
    private let backspaceRepeatInterval: TimeInterval
    private var isBackspacePressing = false
    private var backspaceInitialDelayTimer: Timer?
    private var backspaceRepeatTimer: Timer?
    private var didHandleLongPressNumberInCurrentGesture = false
    /// gestureMoved에서 새 방향 세그먼트가 등록될 때만 햅틱을 울리기 위한 카운터.
    private var lastHapticDirectionCount = 0

    /// 마지막 천지인 스트로크 이후 이 시간 동안 다음 스트로크가 없으면 대기 중인
    /// 모음을 자동으로 확정한다. 실제 천지인 키패드처럼, ㅏ(ㅣㆍ)나 ㅑ(ㅣㆍㆍ)처럼
    /// 서로 앞부분이 겹치는 모음을 시간차로 구분하기 위함이다.
    ///
    /// 이 값을 줄이면 단일 스트로크(ㅡ/ㅣ/ㆍ 단독)는 더 빨리 확정되어 반응이 즉각적으로
    /// 느껴지지만, 두 번째 스트로크(예: ㅡ 다음 ㆍ로 ㅜ를 만드는 조합)가 이 시간 안에
    /// 도착하지 못하면 첫 스트로크가 먼저 조급하게 확정되어 조합 자체가 깨진다(실제로
    /// 0.3초로 줄였다가 "ㄹ+ㅡ+ㆍ가 루가 아니라 르로 끊긴다"는 회귀가 발생해 0.45초로
    /// 되돌렸다). 이 값을 다시 조정할 때는 반드시 두 스트로크 조합(ㅡ+ㆍ=ㅜ, ㅣ+ㆍ=ㅏ 등)이
    /// 실기기에서 여전히 잘 되는지 확인할 것.
    private let cheonjiinAutoCommitDelay: TimeInterval
    private var cheonjiinAutoCommitTimer: Timer?

    /// Y계열(ㅑㅕㅛㅠ) 원점 복귀 인식기(실험적 기능) 토글. 실제 설정을 기본값으로 읽되,
    /// 테스트에서는 고정 클로저를 주입해 UserDefaults/앱그룹 없이 ON/OFF를 검증한다.
    private let experimentalYVowelEnabledProvider: () -> Bool
    /// 제스처 시작 시점에 한 번만 캐시한다 — 미리보기와 최종 확정이 서로 다른 시점에
    /// 토글을 다시 읽어 어긋나는 일이 없도록, 한 제스처 내내 이 값만 참조한다.
    private var isExperimentalYVowelEnabledForCurrentGesture = false

    weak var delegate: KeyboardViewModelDelegate?

    init(
        backspaceRepeatInitialDelay: TimeInterval = 0.4,
        backspaceRepeatInterval: TimeInterval = 0.08,
        cheonjiinAutoCommitDelay: TimeInterval = 0.45,
        experimentalYVowelEnabledProvider: @escaping () -> Bool = { ExperimentalYVowelSettings.isEnabled() }
    ) {
        self.backspaceRepeatInitialDelay = backspaceRepeatInitialDelay
        self.backspaceRepeatInterval = backspaceRepeatInterval
        self.cheonjiinAutoCommitDelay = cheonjiinAutoCommitDelay
        self.experimentalYVowelEnabledProvider = experimentalYVowelEnabledProvider
    }

    deinit {
        stopBackspaceRepeat()
        cheonjiinAutoCommitTimer?.invalidate()
    }

    var composingText: String {
        composer.displayText
    }

    // MARK: - Mode Toggle

    func toggleMode() {
        flushPendingCheonjiin()
        resetPunctuationCycle()
        dismissCandidateBars()
        stopBackspaceRepeat()
        commitCurrent()
        isSymbolMode.toggle()
        triggerHapticFeedback()
    }

    // MARK: - Input Methods

    func inputConsonant(_ consonant: Choseong) {
        flushPendingCheonjiin()
        resetPunctuationCycle()
        dismissCandidateBars()
        let action = composer.inputChoseong(consonant)
        handleComposerAction(action)
        triggerHapticFeedback()
    }

    func inputVowel(_ vowel: Jungseong) {
        let action = composer.inputJungseong(vowel)
        handleComposerAction(action)
        triggerHapticFeedback()
    }

    // MARK: - VoiceOver 접근성 모음 선택 (실험 없는 별도 입력 경로)

    /// 자음 키의 VoiceOver 커스텀 액션에서 호출된다. 오버레이(AccessibilityVowelPickerBar)를
    /// 띄우기만 하고, 실제 조합은 사용자가 모음을 고른 뒤 selectAccessibilityVowel에서 한다.
    func showAccessibilityVowelPicker(for consonant: Choseong) {
        dismissCandidateBars() // 한자/문구 바와 동시에 뜨지 않게 한다
        accessibilityVowelPickerConsonant = consonant
        triggerHapticFeedback()
    }

    /// 오버레이에서 모음을 골랐을 때 호출된다. 드래그 제스처를 전혀 거치지 않고 기존
    /// inputConsonant/inputVowel 경로를 그대로 재사용해 자음+모음을 조합한다 — 새 조합
    /// 로직을 만들지 않는다.
    func selectAccessibilityVowel(_ vowel: Jungseong) {
        guard let consonant = accessibilityVowelPickerConsonant else { return }
        accessibilityVowelPickerConsonant = nil
        inputConsonant(consonant)
        inputVowel(vowel)
    }

    func dismissAccessibilityVowelPicker() {
        accessibilityVowelPickerConsonant = nil
    }

    /// 천지인 ㅣㅡㆍ 스트로크 입력. 버퍼가 더 확장될 수 있으면 대기하고,
    /// 확장이 막혀 모음이 확정되면 기존 `inputVowel` 경로로 그대로 넘긴다.
    func inputCheonjiinStroke(_ stroke: CheonjiinStroke) {
        dismissCandidateBars()
        let committedVowel = cheonjiinResolver.input(stroke)
        cheonjiinAutoCommitTimer?.invalidate()
        cheonjiinAutoCommitTimer = nil

        if let committedVowel {
            resetPunctuationCycle()
            inputVowel(committedVowel)
        } else {
            triggerHapticFeedback()
        }

        // 확정 스트로크가 곧바로 새 버퍼를 시작시켰을 수도 있으므로(예: ㅑ를 확정시킨
        // ㅡ가 그대로 새 ㅡ 버퍼로 이어짐), 커밋 여부와 무관하게 현재 대기 상태를 다시 확인한다.
        if cheonjiinResolver.pendingVowel != nil {
            previewVowel = cheonjiinResolver.pendingVowel
            scheduleCheonjiinAutoCommit()
        } else {
            previewVowel = nil
            gestureStartPoint = nil
        }
    }

    private func scheduleCheonjiinAutoCommit() {
        cheonjiinAutoCommitTimer?.invalidate()
        cheonjiinAutoCommitTimer = makeTimer(interval: cheonjiinAutoCommitDelay, repeats: false) { [weak self] _ in
            self?.flushPendingCheonjiin()
        }
    }

    /// 우측 하단에 통합된 문장부호 키. 탭할 때마다 . , ? ! 순서로 순환 입력한다.
    func inputPunctuationCluster() {
        let symbol = punctuationCycleValues[punctuationCycleIndex]
        punctuationCycleIndex = (punctuationCycleIndex + 1) % punctuationCycleValues.count
        inputSymbol(symbol)
    }

    func inputSymbol(_ symbol: String) {
        flushPendingCheonjiin()
        dismissCandidateBars()
        commitCurrent()
        delegate?.insertText(symbol)
        triggerHapticFeedback()
    }

    func inputNumber(_ number: String) {
        flushPendingCheonjiin()
        resetPunctuationCycle()
        dismissCandidateBars()
        commitCurrent()
        delegate?.insertText(number)
        triggerHapticFeedback()
    }

    /// 자음 키 롱프레스로 확정된 값을 그대로 입력한다. 이름은 숫자 롱프레스에서
    /// 왔지만, ㅋㅌㅊㅍ의 사용자 지정 문구(`SnippetSettings`)도 같은 경로로 들어온다 —
    /// 둘 다 "롱프레스로 확정된 문자열을 그대로 삽입"이라는 동작이 동일하기 때문이다.
    func inputLongPressNumber(_ number: String) {
        didHandleLongPressNumberInCurrentGesture = true
        inputNumber(number)
    }

    func deleteBackward() {
        flushPendingCheonjiin()
        resetPunctuationCycle()
        dismissCandidateBars()
        let action = composer.deleteBackward()
        if action == .none {
            delegate?.deleteBackward()
        } else {
            handleComposerAction(action)
        }
        triggerHapticFeedback()
    }

    func inputSpace() {
        flushPendingCheonjiin()
        resetPunctuationCycle()
        dismissCandidateBars()
        commitAndInsert(" ")
        triggerHapticFeedback()
    }

    func inputReturn() {
        flushPendingCheonjiin()
        resetPunctuationCycle()
        dismissCandidateBars()
        commitAndInsert("\n")
        triggerHapticFeedback()
    }

    // MARK: - Space Bar Cursor Move (트랙패드)

    /// 스페이스 키를 누른 지점을 기록한다. 아직 스페이스를 입력하지도, 커서 이동
    /// 모드로 전환하지도 않는다 — 손가락이 실제로 움직여야 결정된다.
    func beginSpacePress(at point: CGPoint) {
        spacePressStartPoint = point
        isSpaceCursorMoveActive = false
    }

    /// 스페이스 키 위에서 손가락이 움직일 때마다 호출된다.
    /// 데드존을 넘는 순간 커서 이동 모드로 전환하고(조합 중이던 글자를 먼저 확정),
    /// 이후에는 이동 거리를 일정 간격으로 나눠 커서를 한 글자씩 옮긴다.
    func spacePressMoved(to point: CGPoint) {
        guard let start = spacePressStartPoint else { return }

        if !isSpaceCursorMoveActive {
            guard abs(point.x - start.x) >= KeyboardMetrics.spaceCursorMoveDeadzone else { return }
            isSpaceCursorMoveActive = true
            lastSpaceCursorMoveX = point.x
            // 커서를 옮기기 전에 조합/대기 중인 상태를 전부 확정해서,
            // 화면 밖에서 지우고-다시-쓰는 조합 시뮬레이션이 엉뚱한 위치를 건드리지 않게 한다.
            flushPendingCheonjiin()
            resetPunctuationCycle()
            dismissCandidateBars()
            commitCurrent()
            triggerHapticFeedback()
            return
        }

        var dx = point.x - lastSpaceCursorMoveX
        while abs(dx) >= KeyboardMetrics.spaceCursorMoveStep {
            let direction = dx > 0 ? 1 : -1
            delegate?.moveCursor(byCharacterOffset: direction)
            lastSpaceCursorMoveX += CGFloat(direction) * KeyboardMetrics.spaceCursorMoveStep
            dx = point.x - lastSpaceCursorMoveX
        }
    }

    /// 스페이스 키에서 손을 뗀다. 커서 이동 모드로 전환된 적이 없다면(단순 탭이었다면)
    /// 그제서야 스페이스를 입력한다.
    func endSpacePress() {
        let wasCursorMove = isSpaceCursorMoveActive
        spacePressStartPoint = nil
        isSpaceCursorMoveActive = false

        if !wasCursorMove {
            inputSpace()
        }
    }

    // MARK: - Hanja

    /// 한자 버튼을 탭했을 때 호출된다. 커서 바로 앞 글자를 확인해 후보를 찾는다.
    func showHanjaCandidates() {
        flushPendingCheonjiin()
        resetPunctuationCycle()
        commitCurrent()
        snippetCandidates = [] // 두 후보 바를 동시에 보여주지 않는다.

        guard let syllable = delegate?.characterBeforeCursor() else {
            hanjaCandidates = []
            return
        }

        let candidates = HanjaDictionary.shared.candidates(for: syllable)
        hanjaCandidates = candidates
        triggerHapticFeedback()
    }

    /// 후보 중 하나를 선택하면 커서 앞 음절을 지우고 그 자리에 한자를 넣는다.
    func selectHanjaCandidate(_ candidate: HanjaDictionary.Candidate) {
        hanjaCandidates = []
        delegate?.deleteBackward()
        delegate?.insertText(String(candidate.hanja))
        triggerHapticFeedback()
    }

    // MARK: - Snippets

    /// "문구" 버튼을 탭했을 때 호출된다. 등록해둔 문구 전체를 후보로 보여준다.
    func showSnippetCandidates() {
        flushPendingCheonjiin()
        resetPunctuationCycle()
        commitCurrent()
        hanjaCandidates = [] // 두 후보 바를 동시에 보여주지 않는다.

        snippetCandidates = SnippetSettings.allSnippets()
        triggerHapticFeedback()
    }

    /// 후보 중 하나를 선택하면 그 문구를 커서 위치에 그대로 삽입한다.
    func selectSnippetCandidate(_ text: String) {
        snippetCandidates = []
        commitCurrent()
        delegate?.insertText(text)
        triggerHapticFeedback()
    }

    private func dismissCandidateBars() {
        hanjaCandidates = []
        snippetCandidates = []
        accessibilityVowelPickerConsonant = nil
    }

    func beginBackspacePress() {
        guard !isBackspacePressing else { return }

        isBackspacePressing = true
        deleteBackward()  // Immediate delete on touch-down.
        startBackspaceRepeat()
    }

    func endBackspacePress() {
        stopBackspaceRepeat()
    }

    // MARK: - Gesture Handling

    func gestureStarted(row: Int, column: Int, at point: CGPoint) {
        didHandleLongPressNumberInCurrentGesture = false
        activeKey = (row, column)
        gestureStartPoint = point
        gestureAnalyzer.reset()
        gestureAnalyzer.addPoint(point)
        gestureDirections = []
        previewVowel = nil
        lastHapticDirectionCount = 0
        isExperimentalYVowelEnabledForCurrentGesture = experimentalYVowelEnabledProvider()
    }

    func gestureMoved(to point: CGPoint) {
        gestureAnalyzer.addPoint(point)
        let directions = gestureAnalyzer.getDirections()
        gestureDirections = directions

        // 방향이 새로 하나 등록될 때마다 햅틱으로만 "인식됐다"는 걸 알려준다.
        // 어떤 모음이 될지는 보여주지 않는다 — 실제 결과는 텍스트 필드에서 확인.
        if directions.count > lastHapticDirectionCount {
            lastHapticDirectionCount = directions.count
            triggerHapticFeedback()
        }

        // Update preview vowel (only meaningful for consonant keys)
        previewVowel = experimentalOverriddenPreviewVowel(existingPreview: vowelResolver.peekVowel(directions: directions))
    }

    /// 토글이 켜져 있고 Y계열 후보가 확정됐으면 그 값으로 미리보기를 덮어쓴다.
    /// 드래그 중 여러 번 호출되므로 부작용(카운터·로그)은 절대 여기 두지 않는다.
    private func experimentalOverriddenPreviewVowel(existingPreview: Jungseong?) -> Jungseong? {
        guard isExperimentalYVowelEnabledForCurrentGesture,
              let confirmed = gestureAnalyzer.confirmedYVowel else {
            return existingPreview
        }
        return confirmed
    }

    func gestureEnded(row: Int, column: Int) {
        if didHandleLongPressNumberInCurrentGesture {
            didHandleLongPressNumberInCurrentGesture = false
            resetGestureState()
            return
        }

        // In symbol mode, gesture handling is simpler - just tap
        if isSymbolMode {
            handleSymbolModeTap(row: row, column: column)
        } else {
            handleKoreanModeGesture(row: row, column: column)
        }

        resetGestureState()
    }

    private func handleSymbolModeTap(row: Int, column: Int) {
        guard let content = KeyboardMetrics.keyContent(at: row, column: column, isSymbolMode: true) else { return }

        switch content {
        case .symbol(let symbol):
            inputSymbol(symbol)
        case .backspace:
            deleteBackward()
        case .consonant, .cheonjiinStroke:
            break // Should not happen in symbol mode
        }
    }

    private func handleKoreanModeGesture(row: Int, column: Int) {
        let directions = gestureAnalyzer.finalizeGesture()

        guard let content = KeyboardMetrics.keyContent(at: row, column: column, isSymbolMode: false) else { return }

        switch content {
        case .consonant(let consonant):
            if directions.isEmpty {
                // No gesture - treat as tap
                inputConsonant(consonant)
            } else {
                // Gesture completed - input consonant + vowel
                inputConsonant(consonant)

                let resolution = vowelResolver.resolve(directions: directions)
                let decision = finalYVowelDecision(existingResolution: resolution.vowel)
                if decision.wasExperimentalApplied {
                    // 실제 입력이 확정되는 이 지점에서만, 제스처당 정확히 1회 기록한다.
                    #if DEBUG
                    if decision.wasConflictOverride {
                        print("[ExperimentalYVowel] 충돌 발생 — 기존: \(String(describing: resolution.vowel)), 신규: \(String(describing: decision.vowel))")
                    }
                    #endif
                    ExperimentalYVowelSettings.recordApplied(wasConflictOverride: decision.wasConflictOverride)
                }
                if let vowel = decision.vowel {
                    inputVowel(vowel)
                }
            }

        case .symbol(let symbol):
            inputSymbol(symbol)

        case .backspace:
            deleteBackward()

        case .cheonjiinStroke(let stroke):
            inputCheonjiinStroke(stroke)
        }
    }

    // MARK: - Y계열(ㅑㅕㅛㅠ) 원점 복귀 인식기 — 최종 결정 (실험적 기능)

    private struct YVowelDecision {
        let vowel: Jungseong?
        let wasExperimentalApplied: Bool
        let wasConflictOverride: Bool
    }

    /// 부작용 없는 순수 함수 — 카운터·로그 기록은 호출부(`handleKoreanModeGesture`,
    /// 제스처당 정확히 1회 호출됨)에서만 한다. 이렇게 분리해두면 이 함수 자체가
    /// 나중에 여러 번 호출되더라도(예: 테스트, 추측 실행) 조용히 중복 집계되는 일이 없다.
    private func finalYVowelDecision(existingResolution: Jungseong?) -> YVowelDecision {
        guard isExperimentalYVowelEnabledForCurrentGesture,
              let confirmed = gestureAnalyzer.confirmedYVowel else {
            return YVowelDecision(vowel: existingResolution, wasExperimentalApplied: false, wasConflictOverride: false)
        }
        return YVowelDecision(
            vowel: confirmed,
            wasExperimentalApplied: true,
            wasConflictOverride: confirmed != existingResolution
        )
    }

    // MARK: - Public State Reset (for external text field changes)

    func resetComposer() {
        // Reset composer state when text field changes externally
        // (e.g., when user sends a message and the app clears the field)
        stopBackspaceRepeat()
        cheonjiinAutoCommitTimer?.invalidate()
        cheonjiinAutoCommitTimer = nil
        lastComposingText = ""
        composer.reset()
        cheonjiinResolver.reset()
        previewVowel = nil
        resetPunctuationCycle()
        dismissCandidateBars()
    }

    /// Resets gesture tracking state only. Intentionally does NOT reset composer
    /// or lastComposingText to preserve in-progress Hangul composition.
    func resetGestureState() {
        stopBackspaceRepeat()
        didHandleLongPressNumberInCurrentGesture = false
        activeKey = nil
        gestureDirections = []
        // 천지인 버퍼가 아직 대기 중이면(손을 뗀 뒤에도 다음 스트로크를 기다리는 중),
        // 미리보기와 그 위치 기준점을 지우지 않고 유지해서 탭 사이에도 계속 보이게 한다.
        if cheonjiinResolver.pendingVowel == nil {
            gestureStartPoint = nil
            previewVowel = nil
        }
        gestureAnalyzer.reset()
        // 정상 종료뿐 아니라 키보드 전환·뷰 소멸·시스템 제스처 취소 등 이 catch-all
        // 리셋 경로를 거치는 모든 경우에, 실험 토글 캐시도 함께 정리해서 취소된
        // 제스처의 잔여 상태가 다음 제스처로 새지 않게 한다.
        isExperimentalYVowelEnabledForCurrentGesture = false
    }

    // MARK: - Private Helpers

    /// 천지인 버퍼에 확정 대기 중인 모음이 있으면 확정해서 흘려보낸다.
    /// 천지인 스트로크가 아닌 다른 입력(자음, 기호, 삭제, 스페이스 등)이 들어오기
    /// 직전에 호출해서, 미완성 상태로 남은 모음이 유실되지 않게 한다.
    private func flushPendingCheonjiin() {
        cheonjiinAutoCommitTimer?.invalidate()
        cheonjiinAutoCommitTimer = nil
        if let vowel = cheonjiinResolver.flush() {
            previewVowel = nil
            gestureStartPoint = nil
            inputVowel(vowel)
        }
    }

    private func resetPunctuationCycle() {
        punctuationCycleIndex = 0
    }

    private func handleComposerAction(_ action: HangulComposer.ComposerAction) {
        switch action {
        case .none:
            break
        case .update:
            updateComposingText()
        case .commit, .commitAndUpdate, .commitAndCommit:
            let committed = composer.flushCommittedText()

            // 1. First, delete the composing text currently on screen
            for _ in lastComposingText {
                delegate?.deleteBackward()
            }
            lastComposingText = ""

            // 2. Insert the committed text
            if !committed.isEmpty {
                delegate?.insertText(committed)
            }

            // 3. Update with the new composing character (if any)
            updateComposingText()
        case .delete:
            // If there's composing text, delete it; otherwise pass through to delegate
            if !lastComposingText.isEmpty {
                // Clear the composing text from screen
                for _ in lastComposingText {
                    delegate?.deleteBackward()
                }
                lastComposingText = ""
            } else {
                delegate?.deleteBackward()
            }
            updateComposingText()
        }
    }

    private func updateComposingText() {
        let composing = composer.currentComposingCharacter.map { String($0) } ?? ""
        let previous = lastComposingText
        lastComposingText = composing
        delegate?.updateComposingText(from: previous, to: composing)
    }

    private func commitCurrent() {
        // The composing character is already on screen, so just reset state
        // without inserting it again
        lastComposingText = ""
        composer.reset()
    }

    private func commitAndInsert(_ text: String) {
        commitCurrent()
        delegate?.insertText(text)
    }

    private func triggerHapticFeedback() {
        delegate?.triggerHapticFeedback()
    }

    private func startBackspaceRepeat() {
        backspaceInitialDelayTimer?.invalidate()
        backspaceInitialDelayTimer = makeTimer(interval: backspaceRepeatInitialDelay, repeats: false) { [weak self] _ in
            guard let self, self.isBackspacePressing else { return }

            self.backspaceRepeatTimer?.invalidate()
            self.backspaceRepeatTimer = self.makeTimer(interval: self.backspaceRepeatInterval, repeats: true) { [weak self] _ in
                guard let self, self.isBackspacePressing else { return }
                self.deleteBackward()
            }
        }
    }

    private func stopBackspaceRepeat() {
        isBackspacePressing = false
        backspaceInitialDelayTimer?.invalidate()
        backspaceInitialDelayTimer = nil
        backspaceRepeatTimer?.invalidate()
        backspaceRepeatTimer = nil
    }

    private func makeTimer(interval: TimeInterval, repeats: Bool, handler: @escaping (Timer) -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats, block: handler)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}

protocol KeyboardViewModelDelegate: AnyObject {
    func insertText(_ text: String)
    func deleteBackward()
    func updateComposingText(from previous: String, to current: String)
    func switchToNextKeyboard()
    func triggerHapticFeedback()
    func moveCursor(byCharacterOffset offset: Int)
    func characterBeforeCursor() -> Character?
}

#Preview {
    KeyboardView(viewModel: KeyboardViewModel())
        .frame(height: 280)
}
