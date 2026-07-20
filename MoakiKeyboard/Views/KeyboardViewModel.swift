import Combine
import CoreGraphics
import Foundation

// ViewModel to handle keyboard logic
@MainActor
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
    /// 실험 카운터 기록. 실제 저장을 기본값으로 하되, 테스트에서는 임시 suite로
    /// 리디렉션해 실제 App Group을 건드리지 않게 한다.
    private let experimentalYVowelRecorder: (Bool) -> Void
    /// 제스처 시작 시점에 한 번만 캐시한다 — 미리보기와 최종 확정이 서로 다른 시점에
    /// 토글을 다시 읽어 어긋나는 일이 없도록, 한 제스처 내내 이 값만 참조한다.
    private var isExperimentalYVowelEnabledForCurrentGesture = false

    /// "문구" 버튼 후보 목록 조회. 실제 설정을 기본값으로 읽되, 테스트에서는 고정
    /// 클로저를 주입해 UserDefaults/앱그룹 없이 후보 배열 상호정리 로직을 검증한다.
    private let snippetsProvider: () -> [String]

    /// 드래그(또는 접근성 모음 선택)로 기본 모음(ㅏㅓㅗㅜ)이 막 확정됐을 때만 설정된다.
    /// 다음 입력이 정확히 천지인 "점"이면 이 값을 소비해 모음을 Y계열로 바꾸고, 그 외의
    /// 어떤 입력이 오든 즉시 무효화된다. choseong까지 함께 저장해, 소비 시점에 조합기의
    /// 실제 상태와 정확히 일치하는지 엔진 레벨에서 재확인할 수 있게 한다(방어 심화).
    /// cheonjiinResolver.pendingVowel(천지인 자체의 대기 모음)과는 완전히 별개의 상태다.
    private struct DirectVowelExtension {
        let choseong: Choseong
        let jungseong: Jungseong
    }
    private var pendingDirectVowelExtension: DirectVowelExtension?

    private static let dotVowelExtension: [Jungseong: Jungseong] = [
        .ㅏ: .ㅑ, .ㅓ: .ㅕ, .ㅗ: .ㅛ, .ㅜ: .ㅠ,
    ]

    /// ㅃㅂㅁㅋ(왼쪽 끝 자음 열, column 1)에서 위로 드래그하면 손동작이 화면 중앙(오른쪽)으로
    /// 휘어져 ㅗ/ㅛ가 ㅣ로 잘못 인식되는 문제가 실기기에서 보고됐다. 이 열에서 시작한
    /// 제스처에 한해 up 섹터 경계를 넓혀 보정한다. down 계열 분류나 다른 열에는
    /// 전혀 영향이 없다. 실기기 테스트로 부족/과함이 확인되면 이 값만 조정할 것.
    private static let leftEdgeColumnUpSectorExpansionDegrees: CGFloat = 20

    weak var delegate: KeyboardViewModelDelegate?

    init(
        backspaceRepeatInitialDelay: TimeInterval = 0.4,
        backspaceRepeatInterval: TimeInterval = 0.08,
        cheonjiinAutoCommitDelay: TimeInterval = 0.45,
        experimentalYVowelEnabledProvider: @escaping () -> Bool = { ExperimentalYVowelSettings.isEnabled() },
        experimentalYVowelRecorder: @escaping (Bool) -> Void = { ExperimentalYVowelSettings.recordApplied(wasConflictOverride: $0) },
        snippetsProvider: @escaping () -> [String] = { SnippetSettings.allSnippets() }
    ) {
        self.backspaceRepeatInitialDelay = backspaceRepeatInitialDelay
        self.backspaceRepeatInterval = backspaceRepeatInterval
        self.cheonjiinAutoCommitDelay = cheonjiinAutoCommitDelay
        self.experimentalYVowelEnabledProvider = experimentalYVowelEnabledProvider
        self.experimentalYVowelRecorder = experimentalYVowelRecorder
        self.snippetsProvider = snippetsProvider
    }

    deinit {
        // deinit은 Swift에서 항상 nonisolated로 취급되어 @MainActor 격리 메서드인
        // stopBackspaceRepeat()를 호출할 수 없다 — 그 본문을 그대로 인라인한다
        // (Timer.invalidate()는 액터 격리와 무관한 Foundation API라 문제없다).
        backspaceInitialDelayTimer?.invalidate()
        backspaceRepeatTimer?.invalidate()
        cheonjiinAutoCommitTimer?.invalidate()
    }

    var composingText: String {
        composer.displayText
    }

    // MARK: - Mode Toggle

    func toggleMode() {
        prepareForRegularInputAction()
        stopBackspaceRepeat()
        commitCurrent()
        isSymbolMode.toggle()
        triggerHapticFeedback()
    }

    /// 다음 키보드로 전환한다(지구본 버튼). `needsInputModeSwitchKey`로 조건부 표시하지
    /// 않고 항상 노출한다 — 이 프로퍼티는 호스트 연결 이전에 읽으면 부정확하고, 기기·iOS
    /// 버전에 따라 생명주기 도중 값이 바뀐 사례도 보고되어 있어 안전하게 전환 수단이
    /// 안 보이는 상황을 만들 수 있다. 전환할 다른 키보드가 없으면 delegate 호출은
    /// 안전하게 아무 일도 하지 않는다. 대기 중이던 조합 상태 정리는 이 뷰가 사라질 때
    /// 호출되는 flushPendingStateBeforeDisappearing()이 이미 담당하므로 여기서는
    /// 중복으로 처리하지 않는다.
    func switchToNextKeyboard() {
        triggerHapticFeedback()
        delegate?.switchToNextKeyboard()
    }

    // MARK: - Input Methods

    func inputConsonant(_ consonant: Choseong) {
        prepareForRegularInputAction()
        let action = composer.inputChoseong(consonant)
        handleComposerAction(action)
        triggerHapticFeedback()
    }

    func inputVowel(_ vowel: Jungseong) {
        let action = composer.inputJungseong(vowel)
        handleComposerAction(action)
        triggerHapticFeedback()
    }

    /// 드래그·접근성 경로에서 방금 입력한 vowel이 하→햐류 단축 확장 대상인지 확인해
    /// 대기 상태를 건다. vowel 인자만 보고 걸지 않고, 조합기가 실제로 지금 이 모음을
    /// 가진 .choseongJungseong 상태인지 재확인한 뒤에만 건다 — 호출 경로가 나중에
    /// 늘어나거나 바뀌어도 엉뚱한 모음에 잘못 대기가 걸리는 일이 없도록 하기 위함이다.
    /// inputVowel(_:) 내부에는 넣지 않는다 — 그 함수는 천지인 자동확정·다중스트로크
    /// 확정에서도 호출되므로, 내부에 넣으면 천지인 자체 흐름까지 잘못 대기 상태에 걸린다.
    private func armDirectVowelExtensionIfEligible(_ vowel: Jungseong) {
        guard Self.dotVowelExtension[vowel] != nil,
              case .choseongJungseong(let choseong, let currentVowel) = composer.state,
              currentVowel == vowel else {
            pendingDirectVowelExtension = nil
            return
        }
        pendingDirectVowelExtension = DirectVowelExtension(choseong: choseong, jungseong: vowel)
    }

    /// 대기 중인 단축 확장을 소비한다. 성공하면 CheonjiinResolver는 전혀 건드리지 않고
    /// true를 반환한다.
    private func tryExtendPendingVowel() -> Bool {
        guard let pending = pendingDirectVowelExtension,
              let extended = Self.dotVowelExtension[pending.jungseong],
              let action = composer.replaceCurrentSyllableVowel(
                  expectedChoseong: pending.choseong,
                  expectedJungseong: pending.jungseong,
                  with: extended
              ) else {
            return false
        }
        pendingDirectVowelExtension = nil
        handleComposerAction(action)
        triggerHapticFeedback()
        return true
    }

    // MARK: - VoiceOver 접근성 모음 선택 (실험 없는 별도 입력 경로)

    /// 자음 키의 VoiceOver 커스텀 액션에서 호출된다. 오버레이(AccessibilityVowelPickerBar)를
    /// 띄우기만 하고, 실제 조합은 사용자가 모음을 고른 뒤 selectAccessibilityVowel에서 한다.
    func showAccessibilityVowelPicker(for consonant: Choseong) {
        dismissCandidateBars() // 한자/문구 바와 동시에 뜨지 않게 한다
        pendingDirectVowelExtension = nil
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
        armDirectVowelExtensionIfEligible(vowel)
    }

    func dismissAccessibilityVowelPicker() {
        accessibilityVowelPickerConsonant = nil
    }

    /// 천지인 ㅣㅡㆍ 스트로크 입력. 버퍼가 더 확장될 수 있으면 대기하고,
    /// 확장이 막혀 모음이 확정되면 기존 `inputVowel` 경로로 그대로 넘긴다.
    func inputCheonjiinStroke(_ stroke: CheonjiinStroke) {
        dismissCandidateBars()

        if stroke == .dot, tryExtendPendingVowel() {
            return  // 확장 성공 — CheonjiinResolver는 전혀 건드리지 않는다
        }
        pendingDirectVowelExtension = nil  // 점이 아니었거나 확장 실패 — 기회 소멸

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

    /// 동일한 정리 패턴을 가진 일반 입력 경로 중 이 함수만 `resetPunctuationCycle()`을
    /// 의도적으로 뺀다 — `inputPunctuationCluster()`가 인덱스를 미리 증가시킨 뒤 이
    /// 함수를 호출하는 구조라, 여기서 순환을 리셋하면 문장부호 순환(.→,→?→!)이 매번
    /// 첫 기호에 고정되어버린다. 그래서 `prepareForRegularInputAction()`을 쓰지 않는다.
    func inputSymbol(_ symbol: String) {
        flushPendingCheonjiin()
        dismissCandidateBars()
        commitCurrent()
        delegate?.insertText(symbol)
        triggerHapticFeedback()
    }

    func inputNumber(_ number: String) {
        prepareForRegularInputAction()
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
        prepareForRegularInputAction()
        let action = composer.deleteBackward()
        if action == .none {
            delegate?.deleteBackward()
        } else {
            handleComposerAction(action)
        }
        triggerHapticFeedback()
    }

    func inputSpace() {
        prepareForRegularInputAction()
        commitAndInsert(" ")
        triggerHapticFeedback()
    }

    func inputReturn() {
        prepareForRegularInputAction()
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
            prepareForRegularInputAction()
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
        dismissCandidateBars() // 세 오버레이(한자/문구/접근성 피커)를 모두 정리해 상호 배타를 보장한다.

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
        dismissCandidateBars() // 세 오버레이(한자/문구/접근성 피커)를 모두 정리해 상호 배타를 보장한다.

        snippetCandidates = snippetsProvider()
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

    /// 정규 입력 동작을 시작하기 전 공통 정리: 천지인 대기 확정, 문장부호 순환 리셋,
    /// 후보 바 닫기. 동일한 정리 패턴(flush→resetPunct→dismiss 순서)을 가진 일반
    /// 입력 경로에서만 쓴다 — showHanjaCandidates/showSnippetCandidates는 commit이
    /// dismiss보다 먼저 와야 해서 이 헬퍼를 쓰지 않고, inputSymbol은 문장부호 순환을
    /// 보존해야 해서 쓰지 않는다(각 함수 옆 주석 참고).
    private func prepareForRegularInputAction() {
        flushPendingCheonjiin()
        resetPunctuationCycle()
        dismissCandidateBars()
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
        gestureAnalyzer.reset(upSectorExpansionDegrees: column == 1 ? Self.leftEdgeColumnUpSectorExpansionDegrees : 0)
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
                    experimentalYVowelRecorder(decision.wasConflictOverride)
                }
                if let vowel = decision.vowel {
                    inputVowel(vowel)
                    armDirectVowelExtensionIfEligible(vowel)
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
        pendingDirectVowelExtension = nil
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

    /// 키보드 확장 뷰가 화면에서 사라지기 직전(다른 키보드로 전환, 앱 백그라운드
    /// 전환 등)에 호출된다. 천지인 조합 대기 중인 모음이 있으면 자음/기호 입력 등
    /// 다른 전환 시점과 동일한 원칙으로 확정해서 조용히 버리지 않는다 — 이렇게
    /// 안 하면 최대 0.45초짜리 자동확정 타이머가 뷰가 사라진 뒤에도 계속 살아있다가
    /// 나중에 엉뚱한 시점(다른 앱으로 전환된 뒤 등)에 입력을 실행할 수 있다.
    func flushPendingStateBeforeDisappearing() {
        flushPendingCheonjiin()
        resetGestureState()
    }

    // MARK: - Private Helpers

    /// 천지인 버퍼에 확정 대기 중인 모음이 있으면 확정해서 흘려보낸다.
    /// 천지인 스트로크가 아닌 다른 입력(자음, 기호, 삭제, 스페이스 등)이 들어오기
    /// 직전에 호출해서, 미완성 상태로 남은 모음이 유실되지 않게 한다.
    private func flushPendingCheonjiin() {
        pendingDirectVowelExtension = nil
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
