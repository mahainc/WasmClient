# Auto Wasm Corruption Fix Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a reusable wasm corruption fix script in the WasmClient package so any XcodeGen project that adds WasmClient to its `Features` package automatically gets the Xcode 26 fix with a one-line postBuildScript reference.

**Architecture:** A portable shell script (`scripts/fix-wasm-corruption.sh`) lives in the WasmClient repo. Consumer projects call it from their `project.yml` postBuildScript using the SPM checkout path. The script uses standard Xcode build environment variables (`SRCROOT`, `TARGET_BUILD_DIR`, `BUILD_DIR`) to locate and replace corrupted `.wasm` files. A companion XcodeGen include file (`xcodegen/wasm-settings.yml`) provides the required `ENABLE_USER_SCRIPT_SANDBOXING: NO` setting.

**Tech Stack:** Bash (POSIX-compatible), XcodeGen YAML, Swift Package Manager

---

## File Structure

```
WasmClient/
├── scripts/
│   ├── merge-flowkit-modules.sh          # existing — unchanged
│   └── fix-wasm-corruption.sh            # NEW — reusable fix script
├── xcodegen/
│   └── wasm-postbuild.yml                # NEW — XcodeGen include snippet
├── Package.swift                          # existing — unchanged
└── docs/
    └── superpowers/plans/
        └── 2026-03-27-auto-wasm-fix-integration.md  # this plan

# Consumer project (e.g., ScanAnything):
app761-scan-anything/
├── ScanAnything/project.yml               # MODIFY — replace inline script with shared reference
└── Features/Package.swift                 # existing — unchanged (already has WasmClient)
```

---

### Task 1: Create the Reusable Fix Script

**Files:**
- Create: `scripts/fix-wasm-corruption.sh`

This script replaces the inline postBuildScript currently hardcoded in ScanAnything's `project.yml`. It must be generic — working for any consumer project regardless of directory structure.

- [ ] **Step 1: Create `scripts/fix-wasm-corruption.sh`**

```bash
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
```

- [ ] **Step 2: Make the script executable**

Run: `chmod +x scripts/fix-wasm-corruption.sh`

- [ ] **Step 3: Verify the script is valid bash**

Run: `bash -n scripts/fix-wasm-corruption.sh`
Expected: No output (syntax OK)

- [ ] **Step 4: Commit**

```bash
git add scripts/fix-wasm-corruption.sh
git commit -m "feat: add reusable fix-wasm-corruption.sh for Xcode 26 wasm artifact bug"
```

---

### Task 2: Create XcodeGen Include File

**Files:**
- Create: `xcodegen/wasm-postbuild.yml`

This file provides a reusable XcodeGen snippet that consumer projects reference from their `project.yml`. It defines the postBuildScript and required build settings in one place.

- [ ] **Step 1: Create `xcodegen/wasm-postbuild.yml`**

```yaml
# xcodegen/wasm-postbuild.yml
#
# XcodeGen include for projects that consume WasmClient via a Features package.
#
# Usage in your project.yml:
#
#   settings:
#     base:
#       ENABLE_USER_SCRIPT_SANDBOXING: NO    # required for fix script
#
#   targets:
#     YourApp:
#       postBuildScripts:
#         - name: Fix Wasm Resource
#           script: |
#             SCRIPT="${SRCROOT}/../Features/.build/checkouts/WasmClient/scripts/fix-wasm-corruption.sh"
#             [ -x "$SCRIPT" ] && "$SCRIPT" || echo "warning: fix-wasm-corruption.sh not found at $SCRIPT"
#           basedOnDependencyAnalysis: false
#
# Requirements:
#   1. ENABLE_USER_SCRIPT_SANDBOXING: NO  (project-level setting)
#   2. Features package at ../Features that depends on WasmClient
#   3. XcodeGen project (traditional PBXFileReference format)
```

- [ ] **Step 2: Commit**

```bash
git add xcodegen/wasm-postbuild.yml
git commit -m "docs: add XcodeGen integration guide for wasm fix"
```

---

### Task 3: Update ScanAnything to Use Shared Script

**Files:**
- Modify: `/Users/thanhhaikhong/Documents/app761-scan-anything/ScanAnything/project.yml:74-110`

Replace the 35-line inline fix script with a 3-line reference to the shared script.

- [ ] **Step 1: Replace inline postBuildScript in ScanAnything's project.yml**

Replace the entire `postBuildScripts:` block (lines 74-110) with:

```yaml
    postBuildScripts:
      - name: Fix Wasm Resource
        script: |
          SCRIPT="${SRCROOT}/../Features/.build/checkouts/WasmClient/scripts/fix-wasm-corruption.sh"
          [ -x "$SCRIPT" ] && "$SCRIPT" || echo "warning: fix-wasm-corruption.sh not found at $SCRIPT"
        basedOnDependencyAnalysis: false
```

The `SRCROOT` points to `app761-scan-anything/ScanAnything/`, so `../Features/.build/checkouts/WasmClient/` resolves to the SPM checkout of WasmClient inside the Features package.

