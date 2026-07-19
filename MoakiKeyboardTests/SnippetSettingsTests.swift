import XCTest

final class SnippetSettingsTests: XCTestCase {
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

    // MARK: - userDefaultsKey(for:) (순수 함수, 주입 불필요)

    func testUserDefaultsKeyForRegisteredConsonants() {
        XCTAssertEqual(SnippetSettings.userDefaultsKey(for: .ㅋ), "snippet.ㅋ")
        XCTAssertEqual(SnippetSettings.userDefaultsKey(for: .ㅌ), "snippet.ㅌ")
        XCTAssertEqual(SnippetSettings.userDefaultsKey(for: .ㅊ), "snippet.ㅊ")
        XCTAssertEqual(SnippetSettings.userDefaultsKey(for: .ㅍ), "snippet.ㅍ")
    }

    func testUserDefaultsKeyForOtherConsonantIsNil() {
        XCTAssertNil(SnippetSettings.userDefaultsKey(for: .ㄱ))
    }

    // MARK: - snippet(for:defaults:)

    func testSnippetTreatsEmptyStringAsNil() {
        defaults.set("", forKey: "snippet.ㅋ")
        XCTAssertNil(SnippetSettings.snippet(for: .ㅋ, defaults: defaults))
    }

    // MARK: - allSnippets(defaults:)

    func testAllSnippetsCombinesConsonantAndExtraSnippetsInOrder() {
        defaults.set("커피", forKey: "snippet.ㅋ")
        defaults.set("택배", forKey: "snippet.ㅌ")
        defaults.set(["안녕하세요", "감사합니다"], forKey: SnippetSettings.extraSnippetsKey)

        XCTAssertEqual(
            SnippetSettings.allSnippets(defaults: defaults),
            ["커피", "택배", "안녕하세요", "감사합니다"]
        )
    }

    func testExtraSnippetsFiltersOutEmptyStringEntries() {
        defaults.set(["안녕하세요", "", "감사합니다"], forKey: SnippetSettings.extraSnippetsKey)
        XCTAssertEqual(SnippetSettings.extraSnippets(defaults: defaults), ["안녕하세요", "감사합니다"])
    }
}
