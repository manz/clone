# Building

## Prerequisites

- **Swift 6.2+** — [swift.org/install](https://swift.org/install)
- **Rust (stable)** — [rustup.rs](https://rustup.rs)
- **System libraries** — SQLite, Vulkan headers (Linux), pkg-config

## Build Commands

```bash
make all          # Full build: cargo build → UniFFI bindings → swift build
make engine       # Rust engine only
make bindings     # Generate UniFFI Swift bindings
make swift        # Swift package (libs + compositor)
make apps         # Build all app targets
make sdk          # Assemble .framework bundles
make test         # Run all tests (Rust + Swift)
```

## Docker (Linux)

```bash
make docker-build   # Build the container image
make docker-sdk     # Build SDK for Linux inside the container
make docker-apps    # Build all apps for Linux
```

The Docker image is based on `swift:6.2-noble` (Ubuntu 24.04) with Rust and all system dependencies pre-installed.
