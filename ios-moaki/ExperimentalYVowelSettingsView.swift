import SwiftUI

/// Y계열(ㅑㅕㅛㅠ) 원점 복귀 인식기 — 검증용 실험 기능. 기본값은 OFF다.
/// 앱 그룹 이름과 키 문자열은 `MoakiKeyboard/Utilities/ExperimentalYVowelSettings.swift`와
/// 반드시 동일하게 유지한다(키보드 익스텐션과 호스트 앱은 별도 프로세스라 코드를
/// 공유하지 못하고 이렇게 나뉘어 있다).
struct ExperimentalYVowelSettingsView: View {
    static let enabledKey = "experimentalYVowelEnabled"
    static let appliedCountKey = "experimentalYVowelAppliedCount"
    static let conflictOverrideCountKey = "experimentalYVowelConflictOverrideCount"

    @State private var isEnabled = false
    @State private var appliedCount = 0
    @State private var conflictOverrideCount = 0

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConstants.appGroupID)
    }

    var body: some View {
        Form {
            Section {
                Text("ㅑㅕㅛㅠ를 입력할 때, 방향으로 밖에 뺐다가 원점 근처로 돌아온 뒤 같은 방향으로 다시 빼면 그 모음으로 인식하는 실험적 기능입니다. 안드로이드 삼성 모아키 사용 경험이 있는 분들을 위한 검증용 기능이며, 기본은 꺼짐입니다.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section("실험 기능") {
                Toggle("Y계열 원점 복귀 인식", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, newValue in
                        defaults?.set(newValue, forKey: Self.enabledKey)
                    }

                Text("이 토글은 다음 획부터 바로 반영됩니다. 반면 제스처 민감도 배율은 키보드를 껐다 켜야 반영되는 별개의 설정입니다 — 이 화면 토글을 바꿔도 민감도 설정 자체는 즉시 반영되지 않습니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("참고용 진단 수치") {
                LabeledContent("적용된 횟수", value: "\(appliedCount)")
                LabeledContent("기존 결과를 덮어쓴 횟수", value: "\(conflictOverrideCount)")

                Text("이 수치는 정확도 지표가 아니며, 실험 알고리즘이 개입한 횟수만 보여줍니다. 실제 인식률 비교는 OFF/ON 상태에서 직접 입력해보고 의도한 모음과 실제 입력 결과를 비교하는 방식으로 확인하세요.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("진단 수치 초기화", role: .destructive) {
                    resetCounters()
                }
                Text("초기화는 키보드를 사용하고 있지 않을 때 하세요(드물게 키보드가 동시에 값을 기록 중이면 초기화가 일부 반영 안 될 수 있습니다 — 진단용 수치라 기능이나 입력 정확도에는 영향이 없습니다).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("실험 기능: Y계열 인식")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    private func load() {
        isEnabled = defaults?.bool(forKey: Self.enabledKey) ?? false
        appliedCount = defaults?.integer(forKey: Self.appliedCountKey) ?? 0
        conflictOverrideCount = defaults?.integer(forKey: Self.conflictOverrideCountKey) ?? 0
    }

    private func resetCounters() {
        defaults?.set(0, forKey: Self.appliedCountKey)
        defaults?.set(0, forKey: Self.conflictOverrideCountKey)
        appliedCount = 0
        conflictOverrideCount = 0
    }
}

#Preview {
    NavigationStack {
        ExperimentalYVowelSettingsView()
    }
}
