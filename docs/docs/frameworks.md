# Frameworks

Clone distributes its SDK as `.framework` bundles — the same format used on macOS — installed to `/System/Library/Frameworks/`.

## Framework Layout

Swift's compiler supports `.framework` bundles on all platforms via the `-F` flag. On Linux, the executable subdirectory is `Contents/Linux/` instead of `Contents/MacOS/`.

```
SwiftUI.framework/
  Versions/
    A/
      SwiftUI                              ← shared library (.so on Linux)
      Modules/
        SwiftUI.swiftmodule/
          aarch64-unknown-linux-gnu.swiftmodule
          aarch64-unknown-linux-gnu.swiftdoc
    Current → A                            ← symlink
  SwiftUI → Versions/Current/SwiftUI      ← symlink
  Modules → Versions/Current/Modules      ← symlink
```

The key difference from macOS: Foundation's `Bundle` class on Linux resolves the bundle path by walking up from `Contents/Linux/`, not `Contents/MacOS/`. This means `Bundle.main.bundlePath`, `Bundle.main.resourcePath`, and `Bundle.main.infoDictionary` all work correctly — as long as the binary sits in the right platform subdirectory.

| Platform | Executable subdirectory |
|----------|------------------------|
| macOS    | `Contents/MacOS/`      |
| Linux    | `Contents/Linux/`      |
| Windows  | `Contents/Windows/`    |

## Compiling Against Frameworks

```bash
swiftc -F /System/Library/Frameworks \
    -framework SwiftUI \
    -framework Charts \
    MyApp.swift -o MyApp
```

The compiler searches each `-F` path for `FrameworkName.framework/Modules/FrameworkName.swiftmodule/` to resolve imports, and links against the shared library inside the framework bundle.

## Available Frameworks

### Public SDK (app-facing)

| Framework | Description |
|-----------|-------------|
| `SwiftUI` | UI framework: View structs, ViewBuilder, Layout, App protocol, modifiers |
| `AppKit` | NSColor, NSAppearance, NSImage, NSWorkspace, NSPasteboard shims |
| `SwiftData` | SQLite-backed persistence: PersistentModel, ModelContainer, Query, Foundation.Predicate→SQL converter |
| `Charts` | Swift Charts: BarMark, LineMark, AreaMark, PointMark, RuleMark, RectangleMark, SectorMark, ChartProxy, selection, scrolling |
| `AVFoundation` | Audio playback: AVPlayer, AVQueuePlayer, AVPlayerItem, AVAudioSession, CMTime |
| `AVKit` | AV UI components: AVRoutePickerView, AVPlayerView |
| `MediaPlayer` | MPNowPlayingInfoCenter, MPRemoteCommandCenter, media key handling |
| `UniformTypeIdentifiers` | UTType declarations for file type identification |
| `KeychainServices` | Keychain Services API (SecItemAdd, SecItemCopyMatching). Named `KeychainServices` on macOS to avoid shadowing the system `Security.framework`; becomes `Security` on Linux. |

### Internal (compositor + IPC)

| Module | Description |
|--------|-------------|
| `CloneClient` | App-side Unix socket client |
| `CloneProtocol` | Shared IPC message types (Codable, 4-byte BE length-prefixed JSON) |
| `EngineBridge` | UniFFI bridge: FlatRenderCommand↔RenderCommand, CGFloat↔Float boundary |
| `AudioBridge` | UniFFI bridge: wraps Rust `clone-audio` (CPAL + symphonia) for Swift |
| `CloneDaemon` | Now-playing daemon library (used by `cloned` executable) |
| `CloneKeychain` | Keychain daemon library (used by `keychaind` executable), SQLite-backed |
| `CSQLite` | System library wrapper for SQLite3 (used by SwiftData and CloneKeychain) |

## Building the SDK

```bash
make sdk          # Debug build — assembles frameworks from SPM output
make sdk-release  # Release build — optimized
make docker-sdk   # Build for Linux inside Docker container
```

The `scripts/build-sdk.sh` script:

1. Runs `swift build` to compile all modules (produces `.o` files + `.swiftmodule`)
2. Links each module's object files into a shared library (`swiftc -emit-library`)
3. Copies the `.swiftmodule` into the framework's `Modules/` directory
4. Creates the `Versions/A/` → `Versions/Current` symlink structure
5. Outputs to `.build/sdk/System/Library/Frameworks/`

Dependency order matters — leaf modules (CloneProtocol, AppKit) are linked first so that dependent modules (SwiftUI, Charts) can resolve their symbols. AVFoundation additionally links the Rust `libclone_audio` library via AudioBridge.
