import XCTest

final class GestureSensitivitySettingsTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "test-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        if !suiteName.isEmpty {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }
        super.tearDown()
    }

    func testDefaultsToDefaultMultiplierWhenNoValueStored() {
        XCTAssertEqual(
            GestureSensitivitySettings.multiplier(defaults: defaults),
            CGFloat(GestureSensitivitySettings.defaultMultiplier)
        )
    }

    func testOutOfRangeValuesAreClampedToMultiplierRange() {
        defaults.set(0.3, forKey: GestureSensitivitySettings.multiplierKey)
        XCTAssertEqual(
            GestureSensitivitySettings.multiplier(defaults: defaults),
            CGFloat(GestureSensitivitySettings.multiplierRange.lowerBound)
        )

        defaults.set(2.0, forKey: GestureSensitivitySettings.multiplierKey)
        XCTAssertEqual(
            GestureSensitivitySettings.multiplier(defaults: defaults),
            CGFloat(GestureSensitivitySettings.multiplierRange.upperBound)
        )
    }

    func testInRangeValueIsReturnedUnchanged() {
        defaults.set(1.2, forKey: GestureSensitivitySettings.multiplierKey)
        XCTAssertEqual(GestureSensitivitySettings.multiplier(defaults: defaults), 1.2)
    }

    /// 호스트 앱(`ios-moaki/GestureSensitivitySettingsView.swift`)과 값이 반드시
    /// 같아야 하는 리터럴을 고정 문자열/범위와 대조한다 — 여태까지는 이 상수를
    /// 그대로 참조하는 테스트만 있어, 리터럴 값 자체가 실수로 바뀌어도 걸러내지
    /// 못했다.
    func testKeyAndRangeMatchExpectedLiteralValues() {
        XCTAssertEqual(GestureSensitivitySettings.multiplierKey, "gestureSensitivityMultiplier")
        XCTAssertEqual(GestureSensitivitySettings.multiplierRange, 0.7...1.5)
        XCTAssertEqual(GestureSensitivitySettings.defaultMultiplier, 1.0)
    }
}
