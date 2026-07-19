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
}
