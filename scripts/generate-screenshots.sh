#!/usr/bin/env bash
#
# generate-screenshots.sh
# Runs ScreenshotTests, extracts attachments from xcresult, and assembles a GIF.
#
# Usage: ./scripts/generate-screenshots.sh
# Output: docs/screenshots/{01-overview,02-store-detail,...}.png + demo.gif
#

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
RESULT_BUNDLE="$BUILD_DIR/screenshots.xcresult"
OUTPUT_DIR="$ROOT_DIR/docs/screenshots"
ATTACHMENTS_DIR="$BUILD_DIR/attachments"

echo "==> Cleaning previous results..."
rm -rf "$RESULT_BUNDLE" "$ATTACHMENTS_DIR"
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

echo "==> Running ScreenshotTests..."
xcodebuild test \
    -scheme watchify \
    -destination 'platform=macOS' \
    -only-testing:watchifyUITests/ScreenshotTests \
    -resultBundlePath "$RESULT_BUNDLE" \
    2>&1 | tail -20

if [ ! -d "$RESULT_BUNDLE" ]; then
    echo "ERROR: xcresult bundle not found at $RESULT_BUNDLE"
    exit 1
fi

echo "==> Extracting attachments from xcresult..."
xcrun xcresulttool export attachments \
    --path "$RESULT_BUNDLE" \
    --output-path "$ATTACHMENTS_DIR"

if [ ! -d "$ATTACHMENTS_DIR" ]; then
    echo "ERROR: No attachments exported"
    exit 1
fi

echo "==> Processing attachments..."

# Use venv Python if available (for Pillow), else system Python
PYTHON="python3"
if [ -x "$BUILD_DIR/.venv/bin/python3" ]; then
    PYTHON="$BUILD_DIR/.venv/bin/python3"
fi

export ATTACHMENTS_DIR OUTPUT_DIR

# Read manifest to map attachment names to files
"$PYTHON" << 'PYEOF'
import json
import os
import shutil

attachments_dir = os.environ["ATTACHMENTS_DIR"]
output_dir = os.environ["OUTPUT_DIR"]

manifest_path = os.path.join(attachments_dir, "manifest.json")
if not os.path.exists(manifest_path):
    print("ERROR: manifest.json not found in attachments export")
    exit(1)

with open(manifest_path) as f:
    manifest = json.load(f)

gif_frames = []
count = 0

# manifest is a list of test entries, each with an "attachments" array
all_attachments = []
for entry in manifest:
    all_attachments.extend(entry.get("attachments", []))

for att in all_attachments:
    suggested = att.get("suggestedHumanReadableName", "")
    exported_file = att.get("exportedFileName", "")
    if not suggested or not exported_file:
        continue

    # Extract base name from suggested name (e.g., "01-overview_0_UUID.png" -> "01-overview")
    base_name = suggested.split("_0_")[0] if "_0_" in suggested else suggested.replace(".png", "")

    src = os.path.join(attachments_dir, exported_file)
    if not os.path.exists(src):
        print(f"  WARNING: {exported_file} not found, skipping")
        continue

    dst = os.path.join(output_dir, f"{base_name}.png")
    shutil.copy2(src, dst)
    print(f"  Saved: {base_name}.png")
    count += 1

    if base_name.startswith("gif-frame-"):
        gif_frames.append(dst)

print(f"\nExtracted {count} screenshots")

# Assemble GIF from frames: Activity first (frame 006) at 2x duration
if gif_frames:
    gif_frames.sort()
    try:
        from PIL import Image

        # Reorder: Activity (frame 006) first, then normal order
        activity = [f for f in gif_frames if "gif-frame-006" in f]
        others = [f for f in gif_frames if "gif-frame-006" not in f]
        ordered = activity + others

        images = [Image.open(f) for f in ordered]
        base_ms = 1500
        durations = [base_ms * 2] + [base_ms] * (len(images) - 1)

        gif_path = os.path.join(output_dir, "demo.gif")
        images[0].save(
            gif_path,
            save_all=True,
            append_images=images[1:],
            duration=durations,
            loop=0
        )
        print(f"Assembled demo.gif ({len(ordered)} frames, Activity first @ 2x)")
    except ImportError:
        print("Pillow not installed — GIF frames saved as individual PNGs.")
        print("Install with: uv pip install Pillow")
PYEOF

echo ""
echo "==> Done! Screenshots saved to docs/screenshots/"
ls -la "$OUTPUT_DIR"
