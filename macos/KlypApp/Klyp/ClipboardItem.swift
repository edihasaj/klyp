import Foundation
import AppKit
import UniformTypeIdentifiers

enum ClipboardKind: String, Codable, Sendable {
    case text
    case richText
    case image
    case files
    case url
}

struct ClipboardItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let kind: ClipboardKind
    let createdAt: Date
    /// Plain-text payload for text/url, or display caption for image/files.
    let text: String
    /// RTF data for richText kind.
    let rtfData: Data?
    /// Filename of cached image PNG within the app's image cache directory.
    let imageFilename: String?
    /// File system paths for files kind.
    let filePaths: [String]?
    /// Stable hash for dedupe across pasteboard reads.
    let hash: String
    var pinned: Bool
    /// Bundle ID of the app that was frontmost when this item was captured —
    /// used at paste time to apply source-aware transforms (e.g. collapsing
    /// soft-wrap newlines from a narrow terminal window). Nil for items from
    /// older history files.
    let sourceBundleID: String?

    var byteCount: Int {
        var n = text.utf8.count
        if let rtfData { n += rtfData.count }
        if let filePaths { n += filePaths.reduce(0) { $0 + $1.utf8.count } }
        return n
    }
}

extension ClipboardItem {
    static func text(_ s: String, hash: String, sourceBundleID: String? = nil) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .text,
            createdAt: Date(),
            text: s,
            rtfData: nil,
            imageFilename: nil,
            filePaths: nil,
            hash: hash,
            pinned: false,
            sourceBundleID: sourceBundleID
        )
    }

    static func richText(plain: String, rtf: Data, hash: String, sourceBundleID: String? = nil) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .richText,
            createdAt: Date(),
            text: plain,
            rtfData: rtf,
            imageFilename: nil,
            filePaths: nil,
            hash: hash,
            pinned: false,
            sourceBundleID: sourceBundleID
        )
    }

    static func image(filename: String, caption: String, hash: String, sourceBundleID: String? = nil) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .image,
            createdAt: Date(),
            text: caption,
            rtfData: nil,
            imageFilename: filename,
            filePaths: nil,
            hash: hash,
            pinned: false,
            sourceBundleID: sourceBundleID
        )
    }

    static func files(_ paths: [String], caption: String, hash: String, sourceBundleID: String? = nil) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .files,
            createdAt: Date(),
            text: caption,
            rtfData: nil,
            imageFilename: nil,
            filePaths: paths,
            hash: hash,
            pinned: false,
            sourceBundleID: sourceBundleID
        )
    }

    static func url(_ s: String, hash: String, sourceBundleID: String? = nil) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .url,
            createdAt: Date(),
            text: s,
            rtfData: nil,
            imageFilename: nil,
            filePaths: nil,
            hash: hash,
            pinned: false,
            sourceBundleID: sourceBundleID
        )
    }
}
