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

# Modules managed by SPM — MUST be excluded to prevent slice conflicts.
# SwiftProtobuf is NOT excluded — we use the copy inside FlowKit.xcframework
# to avoid duplicate ObjC class registrations that cause silent protobuf
# casting failures when Xcode builds the app with a debug dylib.
EXCLUDE="FlowKit.swiftmodule"

# Search known xcframework locations.
# Three resolver layouts to cover:
#   - swift build       → $PACKAGE_DIR/.build/artifacts/<pkg>/FlowKit/
#   - xcodebuild default DerivedData → $HOME/Library/Developer/Xcode/DerivedData/<proj>-<hash>/SourcePackages/artifacts/<pkg>/FlowKit/
#   - xcodebuild -clonedSourcePackagesDirPath PATH → PATH/artifacts/<pkg>/FlowKit/
#   - xcodebuild -derivedDataPath PATH → PATH/SourcePackages/artifacts/<pkg>/FlowKit/
# <pkg> varies by manifest name (wasmclient, flow-kit, flowkitpackage).
PKG_NAMES=("wasmclient" "flow-kit" "flowkitpackage")
XCFW=""

find_in_root() {
  local root="$1"
  local variant
  local owner
  for variant in "SourcePackages/artifacts" "artifacts"; do
    for owner in "${PKG_NAMES[@]}"; do
      local candidate="$root/$variant/$owner/FlowKit/FlowKit.xcframework"
      if [ -d "$candidate" ]; then
        echo "$candidate"
        return 0
      fi
    done
  done
  return 1
}

# 1) WasmClient-local checkouts.
for owner in "${PKG_NAMES[@]}"; do
  candidate="$PACKAGE_DIR/.build/artifacts/$owner/FlowKit/FlowKit.xcframework"
  if [ -d "$candidate" ]; then XCFW="$candidate"; break; fi
done

# 2) Sibling-package artifacts dir (older layouts).
if [ -z "$XCFW" ]; then
  for owner in "${PKG_NAMES[@]}"; do
    candidate="$PACKAGE_DIR/../../artifacts/$owner/FlowKit/FlowKit.xcframework"
    if [ -d "$candidate" ]; then XCFW="$candidate"; break; fi
  done
fi

# 3) Xcode build env vars (when invoked as a build phase / SPM plugin).
#    BUILD_DIR usually = .../Build/Products/<config>-<sdk>; SourcePackages sits
#    next to Build/. OBJROOT = .../Build/Intermediates.noindex. Walk a couple
#    of parent levels in case Xcode's layout changes.
if [ -z "$XCFW" ]; then
  ENV_ROOTS=()
  [ -n "${BUILD_DIR:-}" ] && ENV_ROOTS+=("$BUILD_DIR/../.." "$BUILD_DIR/..")
  [ -n "${OBJROOT:-}" ]   && ENV_ROOTS+=("$OBJROOT/..")
  [ -n "${SYMROOT:-}" ]   && ENV_ROOTS+=("$SYMROOT/..")
  if [ "${#ENV_ROOTS[@]}" -gt 0 ]; then
    for envroot in "${ENV_ROOTS[@]}"; do
      candidate=$(find_in_root "$envroot" || true)
      if [ -n "$candidate" ]; then XCFW="$candidate"; break; fi
    done
  fi
fi

# 4) Broad fallback — find under known DerivedData / temp roots.
#    Capped maxdepth keeps this cheap even when /tmp is busy.
if [ -z "$XCFW" ]; then
  while IFS= read -r candidate; do
    if [ -d "$candidate" ]; then XCFW="$candidate"; break; fi
  done < <(find \
    "$HOME/Library/Developer/Xcode/DerivedData" \
    "${TMPDIR:-/tmp}" \
    /tmp \
    -maxdepth 8 \
    \( -path '*/SourcePackages/artifacts/*/FlowKit/FlowKit.xcframework' \
       -o -path '*/artifacts/*/FlowKit/FlowKit.xcframework' \) \
    -type d 2>/dev/null | sort -u)
fi

if [ -z "$XCFW" ]; then
  echo "warning: FlowKit.xcframework not found — sub-modules will not be available." >&2
  mkdir -p "$OUTPUT_DIR"
  exit 0
fi

# Fingerprint the source xcframework so the early-exit check can detect when
# FlowKit has been bumped and the merged symlinks are stale. The Info.plist
# changes whenever the version, slices, or available libraries change, which
# is sufficient to catch the cases the stamp needs to invalidate on.
FINGERPRINT="$XCFW|$(/usr/bin/shasum -a 256 "$XCFW/Info.plist" 2>/dev/null | awk '{print $1}')"

# If a sibling target already populated the merged tree, no work to do —
# provided the fingerprint matches and no symlink in the tree is broken.
# Either condition failing means a FlowKit bump (or cache wipe) left stale
# links pointing at a previous xcframework layout; re-merge to fix it.
if [ -d "$OUTPUT_DIR" ] && [ -f "$OUTPUT_DIR/.merge-stamp" ] && \
   find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -name '*.swiftmodule' -print -quit | grep -q . && \
   [ "$(cat "$OUTPUT_DIR/.merge-stamp" 2>/dev/null)" = "$FINGERPRINT" ] && \
   ! find -L "$OUTPUT_DIR" -type l -print -quit 2>/dev/null | grep -q .; then
  echo "FlowKit sub-modules already merged at $OUTPUT_DIR"
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

printf '%s' "$FINGERPRINT" > "$OUTPUT_DIR/.merge-stamp"
echo "Merged $count sub-modules into $OUTPUT_DIR"
