#!/bin/bash
set -euo pipefail

# Build Clone SDK — assembles .framework bundles from SPM build output.
# Usage: ./scripts/build-sdk.sh [release|debug]

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TRIPLE=$(swift -print-target-info | grep "triple" | head -1 | sed 's/.*"\(.*\)".*/\1/')
BUILD_DIR="$ROOT/.build/${TRIPLE//-//}/$CONFIG"
# Fallback: try the flat triple layout (Linux uses this)
if [ ! -d "$BUILD_DIR" ]; then
    BUILD_DIR="$ROOT/.build/$TRIPLE/$CONFIG"
fi
if [ ! -d "$BUILD_DIR" ]; then
    BUILD_DIR="$ROOT/.build/$CONFIG"
fi

MODULES_DIR="$ROOT/.build/$CONFIG/Modules"
SDK_OUT="$ROOT/.build/sdk/System/Library/Frameworks"

# Detect platform
if [[ "$(uname)" == "Darwin" ]]; then
    DYLIB_EXT="dylib"
else
    DYLIB_EXT="so"
fi

# Framework modules to package — ordered by dependency (leaves first).
FRAMEWORKS=(
    CloneProtocol
    AppKit
    UniformTypeIdentifiers
    AVKit
    KeychainServices
    CloneClient
    AvocadoEvents
    MediaPlayer
    SwiftData
    SwiftUI
    Charts
    AVFoundation
)

echo "=== Clone SDK Builder ==="
echo "Config:     $CONFIG"
echo "Build dir:  $BUILD_DIR"
echo "Modules:    $MODULES_DIR"
echo "Output:     $SDK_OUT"
echo ""

# Step 1: Build everything
# Clean previous SDK output
rm -rf "$SDK_OUT"
mkdir -p "$SDK_OUT"

echo "→ Building ($CONFIG)..."
cd "$ROOT"
swift build -c "$CONFIG" 2>&1 | tail -5

# Step 2: Assemble each framework
for MOD in "${FRAMEWORKS[@]}"; do
    OBJ_DIR="$BUILD_DIR/${MOD}.build"
    FRAMEWORK_DIR="$SDK_OUT/${MOD}.framework"
    VERSIONS_DIR="$FRAMEWORK_DIR/Versions/A"

    # Check if the module was built
    if [ ! -d "$OBJ_DIR" ]; then
        echo "⚠ Skipping $MOD — no build output at $OBJ_DIR"
        continue
    fi

    echo "→ Assembling ${MOD}.framework"

    # Clean previous
    rm -rf "$FRAMEWORK_DIR"
    mkdir -p "$VERSIONS_DIR/Modules/${MOD}.swiftmodule"

    # Link .o files into shared library
    OBJ_FILES=("$OBJ_DIR"/*.swift.o)
    if [ ${#OBJ_FILES[@]} -eq 0 ]; then
        echo "  ⚠ No object files for $MOD"
        continue
    fi

    # Collect -framework flags for already-built dependencies
    FWFLAGS=(-F "$SDK_OUT")
    for DEP_FW in "$SDK_OUT"/*.framework; do
        DEP_NAME=$(basename "$DEP_FW" .framework)
        if [ -f "$DEP_FW/$DEP_NAME" ] && [ "$DEP_NAME" != "$MOD" ]; then
            FWFLAGS+=(-framework "$DEP_NAME")
        fi
    done

    # Bundle transitive internal modules that aren't separate frameworks.
    # AVFoundation needs AudioBridge .o files + Rust audio lib
    if [ "$MOD" = "AVFoundation" ] && [ -d "$BUILD_DIR/AudioBridge.build" ]; then
        for ao in "$BUILD_DIR/AudioBridge.build"/*.swift.o; do
            [ -f "$ao" ] && OBJ_FILES+=("$ao")
        done
        FWFLAGS+=(-lclone_audio)
    fi
    # SwiftUI needs CloneText .o files + Rust text lib
    if [ "$MOD" = "SwiftUI" ] && [ -d "$BUILD_DIR/CloneText.build" ]; then
        for to in "$BUILD_DIR/CloneText.build"/*.swift.o; do
            [ -f "$to" ] && OBJ_FILES+=("$to")
        done
        FWFLAGS+=(-lclone_text)
    fi
    # CloneProtocol needs PosixShim .o files
    if [ "$MOD" = "CloneProtocol" ] && [ -d "$BUILD_DIR/PosixShim.build" ]; then
        for po in "$BUILD_DIR/PosixShim.build"/*.swift.o; do
            [ -f "$po" ] && OBJ_FILES+=("$po")
        done
    fi
    # CloneClient needs PosixShim .o files (also depends on it)
    if [ "$MOD" = "CloneClient" ] && [ -d "$BUILD_DIR/PosixShim.build" ]; then
        for po in "$BUILD_DIR/PosixShim.build"/*.swift.o; do
            [ -f "$po" ] && OBJ_FILES+=("$po")
        done
    fi

    swiftc \
        -emit-library \
        -module-name "$MOD" \
        -o "$VERSIONS_DIR/$MOD" \
        "${OBJ_FILES[@]}" \
        "${FWFLAGS[@]}" \
        -L "$ROOT/.build/$CONFIG" \
        -L "$ROOT/target/$CONFIG" \
        2>&1 | head -5 || true

    if [ ! -f "$VERSIONS_DIR/$MOD" ]; then
        echo "  ⚠ Link failed for $MOD"
        continue
    fi

    # Copy swiftmodule
    if [ -f "$MODULES_DIR/${MOD}.swiftmodule" ]; then
        cp "$MODULES_DIR/${MOD}.swiftmodule" "$VERSIONS_DIR/Modules/${MOD}.swiftmodule/${TRIPLE}.swiftmodule"
    fi
    if [ -f "$MODULES_DIR/${MOD}.swiftdoc" ]; then
        cp "$MODULES_DIR/${MOD}.swiftdoc" "$VERSIONS_DIR/Modules/${MOD}.swiftmodule/${TRIPLE}.swiftdoc"
    fi
    if [ -f "$MODULES_DIR/${MOD}.abi.json" ]; then
        cp "$MODULES_DIR/${MOD}.abi.json" "$VERSIONS_DIR/Modules/${MOD}.swiftmodule/${TRIPLE}.abi.json"
    fi

    # Symlinks (macOS framework convention)
    ln -sfn A "$FRAMEWORK_DIR/Versions/Current"
    ln -sfn "Versions/Current/Modules" "$FRAMEWORK_DIR/Modules"
    ln -sfn "Versions/Current/$MOD" "$FRAMEWORK_DIR/$MOD"

    echo "  ✓ ${MOD}.framework ($(wc -l <<< "$(ls "${OBJ_FILES[@]}" 2>/dev/null)" | tr -d ' ') objects)"
done

echo ""
echo "=== SDK assembled at $SDK_OUT ==="
ls -1 "$SDK_OUT" | sed 's/^/  /'
echo ""
echo "Use: swiftc -F $SDK_OUT -framework SwiftUI ..."
