import XCTest

/// 키보드 측 값 회귀 방지 테스트.
/// `ios-moaki/AppGroupConstants.swift`에도 같은 이름의 파일이 별도로 존재하지만,
/// 이 테스트 타깃은 키보드 소스만 직접 컴파일하는 구조라 호스트 앱 쪽 파일을 볼 수
/// 없다 — 즉 이 테스트는 두 타깃 간 값 일치를 보장하지 않고, 키보드 측 값 자체가
/// 의도한 문자열에서 벗어나지 않는지만 확인한다.
final class AppGroupConstantsTests: XCTestCase {
    func testAppGroupIDMatchesExpectedString() {
        XCTAssertEqual(AppGroupConstants.appGroupID, "group.dev.nohkyeongho.moaki")
    }

    /// `ios-moaki/ExperimentalYVowelSettingsView.swift`와 반드시 동일하게 유지해야 하는
    /// 키 문자열들의 키보드 측 회귀 방지 테스트(두 타깃 간 일치를 보장하지는 않음).
    func testExperimentalYVowelSettingsKeysMatchExpectedStrings() {
        XCTAssertEqual(ExperimentalYVowelSettings.enabledKey, "experimentalYVowelEnabled")
        XCTAssertEqual(ExperimentalYVowelSettings.appliedCountKey, "experimentalYVowelAppliedCount")
        XCTAssertEqual(ExperimentalYVowelSettings.conflictOverrideCountKey, "experimentalYVowelConflictOverrideCount")
    }

    func testExperimentalYVowelDefaultsToDisabledAndZeroCounts() {
        // 이 테스트는 앱그룹 UserDefaults suite에 값이 없는 초기 상태를 가정한다.
        // 실제 값이 저장돼 있었다면 isEnabled()/count는 그 값을 그대로 반영하므로,
        // 여기서는 "키가 없을 때 기본값"이라는 기본 계약만 별도로 확인한다.
        let suite = UserDefaults(suiteName: AppGroupConstants.appGroupID)
        let previousEnabled = suite?.object(forKey: ExperimentalYVowelSettings.enabledKey)
        let previousApplied = suite?.object(forKey: ExperimentalYVowelSettings.appliedCountKey)
        let previousConflict = suite?.object(forKey: ExperimentalYVowelSettings.conflictOverrideCountKey)
        defer {
            suite?.set(previousEnabled, forKey: ExperimentalYVowelSettings.enabledKey)
            suite?.set(previousApplied, forKey: ExperimentalYVowelSettings.appliedCountKey)
            suite?.set(previousConflict, forKey: ExperimentalYVowelSettings.conflictOverrideCountKey)
        }

        suite?.removeObject(forKey: ExperimentalYVowelSettings.enabledKey)
        suite?.removeObject(forKey: ExperimentalYVowelSettings.appliedCountKey)
        suite?.removeObject(forKey: ExperimentalYVowelSettings.conflictOverrideCountKey)

        XCTAssertFalse(ExperimentalYVowelSettings.isEnabled())
        XCTAssertEqual(ExperimentalYVowelSettings.appliedCount(), 0)
        XCTAssertEqual(ExperimentalYVowelSettings.conflictOverrideCount(), 0)
    }
}
