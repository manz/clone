.PHONY: all engine bindings text text-bindings audio audio-bindings swift apps install build test clean sdk sdk-release vm-create vm-start vm-stop vm-ssh vm-build vm-run docker-build docker-sdk docker-apps

# Build everything: engine → bindings → audio → audio-bindings → compositor → SDK → apps
all: bindings text-bindings audio-bindings swift sdk apps

# Rust engine
engine:
	cargo build -p clone-engine

engine-release:
	cargo build -p clone-engine --release

# Generate UniFFI Swift bindings (engine)
bindings: engine
	cargo run -p clone-engine --bin uniffi-bindgen generate \
		--library target/debug/libclone_engine.dylib \
		--language swift \
		--out-dir Sources/Internal/EngineBridge
	cp Sources/Internal/EngineBridge/clone_engineFFI.h Sources/FFI/CEngine/include/clone_engineFFI.h

# Rust text measurement crate
text:
	cargo build -p clone-text

# Generate UniFFI Swift bindings (text)
text-bindings: text
	cargo run -p clone-text --bin uniffi-bindgen-text generate \
		--library target/debug/libclone_text.dylib \
		--language swift \
		--out-dir Sources/Internal/CloneText
	cp Sources/Internal/CloneText/clone_textFFI.h Sources/FFI/CText/include/clone_textFFI.h

# Rust audio engine
audio:
	cargo build -p clone-audio

# Generate UniFFI Swift bindings (audio)
audio-bindings: audio
	cargo run -p clone-audio --bin uniffi-bindgen generate \
		--library target/debug/libclone_audio.dylib \
		--language swift \
		--out-dir Sources/Internal/AudioBridge
	cp Sources/Internal/AudioBridge/clone_audioFFI.h Sources/FFI/CAudio/include/clone_audioFFI.h

# Swift package — compositor + daemons only (not apps)
swift:
	swift build --product CloneDesktop
	swift build --product keychaind
	swift build --product cloned
	swift build --product launchservicesd

# App processes — built against prebuilt SDK frameworks
# --output-dir puts the generated Package.swift outside Clone's source tree
# --bundle assembles .app bundles with Info.plist and Resources
APPBUILD = swift run ycodebuild --prebuilt --bundle --output-dir .build/apps/$(1) --source-dir Sources/Apps/$(2) --target $(1)
apps:
	$(call APPBUILD,Finder,Finder)
	$(call APPBUILD,Settings,Settings)
	$(call APPBUILD,Dock,Dock)
	$(call APPBUILD,MenuBar,MenuBar)
	$(call APPBUILD,PasswordApp,Password)
	$(call APPBUILD,TextEditApp,TextEdit)
	$(call APPBUILD,PreviewApp,Preview)
	$(call APPBUILD,LoginWindow,LoginWindow)

# Install to $CLONE_ROOT (~/.clone by default)
CLONE_ROOT ?= $(HOME)/.clone
install: all apps
	@mkdir -p $(CLONE_ROOT)/Applications $(CLONE_ROOT)/System $(CLONE_ROOT)/Library/Preferences $(CLONE_ROOT)/Library/Caches $(CLONE_ROOT)/Library/LaunchServices "$(CLONE_ROOT)/Library/Application Support"
	@for d in .build/apps/*/; do \
		for app in "$$d"*.app; do \
			[ -d "$$app" ] && cp -r "$$app" $(CLONE_ROOT)/Applications/ && echo "Installed $$(basename $$app)"; \
		done; \
	done
	@cp .build/debug/CloneDesktop $(CLONE_ROOT)/System/ 2>/dev/null || true
	@cp .build/debug/cloned $(CLONE_ROOT)/System/ 2>/dev/null || true
	@cp .build/debug/keychaind $(CLONE_ROOT)/System/ 2>/dev/null || true
	@cp .build/debug/launchservicesd $(CLONE_ROOT)/System/ 2>/dev/null || true
	@echo "Installed to $(CLONE_ROOT)"

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
# Full swift build needed — build-sdk.sh requires all module .o files and .swiftmodule outputs
sdk:
	swift build
	./scripts/build-sdk.sh debug

sdk-release: bindings audio-bindings
	swift build -c release
	./scripts/build-sdk.sh release

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
	rm -rf .build/sdk
