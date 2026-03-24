.PHONY: all engine bindings text text-bindings audio audio-bindings swift apps build test clean sdk sdk-release vm-create vm-start vm-stop vm-ssh vm-build vm-run docker-build docker-sdk docker-apps

# Build everything: engine → bindings → audio → audio-bindings → libs + apps
all: bindings text-bindings audio-bindings swift apps

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
		--out-dir Sources/EngineBridge
	cp Sources/EngineBridge/clone_engineFFI.h Sources/CEngine/include/clone_engineFFI.h

# Rust text measurement crate
text:
	cargo build -p clone-text

# Generate UniFFI Swift bindings (text)
text-bindings: text
	cargo run -p clone-text --bin uniffi-bindgen-text generate \
		--library target/debug/libclone_text.dylib \
		--language swift \
		--out-dir Sources/CloneText
	cp Sources/CloneText/clone_textFFI.h Sources/CText/include/clone_textFFI.h

# Rust audio engine
audio:
	cargo build -p clone-audio

# Generate UniFFI Swift bindings (audio)
audio-bindings: audio
	cargo run -p clone-audio --bin uniffi-bindgen generate \
		--library target/debug/libclone_audio.dylib \
		--language swift \
		--out-dir Sources/AudioBridge
	cp Sources/AudioBridge/clone_audioFFI.h Sources/CAudio/include/clone_audioFFI.h

# Swift package (libs + compositor)
swift:
	swift build

# App processes
apps: swift
	swift build --target Finder
	swift build --target Settings
	swift build --target Dock
	swift build --target MenuBar
	swift build --target PasswordApp
	swift build --target TextEditApp
	swift build --target PreviewApp
	swift build --target LoginWindow
	swift build --target keychaind

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
sdk: swift
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
