import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 교재 목록. PDF를 끌어다 놓거나 파일 열기로 불러와요.
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Textbook.updatedAt, order: .reverse) private var textbooks: [Textbook]

    @State private var selection: Textbook?
    @State private var isImporterPresented = false
    @State private var isDropTargeted = false
    @State private var importErrors: [String] = []

    var body: some View {
        NavigationSplitView {
            List(textbooks, selection: $selection) { textbook in
                NavigationLink(value: textbook) {
                    TextbookRow(textbook: textbook)
                }
                .contextMenu {
                    Button("삭제", systemImage: "trash", role: .destructive) {
                        delete(textbook)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            .toolbar {
                ToolbarItem {
                    Button("PDF 불러오기", systemImage: "plus") {
                        isImporterPresented = true
                    }
                    .keyboardShortcut("o")
                    .help("교재 PDF 불러오기 (⌘O)")
                }
            }
        } detail: {
            if let selection {
                TextbookDetailView(textbook: selection)
                    .id(selection.persistentModelID)
            } else {
                emptyState
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls): importPDFs(urls)
            case .failure(let error): importErrors = [error.localizedDescription]
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
            guard !pdfs.isEmpty else { return false }
            importPDFs(pdfs)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.tint, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .alert(
            "불러오지 못한 파일이 있어요",
            isPresented: Binding(get: { !importErrors.isEmpty }, set: { if !$0 { importErrors = [] } })
        ) {
            Button("확인") { importErrors = [] }
        } message: {
            Text(importErrors.joined(separator: "\n"))
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(textbooks.isEmpty ? "교재 PDF를 넣어 주세요" : "교재를 골라 주세요", systemImage: "doc.richtext")
        } description: {
            Text("PDF를 이 창에 끌어다 놓거나 ‘PDF 불러오기’를 눌러 주세요.\n미리 자르지 않고 통째로 넣어도 괜찮아요.")
        } actions: {
            Button("PDF 불러오기…") { isImporterPresented = true }
        }
    }

    private func importPDFs(_ urls: [URL]) {
        var errors: [String] = []
        for url in urls {
            do {
                let imported = try PDFLibrary.importPDF(from: url)
                let textbook = Textbook(
                    title: imported.title,
                    fileName: imported.fileName,
                    pageCount: imported.pageCount,
                    bookPageOneAt: imported.suggestedBookPageOneAt
                )
                modelContext.insert(textbook)
                selection = textbook
            } catch {
                errors.append(error.localizedDescription)
            }
        }
        importErrors = errors
    }

    private func delete(_ textbook: Textbook) {
        if selection == textbook { selection = nil }
        PDFLibrary.deleteFile(named: textbook.fileName)
        modelContext.delete(textbook)
    }
}

private struct TextbookRow: View {
    let textbook: Textbook

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(textbook.title)
                .lineLimit(2)
            Text(textbook.examRangeSummary ?? "시험 범위 미설정 · 전체 \(textbook.pageCount)쪽")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
