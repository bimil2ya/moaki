import Foundation

/// 음절 → 한자 후보 사전.
///
/// 데이터 출처: libhangul(https://github.com/libhangul/libhangul)의
/// `data/hanja/hanja.txt`에서 "음절 1개 → 한자 1개" 항목만 추린 부분집합.
/// 번들 리소스 `hanja_single.txt` 헤더에 원본 BSD 3-Clause 라이선스 고지가 포함되어 있다.
///
/// 키보드 익스텐션의 메모리 제약을 고려해, 이 사전은 앱 시작 시가 아니라
/// 한자 후보가 실제로 필요해지는 시점(`candidates(for:)` 최초 호출)에 지연 로드된다.
final class HanjaDictionary {
    static let shared = HanjaDictionary()

    struct Candidate: Equatable {
        let hanja: Character
        let reading: String
    }

    private var table: [Character: [Candidate]] = [:]
    private var isLoaded = false

    private init() {}

    /// 주어진 음절에 대한 한자 후보 목록. 없으면 빈 배열.
    func candidates(for syllable: Character) -> [Candidate] {
        loadIfNeeded()
        return table[syllable] ?? []
    }

    private func loadIfNeeded() {
        guard !isLoaded else { return }

        // Bundle.main이 아니라 Bundle(for:)를 써야 익스텐션/테스트 양쪽에서
        // 이 리소스가 실제로 컴파일된 번들(MoakiKeyboard)을 정확히 찾는다.
        // isLoaded는 로드가 실제로 성공했을 때만 true로 설정한다 — 그렇지 않으면
        // 일시적 실패(메모리 부족 등) 한 번으로 이 프로세스가 살아있는 동안
        // 한자 기능이 영구적으로 먹통이 된다.
        guard let url = Bundle(for: HanjaDictionary.self).url(forResource: "hanja_single", withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }
        isLoaded = true

        contents.enumerateLines { line, _ in
            guard !line.hasPrefix("#"), !line.isEmpty else { return }

            let parts = line.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count >= 2,
                  parts[0].count == 1, let syllable = parts[0].first,
                  parts[1].count == 1, let hanja = parts[1].first else {
                return
            }

            let reading = parts.count >= 3 ? String(parts[2]) : ""
            self.table[syllable, default: []].append(Candidate(hanja: hanja, reading: reading))
        }
    }
}
