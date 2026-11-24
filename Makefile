.PHONY: all all-release engine render render-bindings bindings text text-bindings audio audio-bindings swift apps install install-sdk build test clean sdk sdk-release docker-build docker-sdk docker-apps os-stage mkosi-image

# Config: debug (default) or release
CONFIG ?= debug
CARGO_FLAGS = $(if $(filter release,$(CONFIG)),--release,)
# Swift 6.4 defaults to the swiftbuild backend; its explicit-module scan resolves
# Apple SDK imports to Clone's shadow modules and the paths here assume the
# native .build layout. Pin native until both are sorted.
SWIFT_BUILD_SYSTEM = --build-system native
SWIFT_FLAGS = $(SWIFT_BUILD_SYSTEM) $(if $(filter release,$(CONFIG)),-c release,)
CARGO_OUT = target/$(CONFIG)

# Platform detection
UNAME := $(shell uname)
ifeq ($(UNAME),Darwin)
  LIB_EXT = dylib
  SED_INPLACE = sed -i ''
else
  LIB_EXT = so
  SED_INPLACE = sed -i
endif

# Build everything: engine -> bindings -> render -> audio -> audio-bindings -> compositor -> SDK -> install-sdk -> apps -> install
all: bindings render-bindings text-bindings audio-bindings swift sdk install-sdk apps install

# Release shorthand
all-release:
	$(MAKE) all CONFIG=release

# Rust engine
engine:
	cargo build -p clone-engine $(CARGO_FLAGS)

# Rust render crate (app-side headless rendering)
render:
	cargo build -p clone-render --features uniffi $(CARGO_FLAGS)

# Generate UniFFI Swift bindings for clone-render (app-side FFI)
render-bindings: render
	cargo run -p clone-render --features uniffi $(CARGO_FLAGS) --bin uniffi-bindgen-render generate \
		--library $(CARGO_OUT)/libclone_render.$(LIB_EXT) \
		--language swift \
		--out-dir /tmp/clone-render-bindings
	mkdir -p Sources/FFI/CRender/include Sources/Internal/CloneRender
	cp /tmp/clone-render-bindings/clone_renderFFI.h Sources/FFI/CRender/include/clone_renderFFI.h
	cp /tmp/clone-render-bindings/clone_render.swift Sources/Internal/CloneRender/clone_render.swift

# Generate UniFFI Swift bindings (engine + clone-render types)
bindings: engine
	cargo run -p clone-engine $(CARGO_FLAGS) --bin uniffi-bindgen generate \
		--library $(CARGO_OUT)/libclone_engine.$(LIB_EXT) \
		--language swift \
		--out-dir Sources/Internal/EngineBridge
	# Merge clone-render FFI header into engine FFI header (symbols live in the same dylib)
	cat Sources/Internal/EngineBridge/clone_renderFFI.h >> Sources/Internal/EngineBridge/clone_engineFFI.h
	mkdir -p Sources/FFI/CEngine/include
	cp Sources/Internal/EngineBridge/clone_engineFFI.h Sources/FFI/CEngine/include/clone_engineFFI.h
	# clone_render.swift imports clone_renderFFI, but all symbols are in clone_engineFFI.
	# Rewrite the import so it finds the C symbols from the merged header.
	$(SED_INPLACE) 's/canImport(clone_renderFFI)/canImport(clone_engineFFI)/' Sources/Internal/EngineBridge/clone_render.swift
	$(SED_INPLACE) 's/import clone_renderFFI/import clone_engineFFI/' Sources/Internal/EngineBridge/clone_render.swift
	# Remove standalone clone-render FFI module files (not needed as a separate module)
	rm -f Sources/Internal/EngineBridge/clone_renderFFI.h Sources/Internal/EngineBridge/clone_renderFFI.modulemap
	# Remove clone-text bindings leaked through engine dylib (already in CloneText target)
	rm -f Sources/Internal/EngineBridge/clone_text.swift Sources/Internal/EngineBridge/clone_textFFI.h Sources/Internal/EngineBridge/clone_textFFI.modulemap

# Rust text measurement crate
text:
	cargo build -p clone-text $(CARGO_FLAGS)

# Generate UniFFI Swift bindings (text)
text-bindings: text
	cargo run -p clone-text $(CARGO_FLAGS) --bin uniffi-bindgen-text generate \
		--library $(CARGO_OUT)/libclone_text.$(LIB_EXT) \
		--language swift \
		--out-dir Sources/Internal/CloneText
	mkdir -p Sources/FFI/CText/include
	cp Sources/Internal/CloneText/clone_textFFI.h Sources/FFI/CText/include/clone_textFFI.h

# Rust audio engine
audio:
	cargo build -p clone-audio $(CARGO_FLAGS)

