import SwiftUI

// MARK: - Model

/// Open Graph metadata captured from a pasted link.
struct LinkMetadata: Equatable {
    var url: String
    var title: String?
    var description: String?
    var imageUrl: String?
    var siteName: String?

    /// Bare host (strips a leading "www."), used as the fallback site label.
    var host: String? {
        guard let h = URL(string: url)?.host else { return nil }
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }

    /// What to show as the small site label under the title.
    var siteLabel: String { siteName ?? host ?? url }

    /// A card is worth showing once we have at least a title or an image.
    var isDisplayable: Bool {
        (title?.isEmpty == false) || (imageUrl?.isEmpty == false)
    }
}

// MARK: - Fetcher

enum LinkMetadataError: LocalizedError {
    case invalidURL
    case notReachable

    var errorDescription: String? {
        switch self {
        case .invalidURL:   return localized("올바른 링크가 아닙니다.", "That doesn't look like a valid link.", "Das ist kein gültiger Link.")
        case .notReachable: return localized("링크 정보를 불러오지 못했어요.", "Couldn't load link preview.", "Vorschau konnte nicht geladen werden.")
        }
    }
}

enum LinkMetadataFetcher {

    /// Turn loose user input into a canonical https(s) URL string, or nil if it isn't a link.
    static func normalized(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, host.contains(".") else { return nil }
        return candidate
    }

    /// Fetch the page and parse its Open Graph / HTML metadata.
    static func fetch(_ rawURL: String) async throws -> LinkMetadata {
        guard let normalized = normalized(rawURL), let url = URL(string: normalized) else {
            throw LinkMetadataError.invalidURL
        }

        var request = URLRequest(url: url)
        // A desktop-browser UA makes most sites serve their OG tags.
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 12

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LinkMetadataError.notReachable
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw LinkMetadataError.notReachable
        }

        // The URL we landed on after redirects (lnkd.in, t.co, …).
        let finalURL = response.url ?? url
        let html = decodeHTML(data)

        var meta = parse(html: html, baseURL: finalURL)
        meta.url = finalURL.absoluteString
        guard meta.isDisplayable else { throw LinkMetadataError.notReachable }
        return meta
    }

    // MARK: Parsing

    private static func decodeHTML(_ data: Data) -> String {
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .isoLatin1) { return s }
        return String(decoding: data, as: UTF8.self)
    }

    private static func parse(html: String, baseURL: URL) -> LinkMetadata {
        // Only the <head> matters and keeps the regex work small.
        let scope: String = {
            if let end = html.range(of: "</head>", options: .caseInsensitive) {
                return String(html[html.startIndex..<end.upperBound])
            }
            return String(html.prefix(60_000))
        }()

        let tags = metaTags(in: scope)
        func content(_ keys: [String]) -> String? {
            for tag in tags {
                guard let key = (tag.property ?? tag.name)?.lowercased(),
                      keys.contains(key),
                      let value = tag.content, !value.isEmpty else { continue }
                return decodeEntities(value).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return nil
        }

        let title = content(["og:title", "twitter:title"]) ?? titleTag(in: scope)
        let description = content(["og:description", "twitter:description", "description"])
        let siteName = content(["og:site_name", "twitter:site", "application-name"])
        let rawImage = content(["og:image:secure_url", "og:image:url", "og:image", "twitter:image", "twitter:image:src"])
        let imageUrl = rawImage.flatMap { absolute($0, relativeTo: baseURL) }

        return LinkMetadata(
            url: baseURL.absoluteString,
            title: title,
            description: description,
            imageUrl: imageUrl,
            siteName: siteName
        )
    }

    private struct MetaTag { var property: String?; var name: String?; var content: String? }

    private static func metaTags(in html: String) -> [MetaTag] {
        guard let regex = try? NSRegularExpression(pattern: "<meta\\b[^>]*>", options: [.caseInsensitive]) else { return [] }
        let ns = html as NSString
        return regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).map { match in
            let tag = ns.substring(with: match.range)
            return MetaTag(property: attribute("property", in: tag),
                           name: attribute("name", in: tag) ?? attribute("itemprop", in: tag),
                           content: attribute("content", in: tag))
        }
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        let pattern = "\(name)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = tag as NSString
        guard let m = regex.firstMatch(in: tag, range: NSRange(location: 0, length: ns.length)) else { return nil }
        for i in 1...3 where m.range(at: i).location != NSNotFound {
            return ns.substring(with: m.range(at: i))
        }
        return nil
    }

    private static func titleTag(in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "<title[^>]*>([\\s\\S]*?)</title>", options: [.caseInsensitive]) else { return nil }
        let ns = html as NSString
        guard let m = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)),
              m.range(at: 1).location != NSNotFound else { return nil }
        let value = decodeEntities(ns.substring(with: m.range(at: 1))).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func absolute(_ value: String, relativeTo base: URL) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("//") { return (base.scheme ?? "https") + ":" + trimmed }
        if let url = URL(string: trimmed), url.scheme != nil { return url.absoluteString }
        return URL(string: trimmed, relativeTo: base)?.absoluteString
    }

    /// Decode the handful of HTML entities that show up in titles/descriptions.
    private static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text
        let named: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&apos;": "'", "&#39;": "'", "&nbsp;": " ", "&middot;": "·"
        ]
        for (entity, char) in named { result = result.replacingOccurrences(of: entity, with: char) }

        // Numeric references: &#123; and &#x1F600;
        func replaceNumeric(pattern: String, radix: Int) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let ns = result as NSString
            var out = ""
            var last = 0
            for m in regex.matches(in: result, range: NSRange(location: 0, length: ns.length)) {
                out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
                let code = ns.substring(with: m.range(at: 1))
                if let scalarValue = UInt32(code, radix: radix), let scalar = Unicode.Scalar(scalarValue) {
                    out += String(scalar)
                }
                last = m.range.location + m.range.length
            }
            out += ns.substring(from: last)
            result = out
        }
        replaceNumeric(pattern: "&#(\\d+);", radix: 10)
        replaceNumeric(pattern: "&#[xX]([0-9A-Fa-f]+);", radix: 16)
        return result
    }
}

