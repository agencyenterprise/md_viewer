import Foundation

enum MarkdownRenderer {
    /// Builds a self-contained HTML page (all JS/CSS inlined) for `markdown`,
    /// using assets shipped in `bundle`.
    ///
    /// Inlining matters for sandboxed Quick Look extensions: the Web Content
    /// sub-process can't read resources via a `file://` baseURL across the
    /// sandbox boundary, so the page would never finish loading.
    ///
    /// `baseDirectory` is the directory of the source `.md` file, used to
    /// resolve and inline local image references (sibling files). Pass `nil`
    /// when there is no source file (e.g. the welcome screen).
    static func html(for markdown: String, bundle: Bundle, baseDirectory: URL? = nil) -> String {
        let preprocessed = inlineLocalImages(in: markdown, baseDirectory: baseDirectory)

        let template = readResource("template", "html", in: bundle) ?? fallbackTemplate
        let markedJS = sanitizeJS(readResource("marked.min", "js", in: bundle) ?? "")
        let highlightJS = sanitizeJS(readResource("highlight.min", "js", in: bundle) ?? "")
        let markdownCSS = readResource("github-markdown", "css", in: bundle) ?? ""
        let highlightLightCSS = readResource("github-highlight-light", "css", in: bundle) ?? ""
        let highlightDarkCSS = readResource("github-highlight-dark", "css", in: bundle) ?? ""

        let payload: String
        if let data = try? JSONEncoder().encode(preprocessed),
           let str = String(data: data, encoding: .utf8) {
            payload = str
        } else {
            payload = "\"\""
        }

        return template
            .replacingOccurrences(of: "/*__GITHUB_MARKDOWN_CSS__*/", with: markdownCSS)
            .replacingOccurrences(of: "/*__HIGHLIGHT_LIGHT_CSS__*/", with: highlightLightCSS)
            .replacingOccurrences(of: "/*__HIGHLIGHT_DARK_CSS__*/", with: highlightDarkCSS)
            .replacingOccurrences(of: "/*__MARKED_JS__*/", with: markedJS)
            .replacingOccurrences(of: "/*__HIGHLIGHT_JS__*/", with: highlightJS)
            .replacingOccurrences(of: "\"__MARKDOWN_PAYLOAD__\"", with: payload)
    }

    /// Rewrites image references whose path points to a local file into
    /// base64-encoded `data:` URLs. Handles both markdown `![alt](path)` and
    /// inline HTML `<img src="path">`. Remote (http/https) and already-`data:`
    /// URLs pass through untouched.
    private static func inlineLocalImages(in markdown: String, baseDirectory: URL?) -> String {
        // Pass 1: markdown ![alt](path) — alt may be empty, path has no
        // whitespace or paren. (Doesn't cover every CommonMark edge case.)
        var result = rewriteMatches(
            in: markdown,
            pattern: #"!\[([^\]]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)"#,
            pathGroup: 2,
            baseDirectory: baseDirectory
        ) { full, dataURL, ranges in
            let alt = String(full[ranges[1]])
            return "![\(alt)](\(dataURL))"
        }

        // Pass 2: inline HTML <img src="path" …> — covers both single- and
        // double-quoted src attributes in any order with the rest of the
        // attributes preserved.
        result = rewriteMatches(
            in: result,
            pattern: #"(<img\b[^>]*?\bsrc\s*=\s*['"])([^'"]+)(['"][^>]*>)"#,
            pathGroup: 2,
            baseDirectory: baseDirectory
        ) { full, dataURL, ranges in
            let prefix = String(full[ranges[1]])
            let suffix = String(full[ranges[3]])
            return "\(prefix)\(dataURL)\(suffix)"
        }

        return result
    }

    /// Generic replace-loop used by `inlineLocalImages`. Walks regex matches
    /// in reverse so substitutions don't invalidate earlier ranges, reads the
    /// file at the captured path (skipping remote / data URLs), and asks the
    /// caller to rebuild the surrounding syntax.
    private static func rewriteMatches(
        in source: String,
        pattern: String,
        pathGroup: Int,
        baseDirectory: URL?,
        rebuild: (Substring, String, [Range<String.Index>]) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return source
        }

        var result = source
        let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let pathRange = Range(match.range(at: pathGroup), in: result) else { continue }

            let path = String(result[pathRange])
            if path.hasPrefix("http://") || path.hasPrefix("https://") || path.hasPrefix("data:") {
                continue
            }

            let imageURL: URL
            if path.hasPrefix("/") {
                imageURL = URL(fileURLWithPath: path)
            } else if let baseDirectory = baseDirectory {
                imageURL = baseDirectory.appendingPathComponent(path)
            } else {
                continue
            }

            guard let data = try? Data(contentsOf: imageURL) else { continue }
            let mime = mimeType(forExtension: imageURL.pathExtension)
            let dataURL = "data:\(mime);base64,\(data.base64EncodedString())"

            // Hand the caller the substring + per-group ranges so it can
            // reconstruct whatever syntax produced the match.
            var groupRanges: [Range<String.Index>] = []
            for i in 0..<match.numberOfRanges {
                groupRanges.append(Range(match.range(at: i), in: result) ?? fullRange)
            }
            let replacement = rebuild(result[fullRange], dataURL, groupRanges)
            result.replaceSubrange(fullRange, with: replacement)
        }
        return result
    }

    private static func mimeType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "png":          return "image/png"
        case "jpg", "jpeg":  return "image/jpeg"
        case "gif":          return "image/gif"
        case "svg":          return "image/svg+xml"
        case "webp":         return "image/webp"
        case "bmp":          return "image/bmp"
        case "ico":          return "image/x-icon"
        case "tiff", "tif":  return "image/tiff"
        case "heic":         return "image/heic"
        default:             return "application/octet-stream"
        }
    }

    private static func readResource(_ name: String, _ ext: String, in bundle: Bundle) -> String? {
        guard let url = bundle.url(forResource: name, withExtension: ext) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Prevent a `</script>` token inside the JS source from terminating the
    /// surrounding `<script>` tag once we inline it into HTML.
    private static func sanitizeJS(_ js: String) -> String {
        js.replacingOccurrences(of: "</script>", with: "<\\/script>")
    }

    private static let fallbackTemplate = """
    <!doctype html><html><body><pre id="c"></pre>
    <script>document.getElementById('c').textContent = "__MARKDOWN_PAYLOAD__";</script>
    </body></html>
    """
}