# Generate UniFFI Swift bindings (audio)
audio-bindings: audio
	cargo run -p clone-audio $(CARGO_FLAGS) --bin uniffi-bindgen generate \
		--library $(CARGO_OUT)/libclone_audio.$(LIB_EXT) \
		--language swift \
		--out-dir Sources/Internal/AudioBridge
	mkdir -p Sources/FFI/CAudio/include
	cp Sources/Internal/AudioBridge/clone_audioFFI.h Sources/FFI/CAudio/include/clone_audioFFI.h

# Swift package - compositor + daemons only (not apps)
swift:
	swift build $(SWIFT_FLAGS) --product CloneDesktop
	swift build $(SWIFT_FLAGS) --product keychaind
	swift build $(SWIFT_FLAGS) --product cloned
	swift build $(SWIFT_FLAGS) --product launchservicesd
	swift build $(SWIFT_FLAGS) --product avocadoeventsd
	swift build $(SWIFT_FLAGS) --product open
	swift build $(SWIFT_FLAGS) --product screencapture

# SDK frameworks
sdk:
	./scripts/build-sdk.sh $(CONFIG)

# App processes - built against prebuilt SDK frameworks
APPBUILD = swift run $(SWIFT_BUILD_SYSTEM) ycodebuild --prebuilt --bundle --output-dir .build/apps/$(1) --source-dir Sources/Apps/$(2) --target $(1)
apps:
	$(call APPBUILD,Finder,System/Finder)
	$(call APPBUILD,Dock,System/Dock)
	$(call APPBUILD,MenuBar,System/MenuBar)
	$(call APPBUILD,LoginWindow,System/LoginWindow)
	$(call APPBUILD,Settings,Settings)
	$(call APPBUILD,Password,Password)
	$(call APPBUILD,TextEdit,TextEdit)
	$(call APPBUILD,Preview,Preview)
	$(call APPBUILD,FontBook,FontBook)
	$(call APPBUILD,Console,Console)
	$(call APPBUILD,Terminal,Terminal)
	$(call APPBUILD,ActivityMonitor,ActivityMonitor)

# Install to $CLONE_ROOT (~/.clone by default)
CLONE_ROOT ?= $(HOME)/.clone
SWIFT_BUILD_DIR = .build/$(CONFIG)

# Install SDK frameworks + Rust libs (needed before make apps)
install-sdk:
	@mkdir -p $(CLONE_ROOT)/System/Library/Frameworks $(CLONE_ROOT)/Library/Fonts
	@cp -n engine/assets/Inter-*.ttf engine/assets/Iosevka-*.ttf $(CLONE_ROOT)/Library/Fonts/ 2>/dev/null || true
	@rm -rf $(CLONE_ROOT)/System/Library/Frameworks
ifeq ($(UNAME),Darwin)
	@ditto .build/sdk/System/Library/Frameworks $(CLONE_ROOT)/System/Library/Frameworks
else
	@cp -a .build/sdk/System/Library/Frameworks $(CLONE_ROOT)/System/Library/Frameworks
endif
	@cp target/$(CONFIG)/libclone_engine.$(LIB_EXT) $(CLONE_ROOT)/System/Library/ 2>/dev/null || true
	@cp target/$(CONFIG)/libclone_render.$(LIB_EXT) $(CLONE_ROOT)/System/Library/ 2>/dev/null || true
	@cp target/$(CONFIG)/libclone_text.$(LIB_EXT) $(CLONE_ROOT)/System/Library/ 2>/dev/null || true
	@cp target/$(CONFIG)/libclone_audio.$(LIB_EXT) $(CLONE_ROOT)/System/Library/ 2>/dev/null || true
	@echo "SDK installed to $(CLONE_ROOT)/System/Library"

# System apps live in System/Library/CoreServices (like macOS)
SYSTEM_APPS = Finder Dock MenuBar LoginWindow

