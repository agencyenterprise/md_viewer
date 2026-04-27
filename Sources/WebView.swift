import SwiftUI
import WebKit
import AppKit

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    let fileURL: URL?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let baseDir = fileURL?.deletingLastPathComponent()
        let html = MarkdownRenderer.html(for: markdown, bundle: .main, baseDirectory: baseDir)
        // Dedupe: SwiftUI calls updateNSView whenever any @Published property
        // fires. Reloading the WebView mid-flight cancels the previous
        // navigation and can keep JS from ever finishing.
        if context.coordinator.lastLoadedHTML == html { return }
        context.coordinator.lastLoadedHTML = html
        webView.loadHTMLString(html, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastLoadedHTML: String?

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            // In-document anchor navigation. We load HTML with baseURL=nil, so
            // the document URL is `about:blank` and `[link](#heading)` resolves
            // to `about:blank#heading`. Let WKWebView handle it (it'll scroll
            // to the matching id); we must NOT hand `about:` URLs to
            // NSWorkspace, which has no handler for them.
            if url.scheme == "about" {
                decisionHandler(.allow)
                return
            }
            // Anything else (http/https/mailto/file) → system default app.
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }
    }
}
