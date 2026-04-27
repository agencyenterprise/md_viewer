import Cocoa
import Quartz
import WebKit

@objc(PreviewViewController)
final class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {
    private var webView: WKWebView!
    private var pendingCompletion: ((Error?) -> Void)?

    override var nibName: NSNib.Name? { nil }

    override func loadView() {
        let frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        let webView = WKWebView(frame: frame)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self
        self.webView = webView
        self.view = webView
        self.preferredContentSize = frame.size
    }

    func preparePreviewOfFile(at url: URL,
                              completionHandler handler: @escaping (Error?) -> Void) {
        let bundle = Bundle(for: type(of: self))
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            let markdown = try String(contentsOf: url, encoding: .utf8)
            let baseDir = url.deletingLastPathComponent()
            let html = MarkdownRenderer.html(for: markdown, bundle: bundle, baseDirectory: baseDir)
            pendingCompletion = handler
            // baseURL = nil — everything (CSS/JS, plus local images already
            // base64-inlined by the renderer) is in the HTML string.
            webView.loadHTMLString(html, baseURL: nil)

            // Safety net: if didFinish never fires, signal the QL window
            // anyway after 3s so the user doesn't see an infinite spinner.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self, let pending = self.pendingCompletion else { return }
                self.pendingCompletion = nil
                pending(nil)
            }
        } catch {
            handler(error)
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Allow the initial loadHTMLString and same-document anchor jumps.
        // External links from inside Quick Look are forwarded to the system
        // default app rather than swapping out the preview content.
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url, url.scheme != "about" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finish(error: nil)
    }

    func webView(_ webView: WKWebView,
                 didFail navigation: WKNavigation!,
                 withError error: Error) {
        finish(error: error)
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        finish(error: error)
    }

    private func finish(error: Error?) {
        guard let handler = pendingCompletion else { return }
        pendingCompletion = nil
        handler(error)
    }
}
