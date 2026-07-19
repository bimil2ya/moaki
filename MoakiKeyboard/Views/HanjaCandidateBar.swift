import SwiftUI

/// 한자 버튼을 탭했을 때 커서 앞 음절의 한자 후보를 가로로 보여주는 바.
/// 후보를 탭하면 선택되고, 후보가 없거나 다른 키를 누르면 사라진다.
struct HanjaCandidateBar: View {
    let candidates: [HanjaDictionary.Candidate]
    let onSelect: (HanjaDictionary.Candidate) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(candidates.enumerated()), id: \.offset) { _, candidate in
                    Button {
                        onSelect(candidate)
                    } label: {
                        VStack(spacing: 2) {
                            Text(String(candidate.hanja))
                                .font(.system(size: 22, weight: .medium))
                            if !candidate.reading.isEmpty {
                                Text(candidate.reading)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
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
    HanjaCandidateBar(
        candidates: [
            .init(hanja: "可", reading: "옳을 가"),
            .init(hanja: "家", reading: "집 가"),
            .init(hanja: "加", reading: "더할 가"),
            .init(hanja: "歌", reading: "노래 가")
        ],
        onSelect: { _ in }
    )
}
