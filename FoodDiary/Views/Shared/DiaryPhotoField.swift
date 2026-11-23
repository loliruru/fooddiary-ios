import PhotosUI
import SwiftUI

struct DiaryPhotoField: View {
    var previousPath: String?
    @Binding var photo: PhotoChange
    @Binding var isLoading: Bool
    @State private var selection: PhotosPickerItem?
    @State private var importTask: Task<Void, Never>?
    @State private var importFailed = false

    private var data: Data? {
        switch photo {
        case .keep: previousPath.flatMap(DiaryPhotos.local.data(for:))
        case .replace(let data): data
        case .copy(let path): DiaryPhotos.local.data(for: path)
        case .remove: nil
        }
    }

    private var hasPhoto: Bool {
        switch photo {
        case .keep: previousPath != nil
        case .replace, .copy: true
        case .remove: false
        }
    }

    var body: some View {
        if let data, let image = UIImage(data: data) {
            DiaryPhotoPreview(image: image)
        }

        PhotosPicker(selection: $selection, matching: .images) {
            Label(hasPhoto ? "photo.replace" : "photo.choose", systemImage: "photo")
        }
        .onChange(of: selection) { _, item in
            guard let item else { return }
            importTask?.cancel()
            isLoading = true
            importTask = Task {
                defer {
                    if !Task.isCancelled {
                        isLoading = false
                        selection = nil
                    }
                }
                do {
                    guard let original = try await item.loadTransferable(type: Data.self) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    try Task.checkCancellation()
                    let data = try await Task.detached(priority: .userInitiated) {
                        try DiaryPhotos.jpeg(from: original)
                    }.value
                    try Task.checkCancellation()
                    photo = .replace(data)
                } catch {
                    if !Task.isCancelled { importFailed = true }
                }
            }
        }
        .onDisappear {
            importTask?.cancel()
            isLoading = false
            selection = nil
        }
        .alert("photo.error", isPresented: $importFailed) {
            Button("common.done", role: .cancel) {}
        }

        if isLoading {
            ProgressView("photo.loading")
        } else if hasPhoto {
            Button("photo.remove", role: .destructive) { photo = .remove }
        }
    }
}

struct DiaryPhotoPreview: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: 280)
            .clipShape(.rect(cornerRadius: 12))
            .accessibilityLabel("photo.image")
    }
}
