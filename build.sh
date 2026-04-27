#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="MarkdownViewer"
APP_DIR="build/${APP_NAME}.app"
APP_MACOS="${APP_DIR}/Contents/MacOS"
APP_RES="${APP_DIR}/Contents/Resources"

EXT_NAME="MarkdownPreview"
EXT_DIR="${APP_DIR}/Contents/PlugIns/${EXT_NAME}.appex"
EXT_MACOS="${EXT_DIR}/Contents/MacOS"
EXT_RES="${EXT_DIR}/Contents/Resources"

VENDOR_DIR="Resources/vendor"
mkdir -p "${VENDOR_DIR}"

fetch() {
    local url="$1"
    local out="$2"
    if [ ! -s "${out}" ]; then
        echo "↓ ${out}"
        curl -fsSL "${url}" -o "${out}"
    fi
}

fetch "https://cdn.jsdelivr.net/npm/marked@12.0.2/marked.min.js" \
      "${VENDOR_DIR}/marked.min.js"
fetch "https://cdn.jsdelivr.net/npm/github-markdown-css@5.5.1/github-markdown.css" \
      "${VENDOR_DIR}/github-markdown.css"
fetch "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js" \
      "${VENDOR_DIR}/highlight.min.js"
fetch "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css" \
      "${VENDOR_DIR}/github-highlight-light.css"
fetch "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css" \
      "${VENDOR_DIR}/github-highlight-dark.css"

rm -rf build
mkdir -p "${APP_MACOS}" "${APP_RES}" "${EXT_MACOS}" "${EXT_RES}"

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
TARGET="arm64-apple-macosx13.0"

# ─── main app ──────────────────────────────────────────────────────────────
echo "↻ compiling main app"
swiftc \
    -O \
    -module-name MarkdownViewer \
    -sdk "${SDK_PATH}" \
    -target "${TARGET}" \
    -framework SwiftUI -framework AppKit -framework WebKit \
    -o "${APP_MACOS}/${APP_NAME}" \
    Sources/App.swift \
    Sources/ContentView.swift \
    Sources/Document.swift \
    Sources/WebView.swift \
    Sources/Shared/MarkdownRenderer.swift

cp Info.plist "${APP_DIR}/Contents/Info.plist"
cp Resources/template.html "${APP_RES}/template.html"
cp "${VENDOR_DIR}/"*.js "${VENDOR_DIR}/"*.css "${APP_RES}/"

# ─── preview extension ─────────────────────────────────────────────────────
echo "↻ compiling preview extension"
mkdir -p build/obj
clang -c -arch arm64 -mmacosx-version-min=13.0 \
    -isysroot "${SDK_PATH}" \
    Sources/PreviewExtension/extension_main.c \
    -o build/obj/extension_main.o

swiftc \
    -O \
    -parse-as-library \
    -module-name MarkdownPreview \
    -sdk "${SDK_PATH}" \
    -target "${TARGET}" \
    -framework Cocoa -framework Quartz -framework WebKit \
    -o "${EXT_MACOS}/${EXT_NAME}" \
    Sources/PreviewExtension/PreviewViewController.swift \
    Sources/Shared/MarkdownRenderer.swift \
    build/obj/extension_main.o

cp PreviewExtension/Info.plist "${EXT_DIR}/Contents/Info.plist"
cp Resources/template.html "${EXT_RES}/template.html"
cp "${VENDOR_DIR}/"*.js "${VENDOR_DIR}/"*.css "${EXT_RES}/"

# ─── codesign (ad-hoc) ─────────────────────────────────────────────────────
# Quick Look preview extensions are required to be sandboxed; pkd rejects them
# otherwise. Sign the extension with the sandbox entitlement first, then the
# parent app (signing is inside-out).
codesign --force --sign - \
    --entitlements PreviewExtension/MarkdownPreview.entitlements \
    "${EXT_DIR}"
codesign --force --sign - "${APP_DIR}"

echo "✓ built ${APP_DIR}"
echo "  open with: open ${APP_DIR}"
echo
echo "To enable Quick Look (Space-bar preview):"
echo "  1. cp -R ${APP_DIR} /Applications/"
echo "  2. open /Applications/${APP_NAME}.app    # registers extension with the system"
echo "  3. (macOS 14+) System Settings → General → Login Items & Extensions → Quick Look,"
echo "     toggle 'Markdown Preview' on if needed."
