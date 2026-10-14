#!/usr/bin/env bash
# Paste conversion: HTML and RTF, as the clipboard carries them, to Markdown.
set -euo pipefail
cd "$(dirname "$0")/.."
T=$(mktemp -d); cp tests/pastetest.swift "$T/main.swift"
swiftc -O Sources/Glassine/Editor/PasteMarkdown.swift "$T/main.swift" -o "$T/pastetest"
"$T/pastetest"
