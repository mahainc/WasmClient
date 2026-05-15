#!/bin/bash
# Merge FlowKit XCFramework sub-module interfaces (AsyncWasm, TaskWasm, etc.)
# into a single directory so one -I flag works for all build destinations.
#
# EXCLUDES modules that SPM resolves on its own (FlowKit, SwiftProtobuf) to
# avoid conflicting with Xcode's per-slice framework search paths.
#
# Usage:
#   merge-flowkit-modules.sh <package-dir> <output-dir>
#   merge-flowkit-modules.sh                              # defaults: cwd, .build/flowkit-merged-modules

set -euo pipefail

PACKAGE_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
OUTPUT_DIR="${2:-$PACKAGE_DIR/.build/flowkit-merged-modules}"

# Serialize concurrent invocations from sibling targets that share OUTPUT_DIR
# (e.g. WasmClientLive and WasmClientWebKit). macOS has no flock, so use the
# atomic-`mkdir` pattern. Block until the lock is acquired, release on exit.
mkdir -p "$(dirname "$OUTPUT_DIR")"
LOCK_DIR="${OUTPUT_DIR}.lock"
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
  sleep 0.1
done
trap 'rm -rf "$LOCK_DIR"' EXIT

# If a sibling target already populated the merged tree, no work to do.
if [ -d "$OUTPUT_DIR" ] && [ -f "$OUTPUT_DIR/.merge-stamp" ] && \
   find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -name '*.swiftmodule' -print -quit | grep -q .; then
  echo "FlowKit sub-modules already merged at $OUTPUT_DIR"
  exit 0
fi

# Modules managed by SPM — MUST be excluded to prevent slice conflicts.
# SwiftProtobuf is NOT excluded — we use the copy inside FlowKit.xcframework
# to avoid duplicate ObjC class registrations that cause silent protobuf
# casting failures when Xcode builds the app with a debug dylib.
EXCLUDE="FlowKit.swiftmodule"

# Search known xcframework locations (local dev + dependency consumer).
XCFW=""
for candidate in \
  "$PACKAGE_DIR/.build/artifacts/wasmclient/FlowKit/FlowKit.xcframework" \
  "$PACKAGE_DIR/.build/artifacts/flow-kit/FlowKit/FlowKit.xcframework" \
  "$PACKAGE_DIR/.build/artifacts/flowkitpackage/FlowKit/FlowKit.xcframework" \
  "$PACKAGE_DIR/../../artifacts/wasmclient/FlowKit/FlowKit.xcframework" \
  "$PACKAGE_DIR/../../artifacts/flow-kit/FlowKit/FlowKit.xcframework" \
  "$PACKAGE_DIR/../../artifacts/flowkitpackage/FlowKit/FlowKit.xcframework"; do
  if [ -d "$candidate" ]; then
    XCFW="$candidate"
    break
  fi
done

if [ -z "$XCFW" ]; then
  while IFS= read -r candidate; do
    if [ -d "$candidate" ]; then
      XCFW="$candidate"
      break
    fi
  done < <(find "$HOME/Library/Developer/Xcode/DerivedData" \( -path '*/SourcePackages/artifacts/wasmclient/FlowKit/FlowKit.xcframework' -o -path '*/SourcePackages/artifacts/flowkitpackage/FlowKit/FlowKit.xcframework' \) -type d 2>/dev/null | sort)
fi

if [ -z "$XCFW" ]; then
  echo "warning: FlowKit.xcframework not found — sub-modules will not be available." >&2
  mkdir -p "$OUTPUT_DIR"
  exit 0
fi

DEVICE="$XCFW/ios-arm64/FlowKit.framework/Modules"
# Simulator slice naming changed in FlowKit 1.2.43-ffi (arm64-only, no x86_64).
# Pick whichever slice this xcframework actually ships.
SIMULATOR=""
for sim in "$XCFW/ios-arm64-simulator/FlowKit.framework/Modules" \
           "$XCFW/ios-arm64_x86_64-simulator/FlowKit.framework/Modules"; do
  if [ -d "$sim" ]; then
    SIMULATOR="$sim"
    break
  fi
done

if [ ! -d "$DEVICE" ] || [ -z "$SIMULATOR" ]; then
  echo "warning: FlowKit framework slices missing — sub-modules will not be available." >&2
  mkdir -p "$OUTPUT_DIR"
  exit 0
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

count=0
for mod in "$DEVICE"/*.swiftmodule; do
  name=$(basename "$mod")

  # Skip SPM-managed modules.
  case " $EXCLUDE " in
    *" $name "*) continue ;;
  esac

  mkdir -p "$OUTPUT_DIR/$name"

  # Symlink device architecture files.
  for f in "$mod"/*; do
    ln -sf "$f" "$OUTPUT_DIR/$name/$(basename "$f")"
  done

  # Symlink simulator architecture files.
  simmod="$SIMULATOR/$name"
  if [ -d "$simmod" ]; then
    for f in "$simmod"/*; do
      ln -sf "$f" "$OUTPUT_DIR/$name/$(basename "$f")"
    done
  fi

  count=$((count + 1))
done

touch "$OUTPUT_DIR/.merge-stamp"
echo "Merged $count sub-modules into $OUTPUT_DIR"
