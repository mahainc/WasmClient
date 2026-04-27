#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSIONS_FILE="$ROOT_DIR/Vendor/FlowKitPackage/flowkit-versions.sh"
PACKAGE_FILE="$ROOT_DIR/Package.swift"

if [ ! -f "$VERSIONS_FILE" ]; then
  echo "error: missing $VERSIONS_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$VERSIONS_FILE"

TARGET_XCODE="${1:-}"
if [ -z "$TARGET_XCODE" ]; then
  echo "usage: $0 <26.1.1>" >&2
  exit 1
fi

case "$TARGET_XCODE" in
  26.1.1)
    FLOWKIT_VERSION="$FLOWKIT_VERSION_26_1_1"
    FLOWKIT_CHECKSUM="$FLOWKIT_CHECKSUM_26_1_1"
    ;;
  *)
    echo "error: unsupported Xcode version '$TARGET_XCODE' (expected 26.1.1)" >&2
    exit 1
    ;;
esac

FLOWKIT_URL="https://github.com/mahainc/flow-kit/releases/download/$FLOWKIT_VERSION/FlowKit.xcframework.zip"

python3 - "$PACKAGE_FILE" "$FLOWKIT_URL" "$FLOWKIT_CHECKSUM" <<'PY'
import pathlib
import re
import sys

package_file = pathlib.Path(sys.argv[1])
url = sys.argv[2]
checksum = sys.argv[3]
text = package_file.read_text()

text, version_count = re.subn(
    r'let flowKitVersion = "[^"]+"',
    f'let flowKitVersion = "{url.split("/")[-2]}"',
    text,
    count=1,
)
text, checksum_count = re.subn(
    r'let flowKitChecksum = "[0-9a-f]+"',
    f'let flowKitChecksum = "{checksum}"',
    text,
    count=1,
)

if version_count != 1 or checksum_count != 1:
    raise SystemExit("failed to update FlowKit package manifest")

package_file.write_text(text)
PY

echo "Switched WasmClient FlowKit binary to $FLOWKIT_VERSION for Xcode $TARGET_XCODE"
echo "Run: swift package resolve"
echo "Or build in Xcode/xcodebuild to refresh package artifacts."
