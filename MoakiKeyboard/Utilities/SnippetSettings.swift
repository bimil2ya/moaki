import Foundation

/// ㅋㅌㅊㅍ 롱프레스로 삽입할 사용자 지정 문구를 앱 그룹 공유 UserDefaults에서 읽는다.
/// 문구 자체는 ios-moaki 앱의 설정 화면(`SnippetSettingsView`)에서 편집한다.
/// 앱 그룹 이름과 키 문자열은 `ios-moaki/SnippetSettingsView.swift`와 반드시 동일하게 유지한다
/// (키보드 익스텐션과 호스트 앱은 별도 프로세스라 코드를 공유하지 못하고 이렇게 나뉘어 있다).
enum SnippetSettings {
    static let appGroupID = AppGroupConstants.appGroupID

    /// ㅋㅌㅊㅍ 롱프레스 문구와 별개로, 특정 자음에 묶이지 않은 추가 문구 목록의 키.
    static let extraSnippetsKey = "snippet.extra"

    static func userDefaultsKey(for consonant: Choseong) -> String? {
        switch consonant {
        case .ㅋ: return "snippet.ㅋ"
        case .ㅌ: return "snippet.ㅌ"
        case .ㅊ: return "snippet.ㅊ"
        case .ㅍ: return "snippet.ㅍ"
        default: return nil
        }
    }

    /// 등록된 문구가 없으면(빈 문자열 포함) nil을 반환한다.
    static func snippet(for consonant: Choseong) -> String? {
        snippet(for: consonant, defaults: UserDefaults(suiteName: appGroupID))
    }

    static func snippet(for consonant: Choseong, defaults: UserDefaults?) -> String? {
        guard let key = userDefaultsKey(for: consonant),
              let text = defaults?.string(forKey: key),
              !text.isEmpty else {
            return nil
        }
        return text
    }

    /// 자음에 묶이지 않은 추가 문구 목록(빈 문자열은 제외).
    static func extraSnippets() -> [String] {
        extraSnippets(defaults: UserDefaults(suiteName: appGroupID))
    }

    static func extraSnippets(defaults: UserDefaults?) -> [String] {
        let raw = defaults?.stringArray(forKey: extraSnippetsKey) ?? []
        return raw.filter { !$0.isEmpty }
    }

    /// ㅋㅌㅊㅍ 중 채워진 것 + 추가 문구를 합친, "문구" 버튼 후보 바에 보여줄 전체 목록.
    static func allSnippets() -> [String] {
        allSnippets(defaults: UserDefaults(suiteName: appGroupID))
    }

    static func allSnippets(defaults: UserDefaults?) -> [String] {
        let consonantSnippets: [String] = [Choseong.ㅋ, .ㅌ, .ㅊ, .ㅍ].compactMap { snippet(for: $0, defaults: defaults) }
        return consonantSnippets + extraSnippets(defaults: defaults)
    }
}
