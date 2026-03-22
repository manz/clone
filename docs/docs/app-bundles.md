# App Bundles

Clone apps are distributed as `.app` bundles — the same structure used on macOS, adapted for Linux.

## Filesystem Layout

Clone replicates the macOS filesystem hierarchy:

```
/
├── Applications/                          ← App bundles
│   ├── Finder.app/
│   ├── Settings.app/
│   ├── Dock.app/
│   ├── MenuBar.app/
│   ├── TextEdit.app/
│   ├── Preview.app/
│   └── CloneDesktop.app/                  ← The compositor
│
├── System/
│   └── Library/
│       └── Frameworks/                    ← SDK frameworks
│           ├── SwiftUI.framework/
│           ├── AppKit.framework/
│           ├── SwiftData.framework/
│           ├── Charts.framework/
│           └── ...
│
├── Library/
│   ├── Preferences/                       ← App preferences (plist)
│   └── Application Support/               ← App data
│
└── Users/
    └── dev/
        ├── Desktop/
        ├── Documents/
        ├── Downloads/
        └── Library/
            └── Application Support/       ← Per-user app data
```

## Bundle Structure

On Linux, the executable lives in `Contents/Linux/` (not `Contents/MacOS/`). This is required for Foundation's `Bundle.main` to resolve correctly — Swift's CoreFoundation walks up from the platform-specific subdirectory to find the bundle root.

```
Finder.app/
  Contents/
    Linux/
      Finder                               ← executable binary
    MacOS/
      Finder                               ← macOS binary (if fat bundle)
    Info.plist                             ← bundle metadata
    Resources/
      AppIcon.icns                         ← app icon
      en.lproj/
        Localizable.strings                ← localized strings
```

### Info.plist

Each app bundle contains an `Info.plist` with standard keys:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.clone.Finder</string>
    <key>CFBundleName</key>
    <string>Finder</string>
    <key>CFBundleExecutable</key>
    <string>Finder</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
```

On Linux, `Bundle.main.infoDictionary` loads `Contents/Info.plist` automatically when the bundle structure is detected (Foundation checks for a `Contents/` directory and resolves the bundle version accordingly).

## Bundle Resolution

| API | Returns |
|-----|---------|
| `Bundle.main.bundlePath` | `/Applications/Finder.app` |
| `Bundle.main.executablePath` | `/Applications/Finder.app/Contents/Linux/Finder` |
| `Bundle.main.resourcePath` | `/Applications/Finder.app/Contents/Resources` |
| `Bundle.main.infoDictionary` | Parsed `Contents/Info.plist` |
| `Bundle.main.bundleIdentifier` | `com.clone.Finder` |

## App Launching

The compositor resolves app binaries from `/Applications/`:

```
launchApp("Finder")
  → /Applications/Finder.app/Contents/Linux/Finder
```

During development, it falls back to the SPM build directory:

```
launchApp("Finder")
  → .build/debug/Finder        (dev fallback)
```

## Building App Bundles

App bundles are assembled after `swift build` by a post-build step:

```bash
make bundles    # Assemble .app bundles from SPM output
make install    # Install to /Applications/ (requires sudo on Linux)
```

The bundler:

1. Takes each executable target from `.build/debug/` (or `release/`)
2. Creates the `Name.app/Contents/Linux/Name` directory structure
3. Copies `Info.plist` from the app's source directory
4. Copies resources from `Resources/` if present
5. Outputs to `.build/bundles/`
