#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
source_dir="$PWD"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/local-search-build.XXXXXX")"
swiftc -O -parse-as-library "$source_dir/Search.swift" "$source_dir/App.swift" -o "$build_dir/LocalSearch"
swiftc -O "$source_dir/make_icon.swift" -o "$build_dir/make-icon"
"$build_dir/make-icon" "$build_dir/AppIcon.iconset"
iconutil --convert icns --output "$build_dir/AppIcon.icns" "$build_dir/AppIcon.iconset"
cd "$build_dir"
mkdir -p "本地搜索.app/Contents/MacOS" "本地搜索.app/Contents/Resources"
mv "LocalSearch" "本地搜索.app/Contents/MacOS/LocalSearch"
cp "AppIcon.icns" "本地搜索.app/Contents/Resources/AppIcon.icns"
cat > "本地搜索.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LocalSearch</string>
<key>CFBundleIdentifier</key><string>local.filesearch.desktop</string>
<key>CFBundleName</key><string>本地搜索</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleIconName</key><string>AppIcon</string>
</dict></plist>
PLIST
xattr -cr "本地搜索.app"
codesign --force --sign - "本地搜索.app"
ditto "本地搜索.app" "$source_dir/本地搜索.app"
sips -s format png "$source_dir/本地搜索.app/Contents/Resources/AppIcon.icns" --out "$source_dir/AppIcon-preview.png" >/dev/null
ditto -c -k --sequesterRsrc --keepParent "本地搜索.app" "$source_dir/本地搜索-Mac.zip"
print "构建完成：本地搜索.app"
