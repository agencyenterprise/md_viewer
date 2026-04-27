import SwiftUI

struct ContentView: View {
    @EnvironmentObject var document: MarkdownDocument

    var body: some View {
        MarkdownWebView(markdown: document.content, fileURL: document.fileURL)
            .navigationTitle(document.title)
    }
}
