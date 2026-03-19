.PHONY: all engine bindings swift apps build test clean

# Build everything: engine → bindings → libs + apps
all: bindings swift apps

# Rust engine
engine:
	cargo build

engine-release:
	cargo build --release

# Generate UniFFI Swift bindings
bindings: engine
	cargo run --bin uniffi-bindgen generate \
		--library target/debug/libclone_engine.dylib \
		--language swift \
		--out-dir Sources/EngineBridge

# Swift package (libs + compositor)
swift:
	swift build

# App processes
apps: swift
	swift build --target Finder
	swift build --target Settings
	swift build --target Dock
	swift build --target MenuBar

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
