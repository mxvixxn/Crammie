import PDFKit
import SwiftUI

/// 교재 한 권의 미리보기. 전체 또는 시험 범위만 볼 수 있어요.
struct TextbookDetailView: View {
    enum PreviewScope: Hashable {
        case all, exam
    }

    let textbook: Textbook

    @State private var document: PDFDocument?
    @State private var examDocument: PDFDocument?
    @State private var scope: PreviewScope = .all
    @State private var isSettingsPresented = false
    @State private var loadFailed = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            preview
        }
        .navigationTitle(textbook.title)
        .toolbar {
            ToolbarItem {
                Button("시험 범위 설정", systemImage: "slider.horizontal.3") {
                    isSettingsPresented = true
                }
                .disabled(document == nil)
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            if let document {
                ExamRangeSettingsView(textbook: textbook, document: document)
            }
        }
        .task {
            guard let loaded = PDFLibrary.document(for: textbook) else {
                loadFailed = true
                return
            }
            document = loaded
            refreshExamDocument()
            if textbook.examPDFPages.isEmpty {
                isSettingsPresented = true
            } else {
                scope = .exam
            }
        }
        .onChange(of: textbook.examPDFPages) {
            refreshExamDocument()
            scope = textbook.examPDFPages.isEmpty ? .all : .exam
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                if let summary = textbook.examRangeSummary {
                    Label("시험 범위: \(summary)", systemImage: "target")
                } else {
                    Label("아직 시험 범위를 정하지 않았어요", systemImage: "target")
                        .foregroundStyle(.secondary)
                }
                if textbook.bookPageOneAt != 1 {
                    Text("책 1쪽 = PDF \(textbook.bookPageOneAt)페이지로 맞춰 두었어요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Picker("미리보기", selection: $scope) {
                Text("전체 \(textbook.pageCount)쪽").tag(PreviewScope.all)
                Text("시험 범위만").tag(PreviewScope.exam)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .disabled(textbook.examPDFPages.isEmpty)
        }
        .padding()
    }

    @ViewBuilder
    private var preview: some View {
        if loadFailed {
            ContentUnavailableView(
                "PDF를 열 수 없어요",
                systemImage: "exclamationmark.triangle",
                description: Text("보관함의 파일이 없어졌을 수 있어요. 교재를 지우고 다시 불러와 주세요.")
            )
        } else if let shown = (scope == .exam ? examDocument : nil) ?? document {
            PDFKitView(document: shown)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func refreshExamDocument() {
        guard let document, !textbook.examPDFPages.isEmpty else {
            examDocument = nil
            return
        }
        examDocument = PDFLibrary.extractPages(textbook.examPDFPages, from: document)
    }
}
