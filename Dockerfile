# Clone SDK build container
# Produces: .framework bundles + app binaries for Linux aarch64
#
# Usage:
#   docker build -t clone-sdk .
#   docker run -v $(pwd):/clone clone-sdk make sdk
#   docker run -v $(pwd):/clone clone-sdk make apps

FROM swift:6.2-noble AS base

# System deps + curl (needed for rustup)
RUN apt-get update -qq && apt-get install -y -qq \
    curl \
    pkg-config cmake \
    libvulkan-dev \
    libwayland-dev wayland-protocols libxkbcommon-dev \
    libasound2-dev \
    libsqlite3-dev \
    fontconfig libfontconfig-dev libfreetype-dev \
    && rm -rf /var/lib/apt/lists/*

# Rust toolchain
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . /root/.cargo/env \
    && cargo --version \
    && rustc --version
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /clone

# Cache Rust deps — copy manifests first
COPY Cargo.toml Cargo.lock ./
COPY engine/Cargo.toml engine/Cargo.toml
COPY audio/Cargo.toml audio/Cargo.toml
# Pre-fetch Rust deps (ok to fail if manifests don't match dummy sources)
RUN mkdir -p engine/src audio/src \
    && echo "pub fn stub() {}" > engine/src/lib.rs \
    && echo "pub fn stub() {}" > audio/src/lib.rs \
    && cargo fetch || true \
    && rm -rf engine/src audio/src

# Copy full source
COPY . .

# Default: build everything + SDK
CMD ["make", "all"]
