#!/usr/bin/env bash
# Renders the static Play Store graphics into fastlane/metadata/android/:
#   images/featureGraphic.png (1024 × 500, per language) and images/icon.png (512 × 512).
# Needs Google Chrome/Chromium, rsvg-convert (librsvg) and ImageMagick.
set -euo pipefail
cd "$(dirname "$0")/../.."
chrome=$(command -v google-chrome || command -v chromium || command -v chromium-browser)
for pair in de:de-DE en:en-US; do
  lang=${pair%%:*}; locale=${pair#*:}
  out="fastlane/metadata/android/$locale/images"
  mkdir -p "$out"
  "$chrome" --headless=new --no-sandbox --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --window-size=1024,500 --virtual-time-budget=3000 \
    --screenshot="$out/featureGraphic.png" "file://$PWD/tool/store/feature-graphic.html?lang=$lang" 2>/dev/null
  # 24-bit, no alpha – Play rejects transparent feature graphics.
  convert "$out/featureGraphic.png" -background white -alpha remove -alpha off -resize '1024x500!' "$out/featureGraphic.png"
  # Hi-res icon: the full-bleed square master; Play applies its own rounded mask.
  rsvg-convert -w 512 -h 512 assets/icon/icon.svg -o "$out/icon.png"
  echo "$locale: featureGraphic.png, icon.png"
done
