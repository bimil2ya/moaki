import SwiftUI

/// VoiceOver 사용자를 위한 접근성 모음 선택 화면. 기존 드래그 기반 모음 입력은 전혀
/// 바꾸지 않고, 자음 키의 커스텀 액션(로터)으로만 진입하는 완전히 별도의 입력 경로다.
/// 21개 모음을 일반 버튼으로 나열해 드래그 없이도 자음+모음 조합을 만들 수 있게 한다.
struct AccessibilityVowelPickerView: View {
    let consonant: Choseong
    let onSelect: (Jungseong) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Jungseong.allCases, id: \.self) { vowel in
                        Button {
                            onSelect(vowel)
                            dismiss()
                        } label: {
                            VStack(spacing: 4) {
                                Text(String(vowel.compatibilityCharacter))
                                    .font(.system(size: 28, weight: .medium))
                                Text(String(HangulConstants.composeSyllable(choseong: consonant, jungseong: vowel)))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                        .accessibilityLabel("모음 \(String(vowel.compatibilityCharacter))")
                        .accessibilityHint("결과: \(String(HangulConstants.composeSyllable(choseong: consonant, jungseong: vowel)))")
                    }
                }
                .padding(16)
            }
            .navigationTitle("\(String(consonant.compatibilityCharacter)) 다음 모음 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AccessibilityVowelPickerView(consonant: .ㄱ, onSelect: { _ in })
}
