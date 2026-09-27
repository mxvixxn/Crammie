import Foundation
import PDFKit

/// 교재 PDF 파일을 앱 보관함에 복사해 두고 꺼내 쓰는 곳.
///
/// 원본 위치에 의존하지 않도록 불러올 때 샌드박스 안(Application Support)으로 복사해요.
/// 그래서 원본을 옮기거나 지워도 앱에서는 계속 열 수 있어요.
enum PDFLibrary {
    enum ImportError: LocalizedError {
        case notPDF(String)
        case unreadable(String)
        case locked(String)
        case empty(String)

        var errorDescription: String? {
            switch self {
            case .notPDF(let name): "‘\(name)’ 은(는) PDF 파일이 아니에요."
            case .unreadable(let name): "‘\(name)’ 을(를) 열 수 없어요. 파일이 손상되었는지 확인해 주세요."
            case .locked(let name): "‘\(name)’ 은(는) 암호가 걸려 있어요. 암호를 푼 PDF로 다시 넣어 주세요."
            case .empty(let name): "‘\(name)’ 에 페이지가 없어요."
            }
        }
    }

    struct ImportedPDF {
        let title: String
        let fileName: String
        let pageCount: Int
        let suggestedBookPageOneAt: Int
    }

    static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "Textbooks", directoryHint: .isDirectory)
    }

    static func url(for fileName: String) -> URL {
        directory.appending(path: fileName, directoryHint: .notDirectory)
    }

    static func document(for textbook: Textbook) -> PDFDocument? {
        PDFDocument(url: url(for: textbook.fileName))
    }

    /// PDF를 확인한 뒤 보관함에 복사해요.
    static func importPDF(from source: URL) throws -> ImportedPDF {
        let displayName = source.lastPathComponent
        guard source.pathExtension.lowercased() == "pdf" else { throw ImportError.notPDF(displayName) }

        // 파일 열기 창으로 고른 파일은 샌드박스 밖이라 접근 허가를 받아야 해요.
        let isAccessing = source.startAccessingSecurityScopedResource()
        defer { if isAccessing { source.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: source) else { throw ImportError.unreadable(displayName) }
        guard !document.isLocked else { throw ImportError.locked(displayName) }
        guard document.pageCount > 0 else { throw ImportError.empty(displayName) }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = UUID().uuidString + ".pdf"
        try FileManager.default.copyItem(at: source, to: url(for: fileName))

        return ImportedPDF(
            title: source.deletingPathExtension().lastPathComponent,
            fileName: fileName,
            pageCount: document.pageCount,
            suggestedBookPageOneAt: suggestedBookPageOneAt(in: document)
        )
    }

    static func deleteFile(named fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    /// PDF에 쪽 번호 라벨(예: 앞부분 i, ii, iii 다음 1, 2, 3…)이 들어 있으면 책 1쪽의 위치를 추측해요.
    /// 라벨이 없으면 1을 돌려줘요. 틀릴 수 있으니 설정 화면에서 고칠 수 있어요.
    static func suggestedBookPageOneAt(in document: PDFDocument) -> Int {
        for index in 0..<min(document.pageCount, 80) {
            if document.page(at: index)?.label?.trimmingCharacters(in: .whitespaces) == "1" {
                return index + 1
            }
        }
        return 1
    }

    /// 고른 PDF 페이지만 담은 새 문서를 만들어요. (미리보기, 나중에 AI 전송용)
    static func extractPages(_ pdfPages: [Int], from document: PDFDocument) -> PDFDocument {
        let extracted = PDFDocument()
        for pdfPage in pdfPages {
            guard let page = document.page(at: pdfPage - 1)?.copy() as? PDFPage else { continue }
            extracted.insert(page, at: extracted.pageCount)
        }
        return extracted
    }
}