// MARK: - Feed card

/// LinkedIn-style link preview: image on top, title + site below. Tapping opens the link.
struct LinkPreviewCard: View {
    let urlString: String
    var title: String?
    var siteName: String?
    var imageUrl: String?

    @Environment(\.openURL) private var openURL

    private var siteLabel: String {
        LinkMetadata(url: urlString, title: title, description: nil,
                     imageUrl: imageUrl, siteName: siteName).siteLabel
    }

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 0) {
                if let imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        case .empty:
                            Rectangle().fill(Color(.tertiarySystemFill))
                                .overlay { ProgressView() }
                        default:
                            Rectangle().fill(Color(.tertiarySystemFill))
                                .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()

                    Divider()
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title ?? urlString)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(siteLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator).opacity(0.6), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title ?? siteLabel))
        .accessibilityHint(Text(localized("링크 열기", "Open link", "Link öffnen")))
    }

    private func open() {
        guard let url = URL(string: urlString) else { return }
        openURL(url)
    }
}

// MARK: - Composer preview (loading / loaded / error states)

/// Interactive preview shown inside the composer while attaching a link.
struct LinkPreviewComposerCard: View {
    let urlString: String
    let isLoading: Bool
    let metadata: LinkMetadata?
    let errorText: String?
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                thumbnail
                VStack(alignment: .leading, spacing: 3) {
                    if isLoading {
                        Text(localized("링크 정보를 불러오는 중…", "Loading link…", "Link wird geladen…"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else if let metadata, metadata.isDisplayable {
                        Text(metadata.title ?? metadata.siteLabel)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        Text(metadata.siteLabel)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    } else {
                        Text(errorText ?? localized("미리보기를 만들 수 없습니다.", "No preview available.", "Keine Vorschau verfügbar."))
                            .font(.caption).foregroundStyle(.secondary)
                        Text(urlString).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var thumbnail: some View {
        Group {
            if isLoading {
                Rectangle().fill(Color(.tertiarySystemFill)).overlay { ProgressView().scaleEffect(0.7) }
            } else if let imageUrl = metadata?.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Color(.tertiarySystemFill))
                    }
                }
            } else {
                Rectangle().fill(Color(.tertiarySystemFill))
                    .overlay { Image(systemName: "link").foregroundStyle(.secondary) }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
