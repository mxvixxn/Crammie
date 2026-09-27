import AppKit
import PDFKit
import SwiftUI

/// 시험 범위 설정 화면.
///
/// 범위는 **책 쪽수**로 적어요(선생님이 알려 주는 번호 그대로). 저장할 때 PDF 페이지로 바꿔 둬요.
/// 입력칸과 썸네일은 서로 연결돼 있어서, 어느 쪽으로 고쳐도 다른 쪽에 바로 반영돼요.
struct ExamRangeSettingsView: View {
    let textbook: Textbook
    let document: PDFDocument

    @Environment(\.dismiss) private var dismiss

    @State private var rangeText = ""
    @State private var bookPageOneAt = 1
    /// 마지막으로 올바르게 읽힌 책 쪽수 목록
    @State private var selectedBookPages: [Int] = []
    @State private var parseError: String?
    /// Shift-클릭으로 구간을 고를 때 기준이 되는 책 쪽수
    @State private var anchorBookPage: Int?
    @State private var thumbnails = ThumbnailCache()
    /// 마우스가 올라가 있는 썸네일의 PDF 페이지
    @State private var hoveredPDFPage: Int?
    /// 마지막으로 클릭했거나 미리보기로 본 PDF 페이지
    @State private var currentPDFPage: Int?
    /// 크게 보고 있는 PDF 페이지. `nil`이면 미리보기가 닫혀 있어요.
    @State private var previewPDFPage: Int?
    @FocusState private var isGridFocused: Bool

    private var bookBounds: ClosedRange<Int> {
        Textbook.bookPageBounds(pageCount: textbook.pageCount, bookPageOneAt: bookPageOneAt)
    }

    var body: some View {
        VStack(spacing: 0) {
            form
                .padding()
            Divider()
            thumbnailGrid
            Divider()
            footer
                .padding()
        }
        .overlay {
            if let previewPDFPage {
                PagePreview(
                    document: document,
                    pdfPage: previewPDFPage,
                    bookPage: Textbook.bookPage(forPDFPage: previewPDFPage, bookPageOneAt: bookPageOneAt),
                    isSelected: isSelected(pdfPage: previewPDFPage),
                    onMove: movePreview(by:),
                    onToggle: { togglePreviewedPage() },
                    onClose: { self.previewPDFPage = nil }
                )
            }
        }
        .frame(minWidth: 760, idealWidth: 960, minHeight: 620, idealHeight: 860)
        .defaultFocus($isGridFocused, true)
        .onAppear {
            bookPageOneAt = textbook.bookPageOneAt
            rangeText = PageRangeFormat.format(textbook.examBookPages)
            reparse()
        }
        .onChange(of: rangeText) { reparse() }
        .onChange(of: bookPageOneAt) {
            let clamped = min(max(1, bookPageOneAt), textbook.pageCount)
            if clamped != bookPageOneAt {
                bookPageOneAt = clamped
            } else {
                reparse()
            }
        }
    }

