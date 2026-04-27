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
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
