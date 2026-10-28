#!/usr/bin/env bash

set -euo pipefail

URL="${1:-https://rpmtechnik.co.uk/porsche-sales/vehicle/991-2-gt2-rs-mr/}"
OUT_DIR="${2:-${HOME}/Desktop/991-2-gt2-rs-mr}"

mkdir -p "$OUT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$TMP_DIR"

npm init -y >/dev/null 2>&1
npm install playwright >/dev/null 2>&1
npx playwright install chromium >/dev/null 2>&1

cat > scrape-images.js <<'EOF'
const { chromium } = require('playwright');
const fs = require('fs');

const url = process.argv[2];

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  await page.goto(url, {
    waitUntil: 'networkidle',
    timeout: 60000,
  });

  await page.waitForTimeout(3000);

  const imageUrls = await page.evaluate(() => {
    const urls = new Set();

    const addUrl = (candidate) => {
      if (!candidate) return;

      const raw = String(candidate).trim();
      if (!raw) return;
      if (/^(data:|blob:|javascript:)/i.test(raw)) return;

      try {
        const absolute = new URL(raw, window.location.href);
        if (absolute.protocol === 'http:' || absolute.protocol === 'https:') {
          urls.add(absolute.href);
        }
      } catch {
        // Ignore invalid URL values from markup/styles.
      }
    };

    document.querySelectorAll('img').forEach((img) => {
      addUrl(img.currentSrc);
      addUrl(img.src);
      addUrl(img.dataset.src);
      addUrl(img.dataset.lazy);
      if (img.srcset) {
        img.srcset.split(',').forEach((entry) => {
          const src = entry.trim().split(/\s+/)[0];
          addUrl(src);
        });
      }
    });

    document.querySelectorAll('*').forEach((el) => {
      const bg = getComputedStyle(el).backgroundImage;
      if (!bg || bg === 'none') return;
      for (const match of bg.matchAll(/url\((['"]?)(.*?)\1\)/g)) {
        addUrl(match[2]);
      }
    });

    return Array.from(urls).filter(Boolean);
  });

  fs.writeFileSync('images.txt', imageUrls.join('\n'));
  await browser.close();
})();
EOF

node scrape-images.js "$URL"

cd - >/dev/null

cp "$TMP_DIR/images.txt" "$OUT_DIR/images.txt"

i=1
while IFS= read -r img_url; do
  # Defensive skip for any non-http URL that slipped through.
  [[ "$img_url" =~ ^https?:// ]] || continue

  ext="${img_url%%\?*}"
  ext="${ext##*.}"

  case "$ext" in
    jpg|jpeg|png|webp|gif|avif) ;;
    *) ext="jpg" ;;
  esac

  filename="$(printf "%03d.%s" "$i" "$ext")"

  curl -L \
    --fail \
    --silent \
    --show-error \
    --output "$OUT_DIR/$filename" \
    "$img_url" || true

  i=$((i + 1))
done < "$OUT_DIR/images.txt"

echo "Downloaded images to: $OUT_DIR"
echo "Image URL list saved to: $OUT_DIR/images.txt"


