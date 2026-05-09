import AppKit
import CryptoKit
import Foundation
import QuickLookThumbnailing
import UniformTypeIdentifiers

@MainActor
final class FileThumbnailLoader {
    static let shared = FileThumbnailLoader()
    private init() {}

    private var memoryCache: [String: NSImage] = [:]
    private var negativeCache: Set<String> = []

    static let thumbnailCacheDir: URL = {
        let dir = AppPaths.supportDir.appendingPathComponent("Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func isPreviewable(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return false
        }
        return type.conforms(to: .image)
            || type.conforms(to: .movie)
            || type.conforms(to: .pdf)
            || type.conforms(to: .audiovisualContent)
    }

    func thumbnail(for path: String, size: CGSize) async -> NSImage? {
        if let cached = memoryCache[path] { return cached }
        if negativeCache.contains(path) { return nil }

        if let disk = loadFromDisk(path: path) {
            memoryCache[path] = disk
            return disk
        }

        guard FileManager.default.fileExists(atPath: path) else {
            negativeCache.insert(path)
            return nil
        }

        let url = URL(fileURLWithPath: path)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )

        do {
            let rep = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let img = rep.nsImage
            memoryCache[path] = img
            persistToDisk(image: img, for: path)
            return img
        } catch {
            negativeCache.insert(path)
            return nil
        }
    }

    private func loadFromDisk(path: String) -> NSImage? {
        let url = diskURL(for: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return NSImage(contentsOf: url)
    }

    private func persistToDisk(image: NSImage, for path: String) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: diskURL(for: path))
    }

    private func diskURL(for path: String) -> URL {
        let key = sha(path)
        return Self.thumbnailCacheDir.appendingPathComponent("\(key).png")
    }

    private func sha(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
