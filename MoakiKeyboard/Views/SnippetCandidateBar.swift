import SwiftUI

/// "문구" 버튼을 탭했을 때 등록해둔 문구들을 가로로 보여주는 바.
/// 후보를 탭하면 그 문구가 그대로 삽입되고, 다른 키를 누르면 사라진다.
struct SnippetCandidateBar: View {
    let snippets: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(snippets.enumerated()), id: \.offset) { _, snippet in
                    Button {
                        onSelect(snippet)
                    } label: {
                        Text(snippet)
                            .font(.system(size: 15, weight: .medium))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 56)
        .background(Color(.systemGray6))
    }
}

#Preview {
    SnippetCandidateBar(
        snippets: ["name@example.com", "안녕하세요, 노경호입니다.", "010-1234-5678"],
        onSelect: { _ in }
    )
}
