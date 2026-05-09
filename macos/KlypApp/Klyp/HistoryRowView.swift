import SwiftUI

struct HistoryRowView: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let onPaste: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            iconBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryText)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .truncationMode(.tail)
                Text(secondaryText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            if item.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tint)
            }
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture(count: 2) { onPaste() }
        .contextMenu {
            Button("Paste", action: onPaste)
            Button(item.pinned ? "Unpin" : "Pin", action: onPin)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    private var badgeSize: CGFloat {
        switch item.kind {
        case .image:
            return 56
        case .files:
            return previewableFilePath != nil ? 56 : 36
        default:
            return 36
        }
    }

    private var previewableFilePath: String? {
        guard let p = item.filePaths?.first, item.filePaths?.count == 1 else { return nil }
        return FileThumbnailLoader.isPreviewable(p) ? p : nil
    }

    @ViewBuilder
    private var iconBadge: some View {
        switch item.kind {
        case .image:
            if let filename = item.imageFilename,
               let nsimg = NSImage(contentsOf: AppPaths.imageCacheDir.appendingPathComponent(filename)) {
                framedThumbnail(nsimg)
            } else {
                fallback("photo")
            }
        case .files:
            if let path = previewableFilePath {
                FileThumbnailView(path: path, size: badgeSize, fallbackSymbol: "doc.on.doc")
            } else {
                fallback("doc.on.doc")
            }
        case .url:
            fallback("link")
        case .richText:
            fallback("textformat.alt")
        case .text:
            fallback("text.alignleft")
        }
    }

    private func framedThumbnail(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: badgeSize, height: badgeSize)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(.background.secondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func fallback(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15))
            .frame(width: badgeSize, height: badgeSize)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(.secondary)
    }

    private var primaryText: String {
        switch item.kind {
        case .image:
            return item.text.isEmpty ? "Image" : item.text
        case .files:
            return item.text
        default:
            return item.text.replacingOccurrences(of: "\n", with: " ⏎ ")
        }
    }

    private var secondaryText: String {
        let kindLabel: String = switch item.kind {
            case .text: "Text"
            case .richText: "Rich text"
            case .image: "Image"
            case .files: "Files"
            case .url: "URL"
        }
        return "\(kindLabel) · \(relativeTime(item.createdAt))"
    }

    private var rowBackground: some ShapeStyle {
        isSelected ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.clear)
    }

    private func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}

struct FileThumbnailView: View {
    let path: String
    let size: CGFloat
    let fallbackSymbol: String
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(.background.secondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(.separator, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: 15))
                    .frame(width: size, height: size)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: path) {
            image = await FileThumbnailLoader.shared.thumbnail(
                for: path,
                size: CGSize(width: size, height: size)
            )
        }
    }
}
