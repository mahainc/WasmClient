# FlowKit Xcode Switching

This repository keeps a single source branch and switches the FlowKit binary
artifact to match the Xcode line you want to use.

## Supported Versions

- `26.1.1`
- `26.4`

## Switch Command

From the repository root:

```bash
./scripts/use-flowkit-xcode.sh 26.1.1
```

or:

```bash
./scripts/use-flowkit-xcode.sh 26.4
```

This updates the vendored wrapper package in
`Vendor/FlowKitPackage/Package.swift` to point at the matching FlowKit release
artifact and checksum.

## After Switching

Refresh package resolution and rebuild:

```bash
swift package resolve
```

or build directly with Xcode/xcodebuild:

```bash
xcodebuild -scheme WasmClient-Package -destination 'generic/platform=iOS Simulator' build
```

## Where Versions Are Defined

Version metadata lives in:

- `Vendor/FlowKitPackage/flowkit-versions.sh`

The switching script is:

- `scripts/use-flowkit-xcode.sh`

## Notes

- `main` stays the primary branch. You do not need separate long-lived branches
  for `26.1.1` and `26.4`.
- The merge helper in `scripts/merge-flowkit-modules.sh` supports both local
  SwiftPM artifacts and Xcode `DerivedData` artifact locations.
