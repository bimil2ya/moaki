import Foundation

/// 제스처 인식 거리(threshold)에 곱해지는 배율을 앱 그룹 공유 UserDefaults에서 읽는다.
/// 손 크기·화면 크기·타이핑 습관이 사람마다 달라서, 한 값으로 모두를 만족시킬 수
/// 없다는 게 확인된 문제(업스트림 vkehfdl1/ios-moaki 프로젝트 issue #23 참고)라
/// 사용자가 직접 조절할 수 있게 노출한다. 배율은 ios-moaki 앱의 설정 화면
/// (`GestureSensitivitySettingsView`)에서 편집한다. 앱 그룹 이름과 키 문자열은
/// 그 파일과 반드시 동일하게 유지한다.
enum GestureSensitivitySettings {
    static let appGroupID = AppGroupConstants.appGroupID
    static let multiplierKey = "gestureSensitivityMultiplier"

    /// 배율이 이 범위를 벗어나면 제스처가 사실상 안 먹히거나 너무 예민해지므로 clamp한다.
    static let multiplierRange: ClosedRange<Double> = 0.7...1.5

    static let defaultMultiplier: Double = 1.0

    static func multiplier() -> CGFloat {
        multiplier(defaults: UserDefaults(suiteName: appGroupID))
    }

    static func multiplier(defaults: UserDefaults?) -> CGFloat {
        let stored = defaults?.object(forKey: multiplierKey) as? Double
        let value = stored ?? defaultMultiplier
        return CGFloat(value.clamped(to: multiplierRange))
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
