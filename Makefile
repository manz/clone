.PHONY: engine bindings swift build test clean

# Rust engine
engine:
	cargo build

engine-release:
	cargo build --release

# Run Rust tests
test-rust:
	cargo test

# Generate UniFFI Swift bindings
bindings: engine
	cargo run --bin uniffi-bindgen generate \
		--library target/debug/libclone_engine.dylib \
		--language swift \
		--out-dir Sources/DesktopKit/Generated
	@# Copy header to CEngine module
	@if [ -f Sources/DesktopKit/Generated/clone_engineFFI.h ]; then \
		cp Sources/DesktopKit/Generated/clone_engineFFI.h Sources/CEngine/include/cloneFFI.h; \
	fi

# Swift package
swift:
	swift build

# Run Swift tests
test-swift:
	swift test

# Build everything
build: engine swift

# Run all tests
test: test-rust test-swift

clean:
	cargo clean
	swift package clean