    // MARK: - 입력

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("시험 범위 설정")
                    .font(.title2.bold())
                Text(textbook.title)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("시험 범위 (책 쪽수)")
                    .font(.headline)
                TextField("시험 범위", text: $rangeText, prompt: Text("예: 12-20, 45-78"))
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospacedDigit())
                Group {
                    if let parseError {
                        Label(parseError, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                    } else if selectedBookPages.isEmpty {
                        Text("쪽수를 적거나 아래 썸네일을 눌러 골라 주세요. Shift-클릭하면 구간을 한 번에 골라요.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(PageRangeFormat.runs(of: selectedBookPages).count)개 구간, 모두 \(selectedBookPages.count)쪽을 골랐어요.")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("쪽수 맞추기")
                    .font(.headline)
                HStack(spacing: 6) {
                    Text("책 1쪽은 PDF의")
                    TextField("PDF 페이지", value: $bookPageOneAt, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 56)
                        .multilineTextAlignment(.trailing)
                    Stepper("PDF 페이지", value: $bookPageOneAt, in: 1...textbook.pageCount)
                        .labelsHidden()
                    Text("번째 페이지예요.")
                }
                Text("표지·목차 때문에 쪽수가 어긋나면 맞춰 주세요. 썸네일을 오른쪽 클릭해서 ‘이 페이지를 책 1쪽으로’를 골라도 돼요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label("썸네일에 마우스를 올리고 스페이스바를 누르면 크게 볼 수 있어요.", systemImage: "keyboard")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 썸네일

    private var thumbnailGrid: some View {
        let selected = Set(selectedBookPages)
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 14)], spacing: 16) {
                    ForEach(1...textbook.pageCount, id: \.self) { pdfPage in
                        let bookPage = Textbook.bookPage(forPDFPage: pdfPage, bookPageOneAt: bookPageOneAt)
                        PageCell(
                            page: document.page(at: pdfPage - 1),
                            pdfPage: pdfPage,
                            bookPage: bookPage,
                            isSelected: bookPage.map { selected.contains($0) } ?? false,
                            isHovered: hoveredPDFPage == pdfPage,
                            cache: thumbnails
                        )
                        .onTapGesture {
                            isGridFocused = true
                            currentPDFPage = pdfPage
                            if let bookPage { toggle(bookPage) }
                        }
                        .onHover { isInside in
                            if isInside {
                                hoveredPDFPage = pdfPage
                            } else if hoveredPDFPage == pdfPage {
                                hoveredPDFPage = nil
                            }
                        }
                        .contextMenu {
                            Button("이 페이지를 책 1쪽으로") { bookPageOneAt = pdfPage }
                        }
                        .id(pdfPage)
                    }
                }
                .padding()
            }
            .focusable()
            .focused($isGridFocused)
            .focusEffectDisabled()
            .onKeyPress(keys: [.space, .escape, .leftArrow, .rightArrow, .return]) { press in
                handleKey(press.key)
            }
            .onAppear {
                if let first = textbook.examPDFPages.first {
                    proxy.scrollTo(first, anchor: .top)
                }
            }
            .onChange(of: previewPDFPage) {
                // 미리보기에서 넘긴 페이지가 닫았을 때 보이도록 뒤에서 따라가요.
                if let previewPDFPage {
                    proxy.scrollTo(previewPDFPage, anchor: .center)
                }
            }
        }
        .background(.background.secondary)
    }

    // MARK: - 하단 버튼

    private var footer: some View {
        HStack {
            Button("모두 해제") { rangeText = "" }
                .disabled(selectedBookPages.isEmpty && parseError == nil)
            Spacer()
            // 미리보기 중에는 Esc·Return을 미리보기가 써야 해서 단축키를 잠시 꺼 둬요.
            Button("취소", role: .cancel) { dismiss() }
                .keyboardShortcut(previewPDFPage == nil ? KeyboardShortcut.cancelAction : nil)
            Button("저장") { save() }
                .keyboardShortcut(previewPDFPage == nil ? KeyboardShortcut.defaultAction : nil)
                .disabled(parseError != nil)
        }
    }

    // MARK: - 동작

    private func reparse() {
        do {
            selectedBookPages = try PageRangeFormat.parse(rangeText, bounds: bookBounds)
            parseError = nil
        } catch {
            parseError = error.localizedDescription
        }
    }

    private func toggle(_ bookPage: Int) {
        var pages = Set(selectedBookPages)
        if NSEvent.modifierFlags.contains(.shift), let anchorBookPage {
            pages.formUnion(min(anchorBookPage, bookPage)...max(anchorBookPage, bookPage))
        } else if pages.contains(bookPage) {
            pages.remove(bookPage)
        } else {
            pages.insert(bookPage)
        }
        anchorBookPage = bookPage
        rangeText = PageRangeFormat.format(Array(pages))
    }

    private func isSelected(pdfPage: Int) -> Bool {
        guard let bookPage = Textbook.bookPage(forPDFPage: pdfPage, bookPageOneAt: bookPageOneAt) else { return false }
        return selectedBookPages.contains(bookPage)
    }

    private func handleKey(_ key: KeyEquivalent) -> KeyPress.Result {
        guard previewPDFPage != nil else {
            guard key == .space, let target = hoveredPDFPage ?? currentPDFPage ?? textbook.examPDFPages.first else {
                return .ignored
            }
            previewPDFPage = target
            currentPDFPage = target
            return .handled
        }
        switch key {
        case .space, .escape: previewPDFPage = nil
        case .leftArrow: movePreview(by: -1)
        case .rightArrow: movePreview(by: 1)
        case .return: togglePreviewedPage()
        default: return .ignored
        }
        return .handled
    }

    private func movePreview(by offset: Int) {
        guard let previewPDFPage else { return }
        let next = min(max(1, previewPDFPage + offset), textbook.pageCount)
        self.previewPDFPage = next
        currentPDFPage = next
        // 뒤에서 스크롤이 따라가면 마우스 아래 썸네일이 바뀌므로, 닫은 뒤에는 방금 본 페이지를 기준으로 해요.
        hoveredPDFPage = nil
    }

    private func togglePreviewedPage() {
        guard let previewPDFPage,
              let bookPage = Textbook.bookPage(forPDFPage: previewPDFPage, bookPageOneAt: bookPageOneAt)
        else { return }
        toggle(bookPage)
    }

    private func save() {
        textbook.bookPageOneAt = bookPageOneAt
        textbook.examPDFPages = selectedBookPages
            .map { Textbook.pdfPage(forBookPage: $0, bookPageOneAt: bookPageOneAt) }
            .filter { (1...textbook.pageCount).contains($0) }
        textbook.updatedAt = .now
        dismiss()
    }
}

// MARK: - 썸네일 칸

private struct PageCell: View {
    let page: PDFPage?
    let pdfPage: Int
    let bookPage: Int?
    let isSelected: Bool
    let isHovered: Bool
    let cache: ThumbnailCache

    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Rectangle().fill(.quaternary)
                    }
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator),
                                      lineWidth: isSelected ? 3 : 1)
                }
                .overlay {
                    if isHovered && !isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(.secondary, lineWidth: 2)
                    }
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .tint)
                        .padding(4)
                }
            }

            VStack(spacing: 0) {
                Text(bookPage.map { "책 \($0)쪽" } ?? "책 앞부분")
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                Text("PDF \(pdfPage)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(bookPage == nil ? 0.45 : 1)
        .contentShape(Rectangle())
        .task(id: pdfPage) {
            if let cached = cache.image(for: pdfPage) {
                image = cached
                return
            }
            // 스크롤할 때 화면이 멈추지 않도록 한 박자 쉬고 그려요.
            await Task.yield()
            guard !Task.isCancelled, let page else { return }
            let rendered = page.thumbnail(of: CGSize(width: 240, height: 320), for: .mediaBox)
            cache.store(rendered, for: pdfPage)
            image = rendered
        }
    }
}

/// 썸네일을 다시 그리지 않도록 잠시 들고 있는 곳
final class ThumbnailCache {
    private let storage = NSCache<NSNumber, NSImage>()

    func image(for pdfPage: Int) -> NSImage? {
        storage.object(forKey: NSNumber(value: pdfPage))
    }

    func store(_ image: NSImage, for pdfPage: Int) {
        storage.setObject(image, forKey: NSNumber(value: pdfPage))
    }
}
