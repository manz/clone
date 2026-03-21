.PHONY: all engine bindings audio audio-bindings swift apps build test clean

# Build everything: engine → bindings → audio → audio-bindings → libs + apps
all: bindings audio-bindings swift apps

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

clean:
	cargo clean
	swift package clean
