# Docker Build

The Docker container provides a reproducible Linux build environment for Clone's SDK and apps.

## Image

Based on `swift:6.2-noble` (Ubuntu 24.04 LTS) with Rust and system dependencies.

## Usage

```bash
# Build the image
make docker-build

# Build SDK frameworks for Linux
make docker-sdk

# Build all app binaries for Linux
make docker-apps
```

The source is bind-mounted into the container, so build output lands directly in `.build/` on the host.

## What Gets Built

| Target | Output |
|--------|--------|
| `make docker-sdk` | `.build/sdk/System/Library/Frameworks/*.framework` |
| `make docker-apps` | `.build/debug/{Finder,Settings,Dock,MenuBar,...}` |

## Manual Usage

```bash
# Interactive shell inside the build container
docker run -it -v $(pwd):/clone clone-sdk bash

# Build a specific target
docker run --rm -v $(pwd):/clone clone-sdk swift build --target Charts
```
