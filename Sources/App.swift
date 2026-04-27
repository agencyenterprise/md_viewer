import SwiftUI
import AppKit

@main
struct MarkdownViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.document)
                .frame(minWidth: 700, minHeight: 500)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { appDelegate.document.openFileDialog() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Reload") { appDelegate.document.reload() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(appDelegate.document.fileURL == nil)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let document = MarkdownDocument()

    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first { document.load(url: url) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
