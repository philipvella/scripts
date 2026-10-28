#!/usr/bin/env bash

set -euo pipefail

# Fetch a numbered image range (e.g. ...-1.jpg to ...-50.jpg), skip 403s,
# and keep a list of successfully downloaded image URLs.
BASE_URL="${1:-https://media.rpmtechnik.co.uk/wp-content/uploads/2026/06/991.2-GT2RS-MR}"
START_INDEX="${2:-1}"
END_INDEX="${3:-50}"
OUT_DIR="${4:-${HOME}/Desktop/991.2-GT2RS-MR}"
LIST_FILE="$OUT_DIR/images.txt"

if ! [[ "$START_INDEX" =~ ^[0-9]+$ && "$END_INDEX" =~ ^[0-9]+$ ]]; then
  echo "Error: start and end index must be positive integers." >&2
  exit 1
fi

if (( START_INDEX > END_INDEX )); then
  echo "Error: start index cannot be greater than end index." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
> "$LIST_FILE"

echo "Downloading images from index $START_INDEX to $END_INDEX"
echo "Output directory: $OUT_DIR"

downloaded=0
skipped_403=0
skipped_other=0

for i in $(seq "$START_INDEX" "$END_INDEX"); do
  image_url="${BASE_URL}-${i}.jpg"
  filename="$(basename "$image_url")"
  output_path="$OUT_DIR/$filename"

  http_code="$(curl -L --silent --show-error --output "$output_path" --write-out "%{http_code}" "$image_url" || true)"

  case "$http_code" in
	200)
	  echo "$image_url" >> "$LIST_FILE"
	  downloaded=$((downloaded + 1))
	  echo "OK   [$http_code] $filename"
	  ;;
	403)
	  rm -f "$output_path"
	  skipped_403=$((skipped_403 + 1))
	  echo "SKIP [$http_code] $image_url"
	  ;;
	*)
	  rm -f "$output_path"
	  skipped_other=$((skipped_other + 1))
	  echo "SKIP [$http_code] $image_url"
	  ;;
  esac
done

echo
echo "Done."
echo "Downloaded: $downloaded"
echo "Skipped (403): $skipped_403"
echo "Skipped (other): $skipped_other"
echo "Saved URL list: $LIST_FILE"
