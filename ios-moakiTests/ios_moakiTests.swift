//
//  ios_moakiTests.swift
//  ios-moakiTests
//
//  Created by Jeffrey Kim on 2026/1/28.
//

import Testing
@testable import ios_moaki

/// 호스트 앱 측 App Group 키/값 회귀 방지 테스트. `MoakiKeyboard/Utilities/`의 대응
/// 파일과 값이 반드시 같아야 하는데, 두 타깃이 별도 프로세스라 소스를 공유하지
/// 못한다 — 이 테스트는 호스트 앱 쪽 값 자체가 의도한 문자열/범위에서 벗어나지
/// 않는지만 확인한다(키보드 확장 쪽과의 실제 일치는 MoakiKeyboardTests의 대응
/// 테스트가 각각 통과하는 것으로 간접 확인한다).
struct ios_moakiTests {
    @Test func appGroupIDMatchesExpectedString() {
        #expect(AppGroupConstants.appGroupID == "group.dev.nohkyeongho.moaki")
    }

    @Test func experimentalYVowelSettingsKeysMatchExpectedStrings() {
        #expect(ExperimentalYVowelSettingsView.enabledKey == "experimentalYVowelEnabled")
        #expect(ExperimentalYVowelSettingsView.appliedCountKey == "experimentalYVowelAppliedCount")
        #expect(ExperimentalYVowelSettingsView.conflictOverrideCountKey == "experimentalYVowelConflictOverrideCount")
    }

    @Test func gestureSensitivitySettingsKeyAndRangeMatchExpectedValues() {
        #expect(GestureSensitivitySettingsView.multiplierKey == "gestureSensitivityMultiplier")
        #expect(GestureSensitivitySettingsView.range == 0.7...1.5)
    }

    @Test func snippetSettingsKeysMatchExpectedStrings() {
        #expect(SnippetSettingsView.extraSnippetsKey == "snippet.extra")
        #expect(SnippetSettingsView.slots.map { $0.key } == ["snippet.ㅋ", "snippet.ㅌ", "snippet.ㅊ", "snippet.ㅍ"])
    }
}
