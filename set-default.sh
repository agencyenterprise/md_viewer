#!/usr/bin/env bash
# Make MarkdownViewer the default app for markdown files.
# Run once after installing the .app to /Applications.
set -euo pipefail

BUNDLE_ID="com.gaspari.MarkdownViewer"

# Make sure Launch Services has indexed the app (no-op if already known).
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
"$LSREGISTER" -f /Applications/MarkdownViewer.app >/dev/null 2>&1 || true

# Call LSSetDefaultRoleHandlerForContentType from Swift for every UTI we know
# real-world markdown files identify as.
swift - <<EOF
import Foundation
import CoreServices

let bundleID = "${BUNDLE_ID}" as CFString
let utis = [
    "net.daringfireball.markdown",
    "public.markdown",
    "com.cursor.MarkdownDocument",   // some apps register their own UTI for .md
]
var ok = true
for uti in utis {
    let status = LSSetDefaultRoleHandlerForContentType(uti as CFString, .all, bundleID)
    let label = (status == 0) ? "ok" : "error \(status)"
    print("\(uti): \(label)")
    if status != 0 && status != -10814 /* unknown UTI is fine */ { ok = false }
}
exit(ok ? 0 : 1)
EOF

echo
echo "Default handler now:"
swift - <<'EOF'
import Foundation
import CoreServices
for uti in ["net.daringfireball.markdown", "public.markdown"] {
    let h = LSCopyDefaultRoleHandlerForContentType(uti as CFString, .all)?.takeRetainedValue() as String?
    print("  \(uti) → \(h ?? "(none)")")
}
EOF
