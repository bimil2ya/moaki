import SwiftUI

/// ㅋㅌㅊㅍ 롱프레스로 삽입할 문구를 앱 그룹 공유 UserDefaults에 저장한다.
/// 앱 그룹 이름과 키 문자열은 `MoakiKeyboard/Utilities/SnippetSettings.swift`와
/// 반드시 동일하게 유지한다 (키보드 익스텐션과 호스트 앱은 별도 프로세스라
/// 코드를 공유하지 못하고 이렇게 나뉘어 있다).
struct SnippetSettingsView: View {
    private let appGroupID = AppGroupConstants.appGroupID
    static let extraSnippetsKey = "snippet.extra"
    static let slots: [(label: String, key: String)] = [
        ("ㅋ 길게 누르면", "snippet.ㅋ"),
        ("ㅌ 길게 누르면", "snippet.ㅌ"),
        ("ㅊ 길게 누르면", "snippet.ㅊ"),
        ("ㅍ 길게 누르면", "snippet.ㅍ"),
    ]

    @State private var values: [String: String] = [:]
    @State private var extraSnippets: [String] = []

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    var body: some View {
        Form {
            Section {
                Text("키보드에서 해당 자음 키를 0.5초 이상 길게 누르면 아래 문구가 그대로 입력됩니다. 비워두면 원래대로 아무 일도 일어나지 않습니다. 등록한 문구는 전부 키보드의 \"문구\" 버튼을 눌러도 목록에서 골라 넣을 수 있습니다.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section("ㅋㅌㅊㅍ 롱프레스") {
                ForEach(Self.slots, id: \.key) { slot in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(slot.label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("예: name@example.com", text: binding(for: slot.key))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
            }

            Section("추가 문구") {
                ForEach(Array(extraSnippets.indices), id: \.self) { index in
                    TextField("문구 입력", text: extraSnippetBinding(at: index))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .onDelete { offsets in
                    extraSnippets.remove(atOffsets: offsets)
                    saveExtraSnippets()
                }

                Button {
                    extraSnippets.append("")
                } label: {
                    Label("문구 추가", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("자주 쓰는 문구")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadValues)
    }

    private func loadValues() {
        guard let defaults else { return }
        for slot in Self.slots {
            values[slot.key] = defaults.string(forKey: slot.key) ?? ""
        }
        extraSnippets = defaults.stringArray(forKey: Self.extraSnippetsKey) ?? []
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { values[key] ?? "" },
            set: { newValue in
                values[key] = newValue
                defaults?.set(newValue, forKey: key)
            }
        )
    }

    private func extraSnippetBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { extraSnippets[index] },
            set: { newValue in
                extraSnippets[index] = newValue
                saveExtraSnippets()
            }
        )
    }

    private func saveExtraSnippets() {
        defaults?.set(extraSnippets, forKey: Self.extraSnippetsKey)
    }
}

#Preview {
    NavigationStack {
        SnippetSettingsView()
    }
}
