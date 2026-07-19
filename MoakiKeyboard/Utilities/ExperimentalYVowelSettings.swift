import Foundation

/// Y계열(ㅑㅕㅛㅠ) 원점 복귀 인식기 — 검증용 실험 기능. 기본값은 OFF다.
/// 토글 자체는 `ios-moaki/ExperimentalYVowelSettingsView.swift`에서 켜고 끈다.
/// 앱 그룹 이름과 키 문자열은 그 파일과 반드시 동일하게 유지한다(키보드 익스텐션과
/// 호스트 앱은 별도 프로세스라 코드를 공유하지 못하고 이렇게 나뉘어 있다).
///
/// `appliedCount`/`conflictOverrideCount`는 A/B 비교를 위한 참고용 진단값일 뿐,
/// 정확도 지표가 아니다 — 실제 판정은 사용자가 직접 기록하는 의도/실제 결과 비교로 한다.
enum ExperimentalYVowelSettings {
    static let enabledKey = "experimentalYVowelEnabled"
    static let appliedCountKey = "experimentalYVowelAppliedCount"
    static let conflictOverrideCountKey = "experimentalYVowelConflictOverrideCount"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConstants.appGroupID)
    }

    static func isEnabled() -> Bool {
        defaults?.bool(forKey: enabledKey) ?? false
    }

    static func appliedCount() -> Int {
        defaults?.integer(forKey: appliedCountKey) ?? 0
    }

    static func conflictOverrideCount() -> Int {
        defaults?.integer(forKey: conflictOverrideCountKey) ?? 0
    }

    /// `handleKoreanModeGesture`(실제 입력 확정 지점)에서 제스처당 정확히 1회만 호출한다.
    /// `wasConflictOverride`는 기존 인식기 결과를 덮어썼을 때만 true.
    static func recordApplied(wasConflictOverride: Bool) {
        guard let defaults else { return }
        defaults.set(appliedCount() + 1, forKey: appliedCountKey)
        if wasConflictOverride {
            defaults.set(conflictOverrideCount() + 1, forKey: conflictOverrideCountKey)
        }
    }
}
