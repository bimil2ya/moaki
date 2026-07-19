import Foundation
import Combine

class KeyboardSettings: ObservableObject {
    static let shared = KeyboardSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let showGesturePreview = "showGesturePreview"
    }

    /// 제스처 프리뷰 표시 여부 (기본값: true — 손을 떼기 전에 인식된 모음을 미리
    /// 보여줘야 사용자가 궤적을 스스로 고칠 수 있어, 커브/훅 모양으로 인한
    /// 오인식을 사용자 쪽에서도 줄일 수 있다)
    @Published var showGesturePreview: Bool {
        didSet {
            defaults.set(showGesturePreview, forKey: Keys.showGesturePreview)
        }
    }

    private init() {
        // 기본값 등록
        defaults.register(defaults: [
            Keys.showGesturePreview: true
        ])

        // 저장된 값 로드
        self.showGesturePreview = defaults.bool(forKey: Keys.showGesturePreview)
    }
}
