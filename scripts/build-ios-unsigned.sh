#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
build_dir="$PWD/build"
mkdir -p "$build_dir"

xcodegen generate --spec project.yml
xcodebuild \
  -project FoodDiary.xcodeproj \
  -scheme FoodDiary \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$build_dir/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  build

app_path="$build_dir/DerivedData/Build/Products/Release-iphoneos/FoodDiary.app"
if [[ ! -s "$app_path/Info.plist" || ! -x "$app_path/FoodDiary" ]]; then
  echo "Missing app bundle, Info.plist, or executable: $app_path" >&2
  exit 1
fi

package_dir="$(mktemp -d "$build_dir/package.XXXXXX")"
trap 'rm -rf -- "$package_dir"' EXIT

ipa_path="$package_dir/FoodDiary-unsigned.ipa"
mkdir -p "$package_dir/Payload"
ditto "$app_path" "$package_dir/Payload/FoodDiary.app"
ditto -c -k --norsrc --noextattr --keepParent "$package_dir/Payload" "$ipa_path"

unzip -tq "$ipa_path"
unzip -Z -1 "$ipa_path" > "$package_dir/entries.txt"
for entry in Payload/FoodDiary.app/Info.plist Payload/FoodDiary.app/FoodDiary; do
  if ! grep -Fxq "$entry" "$package_dir/entries.txt"; then
    echo "Missing IPA entry: $entry" >&2
    exit 1
  fi
done

mv -f "$ipa_path" "$build_dir/FoodDiary-unsigned.ipa"
echo "Verified unsigned IPA: $build_dir/FoodDiary-unsigned.ipa"
