import SwiftUI

/// VoiceOver 사용자를 위한 접근성 모음 선택 바. 기존 드래그 기반 모음 입력은 전혀
/// 바꾸지 않고, 자음 키의 커스텀 액션(로터)으로만 진입하는 완전히 별도의 입력 경로다.
///
/// HanjaCandidateBar/SnippetCandidateBar와 동일하게 KeyboardView의 ZStack 오버레이로
/// 표시된다 — 키보드 익스텐션(고정 높이, 별도 프로세스)에서 검증되지 않은 `.sheet()`
/// 모달 대신, 이미 이 앱에서 실제로 동작이 확인된 오버레이 방식을 그대로 따른다.
struct AccessibilityVowelPickerBar: View {
    let consonant: Choseong
    let onSelect: (Jungseong) -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    onCancel()
                } label: {
                    Text("취소")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.tertiarySystemBackground))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("모음 선택 취소")

                ForEach(Jungseong.allCases, id: \.self) { vowel in
                    Button {
                        onSelect(vowel)
                    } label: {
                        VStack(spacing: 2) {
                            Text(String(vowel.compatibilityCharacter))
                                .font(.system(size: 22, weight: .medium))
                            Text(String(HangulConstants.composeSyllable(choseong: consonant, jungseong: vowel)))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("모음 \(String(vowel.compatibilityCharacter))")
                    .accessibilityHint("결과: \(String(HangulConstants.composeSyllable(choseong: consonant, jungseong: vowel)))")
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 56)
        .background(Color(.systemGray6))
    }
}

#Preview {
    AccessibilityVowelPickerBar(consonant: .ㄱ, onSelect: { _ in }, onCancel: {})
}
