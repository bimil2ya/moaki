import XCTest

final class ExperimentalYVowelSettingsTests: XCTestCase {
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

    func testIsEnabledDefaultsToFalse() {
        XCTAssertFalse(ExperimentalYVowelSettings.isEnabled(defaults: defaults))
    }

    func testIsEnabledRoundTripsStoredValue() {
        defaults.set(true, forKey: ExperimentalYVowelSettings.enabledKey)
        XCTAssertTrue(ExperimentalYVowelSettings.isEnabled(defaults: defaults))
    }

    func testRecordAppliedAccumulatesCountsAcrossCalls() {
        ExperimentalYVowelSettings.recordApplied(wasConflictOverride: false, defaults: defaults)
        ExperimentalYVowelSettings.recordApplied(wasConflictOverride: true, defaults: defaults)

        XCTAssertEqual(ExperimentalYVowelSettings.appliedCount(defaults: defaults), 2)
        XCTAssertEqual(ExperimentalYVowelSettings.conflictOverrideCount(defaults: defaults), 1)
    }
}
