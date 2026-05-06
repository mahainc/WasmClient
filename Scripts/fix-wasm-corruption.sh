#!/usr/bin/env bash
# fix-wasm-corruption.sh
#
# Xcode 26 corrupts .wasm files in xcframework artifacts during
# ProcessXCFramework. This script finds an uncorrupted base.wasm
# from SPM checkouts and replaces all corrupted copies.
#
# Usage: Called as an Xcode postBuildScript. Relies on standard
# Xcode environment variables: SRCROOT, TARGET_BUILD_DIR, BUILD_DIR.
#
# Exit 0 always — a missing wasm is not a build error (the engine
# may download it at runtime).

set -euo pipefail

VALID_MAGIC="0061736d"  # \0asm

# --- Locate uncorrupted source ---

find_good_wasm() {
    local search_dir="$1"
    if [ ! -d "$search_dir" ]; then return 1; fi
    while IFS= read -r -d '' candidate; do
        local header
        header=$(od -A n -t x1 -N 4 "$candidate" 2>/dev/null | tr -d ' ')
        if [ "$header" = "$VALID_MAGIC" ]; then
            echo "$candidate"
            return 0
        fi
    done < <(find "$search_dir" -name "base.wasm" -path "*/Wasm_AsyncWasmKit.bundle/*" -print0 2>/dev/null)
    return 1
}

GOOD_SRC=""

# 1) Xcode SourcePackages/checkouts (Xcode-managed workspace)
if [ -z "$GOOD_SRC" ]; then
    GOOD_SRC=$(find_good_wasm "${SRCROOT}/../../SourcePackages/checkouts/flow-kit/FlowKit.xcframework" || true)
fi

# 2) Features/.build/checkouts (SPM within the Features local package)
if [ -z "$GOOD_SRC" ]; then
    GOOD_SRC=$(find_good_wasm "${SRCROOT}/../Features/.build/checkouts/flow-kit/FlowKit.xcframework" || true)
fi

# 3) WasmClient's own bundled base.wasm (copied as SPM resource)
if [ -z "$GOOD_SRC" ]; then
    BUNDLED="${SRCROOT}/../Features/.build/checkouts/WasmClient/Sources/WasmClientLive/Resources/base.wasm"
    if [ -f "$BUNDLED" ]; then
        header=$(od -A n -t x1 -N 4 "$BUNDLED" 2>/dev/null | tr -d ' ')
        if [ "$header" = "$VALID_MAGIC" ]; then
            GOOD_SRC="$BUNDLED"
        fi
    fi
fi

if [ -z "$GOOD_SRC" ]; then
    echo "warning: fix-wasm-corruption: no uncorrupted base.wasm found — skipping"
    exit 0
fi

echo "fix-wasm-corruption: using source: $GOOD_SRC"

# --- Replace corrupted copies ---

replace_if_corrupted() {
    local dst="$1"
    if [ ! -f "$dst" ]; then return; fi
    local header
    header=$(od -A n -t x1 -N 4 "$dst" 2>/dev/null | tr -d ' ')
    if [ "$header" != "$VALID_MAGIC" ]; then
        /bin/cp -f "$GOOD_SRC" "$dst"
        echo "fix-wasm-corruption: fixed $dst"
    fi
}

# A) TARGET_BUILD_DIR — the app bundle being built
if [ -n "${TARGET_BUILD_DIR:-}" ]; then
    find "$TARGET_BUILD_DIR" -name "base.wasm" -path "*/Wasm_AsyncWasmKit.bundle/*" 2>/dev/null | while read -r dst; do
        replace_if_corrupted "$dst"
    done
fi

# B) BUILD_DIR — intermediate products and framework copies
if [ -n "${BUILD_DIR:-}" ]; then
    find "$BUILD_DIR" -name "base.wasm" -path "*/Wasm_AsyncWasmKit.bundle/*" 2>/dev/null | while read -r dst; do
        replace_if_corrupted "$dst"
    done
fi

# C) Xcode SourcePackages/artifacts — corrupted at source
ARTIFACTS_DIR="${SRCROOT}/../../SourcePackages/artifacts"
if [ -d "$ARTIFACTS_DIR" ]; then
    find "$ARTIFACTS_DIR" -name "base.wasm" -path "*/Wasm_AsyncWasmKit.bundle/*" 2>/dev/null | while read -r dst; do
        replace_if_corrupted "$dst"
    done
fi

# D) Features/.build/artifacts — SPM artifacts within local package
FEATURES_ARTIFACTS="${SRCROOT}/../Features/.build/artifacts"
if [ -d "$FEATURES_ARTIFACTS" ]; then
    find "$FEATURES_ARTIFACTS" -name "base.wasm" -path "*/Wasm_AsyncWasmKit.bundle/*" 2>/dev/null | while read -r dst; do
        replace_if_corrupted "$dst"
    done
fi

echo "fix-wasm-corruption: done"
exit 0
