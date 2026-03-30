.PHONY: all all-release engine render render-bindings bindings text text-bindings audio audio-bindings swift apps install install-sdk build test clean sdk sdk-release vm-create vm-start vm-stop vm-ssh vm-build vm-run docker-build docker-sdk docker-apps

# Config: debug (default) or release
CONFIG ?= debug
CARGO_FLAGS = $(if $(filter release,$(CONFIG)),--release,)
SWIFT_FLAGS = $(if $(filter release,$(CONFIG)),-c release,)
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

# Build everything: engine → bindings → render → audio → audio-bindings → compositor → SDK → install-sdk → apps → install
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
	cp Sources/Internal/AudioBridge/clone_audioFFI.h Sources/FFI/CAudio/include/clone_audioFFI.h

# Swift package — compositor + daemons only (not apps)
swift:
	swift build $(SWIFT_FLAGS) --product CloneDesktop
	swift build $(SWIFT_FLAGS) --product keychaind
	swift build $(SWIFT_FLAGS) --product cloned
	swift build $(SWIFT_FLAGS) --product launchservicesd
	swift build $(SWIFT_FLAGS) --product avocadoeventsd

# SDK frameworks
sdk:
	./scripts/build-sdk.sh $(CONFIG)

# App processes — built against prebuilt SDK frameworks
APPBUILD = swift run ycodebuild --prebuilt --bundle --output-dir .build/apps/$(1) --source-dir Sources/Apps/$(2) --target $(1)
apps:
	$(call APPBUILD,Finder,Finder)
	$(call APPBUILD,Settings,Settings)
	$(call APPBUILD,Dock,Dock)
	$(call APPBUILD,MenuBar,MenuBar)
	$(call APPBUILD,Password,Password)
	$(call APPBUILD,TextEdit,TextEdit)
	$(call APPBUILD,Preview,Preview)
	$(call APPBUILD,LoginWindow,LoginWindow)
	$(call APPBUILD,FontBook,FontBook)

# Install to $CLONE_ROOT (~/.clone by default)
CLONE_ROOT ?= $(HOME)/.clone
SWIFT_BUILD_DIR = .build/$(CONFIG)

# Install SDK frameworks + Rust libs (needed before make apps)
install-sdk:
	@mkdir -p $(CLONE_ROOT)/System/Library/Frameworks $(CLONE_ROOT)/Library/Fonts
	@cp -n engine/assets/Inter-*.ttf engine/assets/Iosevka-*.ttf $(CLONE_ROOT)/Library/Fonts/ 2>/dev/null || true
	@rm -rf $(CLONE_ROOT)/System/Library/Frameworks
	@ditto .build/sdk/System/Library/Frameworks $(CLONE_ROOT)/System/Library/Frameworks
	@cp target/$(CONFIG)/libclone_engine.$(LIB_EXT) $(CLONE_ROOT)/System/Library/ 2>/dev/null || true
	@cp target/$(CONFIG)/libclone_render.$(LIB_EXT) $(CLONE_ROOT)/System/Library/ 2>/dev/null || true
	@cp target/$(CONFIG)/libclone_text.$(LIB_EXT) $(CLONE_ROOT)/System/Library/ 2>/dev/null || true
	@cp target/$(CONFIG)/libclone_audio.$(LIB_EXT) $(CLONE_ROOT)/System/Library/ 2>/dev/null || true
	@echo "SDK installed to $(CLONE_ROOT)/System/Library"

# Full install (SDK + apps + system binaries)
install: install-sdk
	@mkdir -p $(CLONE_ROOT)/Applications $(CLONE_ROOT)/Library/Preferences $(CLONE_ROOT)/Library/Caches $(CLONE_ROOT)/Library/LaunchServices "$(CLONE_ROOT)/Library/Application Support"
	@echo "Installing app bundles..."
	@rm -rf $(CLONE_ROOT)/Applications/*.app
	@for d in .build/apps/*/; do \
		for app in "$$d"*.app; do \
			[ -d "$$app" ] && ditto "$$app" "$(CLONE_ROOT)/Applications/$$(basename $$app)" && echo "  $$(basename $$app)"; \
		done; \
	done
	@echo "Installing system binaries..."
	@ditto $(SWIFT_BUILD_DIR)/CloneDesktop $(CLONE_ROOT)/System/CloneDesktop 2>/dev/null || true
	@ditto $(SWIFT_BUILD_DIR)/cloned $(CLONE_ROOT)/System/cloned 2>/dev/null || true
	@ditto $(SWIFT_BUILD_DIR)/keychaind $(CLONE_ROOT)/System/keychaind 2>/dev/null || true
	@ditto $(SWIFT_BUILD_DIR)/launchservicesd $(CLONE_ROOT)/System/launchservicesd 2>/dev/null || true
	@ditto $(SWIFT_BUILD_DIR)/avocadoeventsd $(CLONE_ROOT)/System/avocadoeventsd 2>/dev/null || true
	@echo "Installed to $(CLONE_ROOT) ($(CONFIG))"

# Alias
build: all

# Run Rust tests
test-rust:
	cargo test --lib

# Run Swift tests
test-swift:
	swift test

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

# --- VM (NixOS via Lima) ---

vm-create:
	limactl create --name clone nix/lima.yaml

vm-start:
	limactl start clone

vm-stop:
	limactl stop clone

vm-ssh:
	limactl shell clone

vm-build:
	limactl shell clone -- bash -c 'cd /mnt/clone && make all && make sdk'

vm-run:
	limactl shell clone -- bash -c 'cd /mnt/clone && sudo nixos-rebuild switch --flake .#clone'

clean:
	cargo clean
	swift package clean
	rm -rf .build/sdk .build/apps
