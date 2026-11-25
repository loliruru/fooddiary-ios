import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PhotoChange {
    case keep
    case replace(Data)
    case copy(String)
    case remove
}

struct DiaryPhotos {
    static let dataDirectory = URL.applicationSupportDirectory.appending(path: "FoodDiary", directoryHint: .isDirectory)
    static let local = DiaryPhotos(directory: dataDirectory.appending(path: "Photos", directoryHint: .isDirectory))

    let directory: URL

    static func jpeg(from data: Data) throws -> Data {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1_600
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: 0.85
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return result as Data
    }

    func url(for path: String) -> URL? {
        guard path.hasSuffix(".jpg"), UUID(uuidString: String(path.dropLast(4))) != nil else { return nil }
        return directory.appending(path: path)
    }

    func data(for path: String) -> Data? {
        guard let source = url(for: path) else { return nil }
        return try? Data(contentsOf: source)
    }

    static func isBackupJPEG(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              (CGImageSourceGetType(source) as String?) == UTType.jpeg.identifier,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              (1...1_600).contains(width), (1...1_600).contains(height) else { return false }
        return CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete
    }

    func prepare(_ change: PhotoChange, previous: String?) throws -> String? {
        switch change {
        case .keep: return previous
        case .remove: return nil
        case .replace, .copy:
            let path = UUID().uuidString + ".jpg"
            let destination = directory.appending(path: path)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            do {
                switch change {
                case .replace(let data): try data.write(to: destination, options: .atomic)
                case .copy(let path):
                    guard let source = url(for: path) else { throw CocoaError(.fileReadNoSuchFile) }
                    try FileManager.default.copyItem(at: source, to: destination)
                default: break
                }
            } catch {
                remove(path)
                throw error
            }
            return path
        }
    }

    func remove(_ path: String?) {
        guard let path, let file = url(for: path) else { return }
        try? FileManager.default.removeItem(at: file)
    }

    func removeUnreferenced(keeping paths: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return }
        for file in files where !paths.contains(file.lastPathComponent) {
            remove(file.lastPathComponent)
        }
    }
}
