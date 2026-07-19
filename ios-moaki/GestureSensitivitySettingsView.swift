import SwiftUI

/// 제스처 인식 거리(threshold) 배율을 앱 그룹 공유 UserDefaults에 저장한다.
/// 앱 그룹 이름과 키 문자열은 `MoakiKeyboard/Utilities/GestureSensitivitySettings.swift`와
/// 반드시 동일하게 유지한다 (키보드 익스텐션과 호스트 앱은 별도 프로세스라
/// 코드를 공유하지 못하고 이렇게 나뉘어 있다).
struct GestureSensitivitySettingsView: View {
    private let appGroupID = AppGroupConstants.appGroupID
    private let multiplierKey = "gestureSensitivityMultiplier"
    private let range: ClosedRange<Double> = 0.7...1.5

    @State private var multiplier: Double = 1.0

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    var body: some View {
        Form {
            Section {
                Text("자음 위에서 모음 방향으로 드래그할 때, 얼마나 확실하게 움직여야 방향이 인식될지를 조절합니다. 오인식(예: '오'가 '와'로 잘못 입력됨)이 잦다면 오른쪽으로 옮겨 더 확실한 움직임을 요구하게 하세요. 값을 바꾼 뒤에는 키보드를 한 번 껐다 켜야 반영됩니다.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section("제스처 인식 거리") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("민감하게 (짧게)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("확실하게 (길게)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $multiplier, in: range, step: 0.05) {
                        Text("제스처 인식 거리")
                    } onEditingChanged: { isEditing in
                        if !isEditing {
                            save()
                        }
                    }
                    Text(String(format: "현재 배율: %.2f배 (기본값 1.00배)", multiplier))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button("기본값으로 되돌리기") {
                    multiplier = 1.0
                    save()
                }
            }
        }
        .navigationTitle("제스처 민감도")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    private func load() {
        guard let stored = defaults?.object(forKey: multiplierKey) as? Double else {
            multiplier = 1.0
            return
        }
        multiplier = min(max(stored, range.lowerBound), range.upperBound)
    }

    private func save() {
        defaults?.set(multiplier, forKey: multiplierKey)
    }
}

#Preview {
    NavigationStack {
        GestureSensitivitySettingsView()
    }
}
