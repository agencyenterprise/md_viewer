import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class MarkdownDocument: ObservableObject {
    @Published var content: String = MarkdownDocument.welcome
    @Published var fileURL: URL?
    @Published var title: String = "Markdown Viewer"

    private var fileMonitor: DispatchSourceFileSystemObject?

    func openFileDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Open Markdown File"
        var types: [UTType] = []
        if let md = UTType(filenameExtension: "md") { types.append(md) }
        if let markdown = UTType(filenameExtension: "markdown") { types.append(markdown) }
        if let mdown = UTType(filenameExtension: "mdown") { types.append(mdown) }
        if let mkd = UTType(filenameExtension: "mkd") { types.append(mkd) }
        types.append(.plainText)
        panel.allowedContentTypes = types

        if panel.runModal() == .OK, let url = panel.url {
            load(url: url)
        }
    }

    func reload() {
        if let url = fileURL { load(url: url) }
    }

    func load(url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            DispatchQueue.main.async {
                self.content = text
                self.fileURL = url
                self.title = url.lastPathComponent
                NSDocumentController.shared.noteNewRecentDocumentURL(url)
            }
            startMonitoring(url: url)
        } catch {
            DispatchQueue.main.async {
                self.content = "# Error\n\nCould not read `\(url.path)`:\n\n```\n\(error.localizedDescription)\n```"
            }
        }
    }

    private func startMonitoring(url: URL) {
        fileMonitor?.cancel()
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                self.content = text
            } else {
                // Atomic save (rename) — file we were watching is gone. Re-open after a beat.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.load(url: url)
                }
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileMonitor = source
    }

    static let welcome = """
    # Markdown Viewer

    Open a markdown file with **⌘O**, or use *Open With…* in Finder. The file reloads automatically when it changes on disk.

    ## Features

    - GitHub-flavored markdown via [marked](https://marked.js.org)
    - GitHub styling via `github-markdown-css`
    - Syntax highlighting via [highlight.js](https://highlightjs.org)
    - Live reload on file change
    - Light / dark mode follows the system

    ## Code

    ```swift
    struct Greeting {
        let name: String
        func say() { print("Hello, \\(name)!") }
    }
    ```

    ## Tables

    | Column A | Column B | Column C |
    | -------- | :------: | -------: |
    | left     | center   | right    |
    | foo      | bar      | baz      |

    ## Lists

    - [x] Render markdown
    - [x] Style like GitHub
    - [ ] Win the day

    > Tip: drop a `.md` file onto the app icon, or right-click in Finder → *Open With → MarkdownViewer*.
    """
}
