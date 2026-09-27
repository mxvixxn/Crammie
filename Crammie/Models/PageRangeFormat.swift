import Foundation

/// 시험 범위 문자열(`"12-20, 45-78"`)과 쪽 번호 목록 사이를 변환해요.
/// 쪽 번호는 1부터 시작해요.
enum PageRangeFormat {
    enum ParseError: LocalizedError, Equatable {
        case invalidToken(String)
        case reversed(String)
        case outOfBounds(Int, ClosedRange<Int>)

        var errorDescription: String? {
            switch self {
            case .invalidToken(let token):
                "‘\(token)’ 부분을 이해하지 못했어요. 예: 12-20, 45-78"
            case .reversed(let token):
                "‘\(token)’ 는 앞 숫자가 더 커요. 작은 쪽을 먼저 적어 주세요."
            case .outOfBounds(let page, let bounds):
                "\(page)쪽은 교재 범위를 벗어나요. \(bounds.lowerBound)~\(bounds.upperBound)쪽 사이로 적어 주세요."
            }
        }
    }

    /// `"12-20, 45-78"` → `[12, 13, …, 20, 45, …, 78]` (정렬, 중복 제거)
    ///
    /// 구간 기호는 `-`, `~`, `–`, `—` 를, 구분자는 쉼표와 공백을 받아요. `"쪽"`, `"p"` 같은 꼬리표는 무시해요.
    static func parse(_ text: String, bounds: ClosedRange<Int>) throws -> [Int] {
        var normalized = text
        for dash in ["~", "–", "—", "−", "∼", "～"] {
            normalized = normalized.replacingOccurrences(of: dash, with: "-")
        }
        for comma in ["，", "、", ";"] {
            normalized = normalized.replacingOccurrences(of: comma, with: ",")
        }
        for suffix in ["페이지", "쪽", "p", "P"] {
            normalized = normalized.replacingOccurrences(of: suffix, with: "")
        }
        // "12 - 20" 처럼 기호 양옆에 띄어 쓴 경우를 붙여 둬야 공백으로 나눌 수 있어요.
        normalized = normalized.replacingOccurrences(of: #"\s*-\s*"#, with: "-", options: .regularExpression)

        let separators = CharacterSet(charactersIn: ",").union(.whitespacesAndNewlines)
        var pages = Set<Int>()

        for token in normalized.components(separatedBy: separators) where !token.isEmpty {
            let parts = token.split(separator: "-", omittingEmptySubsequences: false)
            let numbers = parts.compactMap { Int($0) }
            guard numbers.count == parts.count, (1...2).contains(numbers.count) else {
                throw ParseError.invalidToken(token)
            }
            let start = numbers[0]
            let end = numbers.last!
            guard start <= end else { throw ParseError.reversed(token) }
            for page in [start, end] where !bounds.contains(page) {
                throw ParseError.outOfBounds(page, bounds)
            }
            pages.formUnion(start...end)
        }
        return pages.sorted()
    }

    /// `[12, 13, 14, 20]` → `"12-14, 20"`
    static func format(_ pages: [Int]) -> String {
        runs(of: pages)
            .map { $0.lowerBound == $0.upperBound ? "\($0.lowerBound)" : "\($0.lowerBound)-\($0.upperBound)" }
            .joined(separator: ", ")
    }

    /// 연속된 쪽을 구간으로 묶어요.
    static func runs(of pages: [Int]) -> [ClosedRange<Int>] {
        var result: [ClosedRange<Int>] = []
        for page in Set(pages).sorted() {
            if let last = result.last, last.upperBound + 1 == page {
                result[result.count - 1] = last.lowerBound...page
            } else {
                result.append(page...page)
            }
        }
        return result
    }
}
