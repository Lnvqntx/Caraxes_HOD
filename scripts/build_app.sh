#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
root="$PWD"
app="$root/Caraxes.app"

if [[ "$(uname -s)" != Darwin ]]; then
    printf '%s\n' 'Caraxes requires macOS and the Apple Command Line Tools.' >&2
    exit 1
fi

swift build -c release >&2
bin_dir="$(swift build -c release --show-bin-path)"
stage="$(mktemp -d "$root/.build/caraxes-app.XXXXXX")"
trap 'rm -rf "$stage"' EXIT

bundle="$stage/Caraxes.app"
contents="$bundle/Contents"
mkdir -p "$contents/MacOS" "$contents/Resources"
install -m 755 "$bin_dir/Caraxes" "$contents/MacOS/Caraxes"
install -m 644 Caraxes/Resources/caraxes.png "$contents/Resources/caraxes.png"

plist="$contents/Info.plist"
sed -e 's/$(DEVELOPMENT_LANGUAGE)/en/g' \
    -e 's/$(EXECUTABLE_NAME)/Caraxes/g' \
    -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/com.lnvqntx.Caraxes/g' \
    -e 's/$(PRODUCT_NAME)/Caraxes/g' \
    -e 's/$(MARKETING_VERSION)/0.1.0/g' \
    -e 's/$(CURRENT_PROJECT_VERSION)/1/g' \
    -e 's/$(MACOSX_DEPLOYMENT_TARGET)/12.0/g' \
    Caraxes/Info.plist > "$plist"
plutil -lint "$plist" >&2

codesign --force --sign - "$bundle"
codesign --verify --strict "$bundle"

rm -rf "$app"
mv "$bundle" "$app"
printf '%s\n' "$app"
