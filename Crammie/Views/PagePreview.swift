import PDFKit
import SwiftUI

/// 시험 범위 설정 화면 위에 한 페이지를 크게 띄우는 미리보기 (스페이스바).
///
/// 키 입력은 뒤의 썸네일 목록이 받아서 처리해요. 여기서는 보여 주기와 마우스 조작만 맡아요.
struct PagePreview: View {
    let document: PDFDocument
    let pdfPage: Int
    let bookPage: Int?
    let isSelected: Bool
    let onMove: (Int) -> Void
    let onToggle: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.45))
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                Divider()
                HStack(spacing: 0) {
                    pageButton(systemImage: "chevron.left", help: "이전 페이지 (←)", offset: -1)
                        .disabled(pdfPage <= 1)
                    PreviewPDFView(document: document, pageIndex: pdfPage - 1)
                    pageButton(systemImage: "chevron.right", help: "다음 페이지 (→)", offset: 1)
                        .disabled(pdfPage >= document.pageCount)
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator),
                                  lineWidth: isSelected ? 3 : 1)
            }
            .shadow(radius: 20)
            .padding(24)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(bookPage.map { "책 \($0)쪽" } ?? "책 앞부분")
                    .font(.headline)
                Text("PDF \(pdfPage) / \(document.pageCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("← → 넘기기 · Return 선택 · 스페이스 닫기")
                .font(.caption)
                .foregroundStyle(.secondary)
            if bookPage != nil {
                Button(isSelected ? "선택 해제" : "시험 범위에 넣기",
                       systemImage: isSelected ? "checkmark.circle.fill" : "circle",
                       action: onToggle)
            }
            Button("닫기", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
        }
    }

    private func pageButton(systemImage: String, help: String, offset: Int) -> some View {
        Button {
            onMove(offset)
        } label: {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 36)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// 한 페이지만 보여 주는 PDF 뷰. 핀치로 확대할 수 있어요.
private struct PreviewPDFView: NSViewRepresentable {
    let document: PDFDocument
    let pageIndex: Int

    func makeNSView(context: Context) -> PDFView {
        let view = NonFocusingPDFView()
        view.displayMode = .singlePage
        view.displaysPageBreaks = false
        view.autoScales = true
        view.backgroundColor = .clear
        view.document = document
        if let page = document.page(at: pageIndex) {
            view.go(to: page)
        }
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        guard let page = document.page(at: pageIndex), view.currentPage !== page else { return }
        view.go(to: page)
        // 페이지마다 크기가 다를 수 있어 다시 창에 맞춰요.
        view.autoScales = true
    }
}

/// 키 입력을 가로채지 않는 PDFView.
/// 이게 포커스를 가져가면 스페이스·화살표를 PDFView가 먹어서 미리보기를 닫거나 넘길 수 없어요.
private final class NonFocusingPDFView: PDFView {
    override var acceptsFirstResponder: Bool { false }
}