# Full install (SDK + apps + system binaries)
install: install-sdk
	@mkdir -p $(CLONE_ROOT)/Applications $(CLONE_ROOT)/System/Library/CoreServices $(CLONE_ROOT)/Library/Preferences $(CLONE_ROOT)/Library/Caches $(CLONE_ROOT)/Library/LaunchServices "$(CLONE_ROOT)/Library/Application Support"
	@echo "Installing app bundles..."
	@rm -rf $(CLONE_ROOT)/Applications/*.app $(CLONE_ROOT)/System/Library/CoreServices/*.app
	@for d in .build/apps/*/; do \
		for app in "$$d"*.app; do \
			[ -d "$$app" ] || continue; \
			name=$$(basename "$$app" .app); \
			if echo " $(SYSTEM_APPS) " | grep -q " $$name "; then \
				cp -a "$$app" "$(CLONE_ROOT)/System/Library/CoreServices/$$(basename $$app)" && echo "  $$(basename $$app) -> CoreServices"; \
			else \
				cp -a "$$app" "$(CLONE_ROOT)/Applications/$$(basename $$app)" && echo "  $$(basename $$app) -> Applications"; \
			fi; \
		done; \
	done
	@cp -f Sources/Apps/System/SystemVersion.plist $(CLONE_ROOT)/System/Library/CoreServices/SystemVersion.plist
	@echo "Installing system binaries..."
	@cp -f $(SWIFT_BUILD_DIR)/CloneDesktop $(CLONE_ROOT)/System/Library/CoreServices/CloneDesktop 2>/dev/null || true
	@cp -f $(SWIFT_BUILD_DIR)/cloned $(CLONE_ROOT)/System/Library/CoreServices/cloned 2>/dev/null || true
	@cp -f $(SWIFT_BUILD_DIR)/keychaind $(CLONE_ROOT)/System/Library/CoreServices/keychaind 2>/dev/null || true
	@cp -f $(SWIFT_BUILD_DIR)/launchservicesd $(CLONE_ROOT)/System/Library/CoreServices/launchservicesd 2>/dev/null || true
	@cp -f $(SWIFT_BUILD_DIR)/avocadoeventsd $(CLONE_ROOT)/System/Library/CoreServices/avocadoeventsd 2>/dev/null || true
	@# `open` + `screencapture` CLIs: macOS ships them under the system path. Stage
	@# them on PATH for parity.
	@mkdir -p $(CLONE_ROOT)/usr/bin
	@cp -f $(SWIFT_BUILD_DIR)/open $(CLONE_ROOT)/usr/bin/open 2>/dev/null || true
	@cp -f $(SWIFT_BUILD_DIR)/screencapture $(CLONE_ROOT)/usr/bin/screencapture 2>/dev/null || true
ifeq ($(UNAME),Linux)
	@echo "Bundling Swift runtime (from the toolchain CloneDesktop links against)..."
	@RT=$$(ldd $(CLONE_ROOT)/System/Library/CoreServices/CloneDesktop 2>/dev/null | grep -m1 libswiftCore | awk '{print $$3}' | xargs -r dirname); \
	if [ -n "$$RT" ] && [ -d "$$RT" ]; then \
		mkdir -p $(CLONE_ROOT)/System/Library/swift-linux; \
		cp -aL "$$RT"/*.so* $(CLONE_ROOT)/System/Library/swift-linux/ 2>/dev/null; \
		echo "  Swift runtime from $$RT"; \
		BT=$$(find "$$RT/../../.." -name swift-backtrace -type f 2>/dev/null | head -1); \
		if [ -n "$$BT" ]; then cp -f "$$BT" $(CLONE_ROOT)/System/Library/swift-linux/swift-backtrace && echo "  swift-backtrace from $$BT"; \
		else echo "  WARN: swift-backtrace not found near runtime"; fi; \
	else echo "  WARN: could not locate Swift runtime via ldd"; fi
endif
	@echo "Installed to $(CLONE_ROOT) ($(CONFIG))"

# Alias
build: all

# Run Rust tests
test-rust:
	cargo test --lib

# Run Swift tests
# --no-parallel: the SDK's singletons (LayoutCache, StateGraph, registries) are
# main-thread-only like in a real app; parallel tests race on them (SIGSEGV).
test-swift:
	swift test $(SWIFT_BUILD_SYSTEM) --no-parallel

# Run all tests
test: test-rust test-swift

# Assemble SDK frameworks (.framework bundles with .dylib/.so + .swiftmodule)
sdk-release:
	$(MAKE) sdk CONFIG=release

# --- Docker (Linux build environment) ---

docker-build:
	docker build -t clone-sdk .

docker-sdk: docker-build
	docker run --rm -v $(PWD):/clone clone-sdk bash -c 'make all && make sdk'

docker-apps: docker-build
	docker run --rm -v $(PWD):/clone clone-sdk make apps

# --- Appliance image (mkosi / Debian) ---

# Stage a self-contained macOS-layout tree (binaries + bundled Swift runtime +
# wallpapers) that mkosi copies into the image via ExtraTrees. Run on Linux.
CLONE_ROOT_STAGE = $(PWD)/.build/clone-root
os-stage:
	@test "$(UNAME)" = "Linux" || { echo "os-stage must run on Linux (in the VM)"; exit 1; }
	$(MAKE) all CLONE_ROOT=$(CLONE_ROOT_STAGE)
	@mkdir -p "$(CLONE_ROOT_STAGE)/Library/Desktop Pictures"
	@cp -f nix/wallpapers/*.jpg "$(CLONE_ROOT_STAGE)/Library/Desktop Pictures/" 2>/dev/null || true
	@echo "Staged Clone root at $(CLONE_ROOT_STAGE)"

# Build the bootable Debian appliance image: stage the tree, then run mkosi (config
# in mkosi/, which copies .build/clone-root in via ExtraTrees). Run on Linux with
# mkosi installed.
mkosi-image: os-stage
	cd mkosi && mkosi --force build
	@echo "Appliance image built under mkosi/"

clean:
	cargo clean
	swift package clean
	rm -rf .build/sdk .build/apps .build/clone-root
