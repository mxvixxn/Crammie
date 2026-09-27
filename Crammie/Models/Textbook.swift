import Foundation
import SwiftData

/// 불러온 교재 PDF 한 권과 그 교재의 시험 범위.
///
/// 쪽 번호가 두 가지라 헷갈리지 않게 이름을 구분해요.
/// - **PDF 페이지**: PDF 파일 안의 순서 (1부터). 저장은 항상 이 번호로 해요.
/// - **책 쪽수**: 교재에 인쇄된 쪽 번호. 표지·목차 때문에 PDF 페이지와 어긋날 수 있어요.
///
/// 둘의 관계는 `bookPageOneAt`(책 1쪽이 PDF 몇 페이지인지) 하나로 보정해요.
@Model
final class Textbook {
    var title: String
    /// 앱 보관함(`PDFLibrary.directory`)에 복사해 둔 파일 이름
    var fileName: String
    var pageCount: Int
    /// 책 1쪽이 놓인 PDF 페이지 번호. 어긋남이 없으면 1이에요.
    var bookPageOneAt: Int
    /// 시험 범위로 고른 PDF 페이지 번호 (정렬, 1부터)
    var examPDFPages: [Int]
    var createdAt: Date
    var updatedAt: Date

    init(title: String, fileName: String, pageCount: Int, bookPageOneAt: Int = 1) {
        self.title = title
        self.fileName = fileName
        self.pageCount = pageCount
        self.bookPageOneAt = bookPageOneAt
        self.examPDFPages = []
        self.createdAt = .now
        self.updatedAt = .now
    }
}

// MARK: - 책 쪽수 ↔ PDF 페이지

extension Textbook {
    /// 책 쪽수로 적을 수 있는 범위
    var bookPageBounds: ClosedRange<Int> {
        Textbook.bookPageBounds(pageCount: pageCount, bookPageOneAt: bookPageOneAt)
    }

    var examBookPages: [Int] {
        examPDFPages.compactMap { Textbook.bookPage(forPDFPage: $0, bookPageOneAt: bookPageOneAt) }
    }

    /// 예: `"책 12-20, 45-78쪽 · 38쪽"`. 범위가 없으면 `nil`
    var examRangeSummary: String? {
        guard !examPDFPages.isEmpty else { return nil }
        return "책 \(PageRangeFormat.format(examBookPages))쪽 · \(examPDFPages.count)쪽"
    }

    static func bookPageBounds(pageCount: Int, bookPageOneAt: Int) -> ClosedRange<Int> {
        1...max(1, pageCount - bookPageOneAt + 1)
    }

    static func pdfPage(forBookPage bookPage: Int, bookPageOneAt: Int) -> Int {
        bookPage + bookPageOneAt - 1
    }

    /// 책 1쪽보다 앞(표지·목차)이면 `nil`
    static func bookPage(forPDFPage pdfPage: Int, bookPageOneAt: Int) -> Int? {
        let bookPage = pdfPage - bookPageOneAt + 1
        return bookPage >= 1 ? bookPage : nil
    }
}
