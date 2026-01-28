#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# Usage
# ------------------------------------------------------------------------------
# Split an MP4 into ~75MB chunks WITHOUT re-encoding (no quality loss).
# The script uses ffmpeg "stream copy" (-c copy), so video/audio quality stays
# exactly the same. Note: chunks may be slightly above/below 75MB because
# splitting happens on keyframes.
#
# Requirements:
#   - macOS + iTerm
#   - ffmpeg/ffprobe installed:
#       brew install ffmpeg
#
# Run:
#   ./split-75mb.sh                 # uses default input: original.mp4
#   ./split-75mb.sh original.mp4    # explicit input file
#   ./split-75mb.sh /path/to/video.mp4
#
# Output:
#   split_75mb/<input_filename_without_ext>/
#     <name>_part_000.mp4
#     <name>_part_001.mp4
#     ...
# ------------------------------------------------------------------------------

set -euo pipefail

INPUT="${1:-original.mp4}"
OUT_DIR="split_75mb"
TARGET_MB=75

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found. Install: brew install ffmpeg"; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo "ffprobe not found. Install: brew install ffmpeg"; exit 1; }

if [[ ! -f "$INPUT" ]]; then
  echo "Input file not found: $INPUT"
  echo "Usage: $0 /path/to/video.mp4"
  exit 1
fi

# Make output folder unique per file
BASENAME="$(basename "$INPUT")"
NAME_NOEXT="${BASENAME%.*}"
OUT_DIR="${OUT_DIR}/${NAME_NOEXT}"

mkdir -p "$OUT_DIR"

# Get average container bitrate (bits/sec). If missing, estimate it using size/duration.
BITRATE="$(ffprobe -v error -show_entries format=bit_rate -of default=nk=1:nw=1 "$INPUT" || true)"

if [[ -z "${BITRATE}" || "${BITRATE}" == "N/A" || "${BITRATE}" == "0" ]]; then
  echo "bit_rate missing; estimating bitrate from file size and duration…"
  SIZE_BYTES="$(stat -f%z "$INPUT")"
  DURATION="$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$INPUT")"
  BITRATE="$(python3 - <<PY
size_bytes=float("$SIZE_BYTES")
duration=float("$DURATION")
print(int((size_bytes*8)/duration))
PY
)"
fi

# Compute segment duration seconds for ~75MB
SEG_SECONDS="$(python3 - <<PY
bitrate=int("$BITRATE")
target_mb=int("$TARGET_MB")
secs=(target_mb*1024*1024*8)/bitrate
# Use floor to bias under target
print(max(1, int(secs)))
PY
)"

echo "Input: $INPUT"
echo "Bitrate (bps): $BITRATE"
echo "Target: ${TARGET_MB}MB"
echo "Segment time: ${SEG_SECONDS}s"
echo "Output dir: $OUT_DIR"
echo

# Split (stream copy: no re-encode, no quality loss)
ffmpeg -hide_banner -i "$INPUT" -map 0 -c copy \
  -f segment -segment_time "$SEG_SECONDS" -reset_timestamps 1 \
  "$OUT_DIR/${NAME_NOEXT}_part_%03d.mp4"

echo
echo "Done. Parts written to: $OUT_DIR/"
ls -lh "$OUT_DIR" | sed -n '1,200p'
