import Foundation

/// 천지인(天地人) 입력 방식의 기본 스트로크.
/// ㅣ(人/사람) · ㅡ(地/땅) · ㆍ(天/하늘) 세 개를 순서대로 조합해 모음을 만든다.
enum CheonjiinStroke: CaseIterable, Equatable, Hashable {
    case dot  // ㆍ
    case eu   // ㅡ
    case i    // ㅣ

    var displayText: String {
        switch self {
        case .dot: return "ㆍ"
        case .eu: return "ㅡ"
        case .i: return "ㅣ"
        }
    }
}
