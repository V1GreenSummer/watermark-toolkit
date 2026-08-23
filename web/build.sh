#!/bin/sh
# Build the wasm-gc artifact and copy it next to the static page.
set -e
cd "$(dirname "$0")/.."
moon build --target wasm-gc --release web/main
cp _build/wasm-gc/release/build/web/main/main.wasm web/main.wasm
node tools/gen_string_imports.mjs web/main.wasm web/string-imports.js
echo "web/main.wasm: $(wc -c < web/main.wasm) bytes"
