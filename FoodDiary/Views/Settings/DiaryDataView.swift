import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DiaryDataView: View {
    private enum Operation: Equatable {
        case export(DiaryExportFile.Format)
        case readBackup(URL)
    }

    @Environment(\.modelContext) private var context
    @State private var operation: Operation?
    @State private var exportFile: DiaryExportFile?
    @State private var isSharing = false
    @State private var isChoosingBackup = false
    @State private var pendingBackup: DiaryBackup?
    @State private var isConfirmingRestore = false
    @State private var isConfirmingClear = false
    @State private var notice: LocalizedStringKey?
    @AccessibilityFocusState private var noticeFocused: Bool

    var body: some View {
        DiaryPage {
            if operation != nil {
                ProgressView("data.preparing")
            }
            if let notice {
                Label(notice, systemImage: "info.circle")
                    .font(.subheadline)
                    .accessibilityFocused($noticeFocused)
                    .onAppear { noticeFocused = true }
            }

            DiaryCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("data.export")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    dataButton("data.exportCSV", symbol: "tablecells") { start(.export(.csv)) }
                    dataButton("data.exportJSON", symbol: "doc.badge.arrow.up") { start(.export(.json)) }
                    Text("data.exportHint")
                        .font(.footnote)
                        .foregroundStyle(DiaryTheme.secondaryText)
                }
            }
            DiaryCard {
                VStack(alignment: .leading, spacing: 10) {
                    dataButton("data.restore", symbol: "arrow.down.doc") { isChoosingBackup = true }
                    Text("data.restoreHint")
                        .font(.footnote)
                        .foregroundStyle(DiaryTheme.secondaryText)
                }
            }
            DiaryCard {
                Button(role: .destructive) {
                    isConfirmingClear = true
                } label: {
                    Label("data.clear", systemImage: "trash")
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
        }
        .disabled(operation != nil)
        .navigationTitle("data.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task(id: operation) {
            guard let operation else { return }
            await prepare(operation)
        }
        .sheet(isPresented: $isSharing, onDismiss: removeExport) {
            if let exportFile {
                DiaryShareSheet(url: exportFile.url) { isSharing = false }
                    .ignoresSafeArea()
            }
        }
        .fileImporter(isPresented: $isChoosingBackup, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): start(.readBackup(url))
            case .failure: show("data.readError")
            }
        }
        .alert("data.restoreConfirm", isPresented: $isConfirmingRestore, presenting: pendingBackup) { backup in
            Button("data.replace", role: .destructive) { restore(backup) }
            Button("common.cancel", role: .cancel) { pendingBackup = nil }
        } message: { backup in
            Text("data.restoreMessage \(backup.recordCount) \(backup.templateCount)")
        }
        .alert("data.clearConfirm", isPresented: $isConfirmingClear) {
            Button("data.clear", role: .destructive, action: clear)
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("data.clearMessage")
        }
    }

    private func dataButton(_ title: LocalizedStringKey, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
        }
        .buttonStyle(DiaryButtonStyle(kind: .secondary))
    }

    private func prepare(_ operation: Operation) async {
        defer { self.operation = nil }
        do {
            switch operation {
            case .export(let format):
                let timeZone = TimeZone.current
                let backup = try DiaryStore(context: context).backup(includingPhotos: format == .json, timeZone: timeZone)
                let file = try await Task.detached(priority: .userInitiated) {
                    try DiaryExportFile(backup: backup, format: format, timeZone: timeZone)
                }.value
                if Task.isCancelled {
                    file.remove()
                    return
                }
                exportFile = file
                isSharing = true
            case .readBackup(let url):
                let backup = try await Task.detached(priority: .userInitiated) {
                    try DiaryBackup.readJSON(from: url)
                }.value
                try Task.checkCancellation()
                pendingBackup = backup
                isConfirmingRestore = true
            }
        } catch where Task.isCancelled {
            return
        } catch DiaryBackup.FormatError.unsupportedVersion {
            show("data.unsupportedVersion")
        } catch DiaryBackup.FormatError.missingPhoto {
            show("data.missingPhoto")
        } catch {
            switch operation {
            case .export: show("data.exportError")
            case .readBackup: show("data.readError")
            }
        }
    }

    private func restore(_ backup: DiaryBackup) {
        defer { pendingBackup = nil }
        do {
            try DiaryStore(context: context).restore(backup)
            show("data.restored")
        } catch {
            show("data.restoreError")
        }
    }

    private func clear() {
        do {
            try DiaryStore(context: context).clearAll()
            show("data.cleared")
        } catch {
            show("data.clearError")
        }
    }

    private func show(_ title: LocalizedStringKey) {
        notice = title
        noticeFocused = true
    }

    private func start(_ operation: Operation) {
        notice = nil
        self.operation = operation
    }

    private func removeExport() {
        exportFile?.remove()
        exportFile = nil
    }
}

private struct DiaryShareSheet: UIViewControllerRepresentable {
    let url: URL
    let onCompletion: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onCompletion() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
