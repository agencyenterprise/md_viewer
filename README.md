<div align="center">
  <img src="assets/logo.png" alt="MarkdownViewer" width="160" />
  <h1>MarkdownViewer</h1>
  <p>A native macOS markdown viewer that renders the way GitHub does.</p>
</div>

---

MarkdownViewer is a tiny, native macOS app for previewing markdown files. It
ships with a Quick Look extension so pressing the Space bar in Finder shows a
fully styled preview — code highlighting, tables, task lists, images, the
works — without opening anything.

It is intentionally simple: open a file, see it rendered. No editor, no Markdown
flavor toggle, no settings panel.

## Features

- GitHub-flavored markdown rendering (tables, task lists, fenced code, autolinks)
- GitHub styling via `github-markdown-css`
- Syntax highlighting via `highlight.js`
- Light / dark mode follows the system
- **Live reload** — edit the file in any editor and the view updates automatically
- **Quick Look extension** — Space-bar preview in Finder, fully sandboxed
- **Inline images** — local relative paths and remote URLs both work
- External links open in the default browser

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)

That's it. No Xcode app, no Swift package manager.

## Build & install

```sh
./build.sh
cp -R build/MarkdownViewer.app /Applications/
```

`build.sh` downloads `marked.js`, `github-markdown-css`, and `highlight.js` on
first run, compiles the Swift sources, packages everything into
`MarkdownViewer.app`, and signs the app and its preview extension ad-hoc.

To activate the Quick Look extension, the app needs to be in `/Applications`
and registered with Launch Services:

```sh
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
    -f /Applications/MarkdownViewer.app
pluginkit -a /Applications/MarkdownViewer.app/Contents/PlugIns/MarkdownPreview.appex
```

## Make it the default for `.md` files

macOS remembers per-user defaults for file types, so even after install another
app (e.g. Cursor, VS Code) may still own `.md`. To switch:

```sh
./set-default.sh
```

This calls `LSSetDefaultRoleHandlerForContentType` for the markdown UTIs the
common editors register. Re-run any time another app reclaims the default.

## Usage

- **⌘O** — open a file
- **⌘R** — reload (also happens automatically when the file changes on disk)
- Drop a `.md` onto the Dock icon, or right-click in Finder → *Open With → MarkdownViewer*
- **Space-bar** in Finder for an instant Quick Look preview

## Project layout

```
md_viewer/
├── Sources/
│   ├── App.swift                  # SwiftUI App + AppDelegate (Apple Events)
│   ├── ContentView.swift
│   ├── Document.swift             # File loading + on-disk live reload
│   ├── WebView.swift              # WKWebView host
│   ├── Shared/
│   │   └── MarkdownRenderer.swift # md → HTML, inlines local images as data URLs
│   └── PreviewExtension/
│       ├── PreviewViewController.swift   # QLPreviewingController
│       └── extension_main.c              # NSExtensionMain entry point
├── Resources/
│   └── template.html              # rendering shell (vendored CSS/JS gets inlined)
├── PreviewExtension/
│   ├── Info.plist
│   └── MarkdownPreview.entitlements
├── Info.plist                     # main app bundle metadata
├── build.sh                       # download deps, compile, package, sign
├── set-default.sh                 # set as default .md handler
├── assets/
│   └── logo.png
└── LICENSE
```

## How it works

The renderer is intentionally not a Swift markdown parser. Instead the Swift
side builds a self-contained HTML page (CSS + `marked.js` + `highlight.js` are
inlined as `<style>` and `<script>` blocks) and hands it to `WKWebView`. The
markdown is delivered to the browser as a JSON-encoded string and parsed by
`marked` at render time.

Local image references (`![alt](path.png)`) are resolved on the Swift side
*before* rendering: the file is read from disk, base64-encoded, and rewritten
into the markdown as a `data:` URL. This sidesteps the sandbox boundary the
Quick Look extension lives behind — the WebContent process never has to
follow a `file://` URL.

The Quick Look preview extension is sandboxed (a hard requirement — `pkd`
refuses to register non-sandboxed extensions). It declares a temporary
read-only file-access exception scoped to `/Users/` so it can resolve
relative-path images sitting next to a `.md` file.

## Running the test files

The repo includes two sample markdown files used to verify the build:

- `sample.md` — covers headings, code blocks, tables, task lists, blockquotes
- `sample-with-images.md` — exercises both local (`test-image.png`, inlined as
  a data URL) and remote (`shields.io` badge, fetched over the network)
  images

After install:

```sh
open sample-with-images.md
```

Then press Space on the same file in Finder to verify the Quick Look path.

## License

[MIT](LICENSE) © Tiago De Gaspari

## Credits

- [marked](https://marked.js.org) — markdown parser
- [github-markdown-css](https://github.com/sindresorhus/github-markdown-css) — styling
- [highlight.js](https://highlightjs.org) — syntax highlighting