- [ ] **Step 2: Verify `ENABLE_USER_SCRIPT_SANDBOXING: NO` is present**

Check that line 23 of `project.yml` has:
```yaml
    ENABLE_USER_SCRIPT_SANDBOXING: NO
```
Expected: Already present in ScanAnything's project.yml (confirmed).

- [ ] **Step 3: Regenerate the Xcode project**

Run from `app761-scan-anything/ScanAnything/`:
```bash
cd /Users/thanhhaikhong/Documents/app761-scan-anything/ScanAnything
xcodegen generate
```
Expected: `Generated project` message with no errors.

- [ ] **Step 4: Build to verify the fix still works**

Build using XcodeBuildMCP or:
```bash
cd /Users/thanhhaikhong/Documents/app761-scan-anything/ScanAnything
xcodebuild build -project ScanAnything.xcodeproj -scheme ScanAnything -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED with "fix-wasm-corruption: done" in build log.

- [ ] **Step 5: Commit in app761-scan-anything repo**

```bash
cd /Users/thanhhaikhong/Documents/app761-scan-anything
git add ScanAnything/project.yml
git commit -m "refactor: use shared fix-wasm-corruption.sh from WasmClient instead of inline script"
```

---

### Task 4: Template for New Consumer Projects (e.g., LiveScore Adding WasmClient)

This task documents the exact steps when a new project like `app773-live-score` adds WasmClient to its `Features` package. No code changes needed in WasmClient — only in the consumer project.

**Files:**
- Modify (when needed): `app773-live-score/Features/Package.swift` — add WasmClient dependency
- Modify (when needed): `app773-live-score/LiveScore/project.yml` — add fix script + setting

- [ ] **Step 1: Add WasmClient dependency to the Features Package.swift**

In the consumer's `Features/Package.swift`, add to `dependencies:`:

```swift
.package(
    url: "https://github.com/ThanhHaiKhong/WasmClient.git",
    branch: "main"
),
```

And add the products to whichever targets need them:

```swift
// Interface only (for features that reference WasmClient types):
.product(name: "WasmClient", package: "WasmClient"),

// Live implementation (for the feature that starts the engine):
.product(name: "WasmClientLive", package: "WasmClient"),
```

- [ ] **Step 2: Add `ENABLE_USER_SCRIPT_SANDBOXING: NO` to project.yml**

In the project's `project.yml` under `settings.base:`, add:

```yaml
settings:
  base:
    ENABLE_USER_SCRIPT_SANDBOXING: NO    # Required for wasm fix script
    # ... existing settings ...
```

- [ ] **Step 3: Add postBuildScript to the app target in project.yml**

Under the app target's definition, add:

```yaml
    postBuildScripts:
      - name: Fix Wasm Resource
        script: |
          SCRIPT="${SRCROOT}/../Features/.build/checkouts/WasmClient/scripts/fix-wasm-corruption.sh"
          [ -x "$SCRIPT" ] && "$SCRIPT" || echo "warning: fix-wasm-corruption.sh not found at $SCRIPT"
        basedOnDependencyAnalysis: false
```

- [ ] **Step 4: Regenerate and build**

```bash
xcodegen generate
xcodebuild build -project <ProjectName>.xcodeproj -scheme <SchemeName> -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```
Expected: BUILD SUCCEEDED, "fix-wasm-corruption: done" in log.

- [ ] **Step 5: Commit**

```bash
git add Features/Package.swift <ProjectDir>/project.yml
git commit -m "feat: integrate WasmClient with Xcode 26 wasm corruption fix"
```

---

### Task 5: Clean Up WasmBuildError.md

**Files:**
- Modify: `WasmBuildError.md`

Update the documentation to reference the new shared script instead of describing the fix as project-specific.

- [ ] **Step 1: Append integration instructions to WasmBuildError.md**

Add at the end of the file:

```markdown

## Automatic Fix Integration

The fix is shipped as `scripts/fix-wasm-corruption.sh` in this repository. Any XcodeGen
project that adds WasmClient to its Features package gets the fix by adding two things
to `project.yml`:

1. Project-level setting:
   ```yaml
   settings:
     base:
       ENABLE_USER_SCRIPT_SANDBOXING: NO
   ```

2. Post-build script on the app target:
   ```yaml
   postBuildScripts:
     - name: Fix Wasm Resource
       script: |
         SCRIPT="${SRCROOT}/../Features/.build/checkouts/WasmClient/scripts/fix-wasm-corruption.sh"
         [ -x "$SCRIPT" ] && "$SCRIPT" || echo "warning: fix-wasm-corruption.sh not found at $SCRIPT"
       basedOnDependencyAnalysis: false
   ```

See `xcodegen/wasm-postbuild.yml` for the full reference.
```

- [ ] **Step 2: Commit**

```bash
git add WasmBuildError.md
git commit -m "docs: add automatic fix integration instructions to WasmBuildError.md"
```
