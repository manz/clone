#!/bin/bash
# Stand up a lightweight Linux dev environment for Clone.
#
# From macOS:
#   ./scripts/linux-dev.sh setup    # create + provision VM (once)
#   ./scripts/linux-dev.sh build    # build everything inside VM
#   ./scripts/linux-dev.sh run      # launch CloneDesktop in VM
#   ./scripts/linux-dev.sh shell    # interactive shell in VM
#   ./scripts/linux-dev.sh teardown # destroy VM
#
# Prerequisites: brew install lima
#
# Source tree is shared via virtiofs at /mnt/clone — edits on macOS
# are immediately visible in the VM. Build artifacts stay in the VM's
# filesystem for native speed.

set -euo pipefail

VM_NAME="clone-dev"
LIMA_CONFIG="nix/lima.yaml"

case "${1:-help}" in
  setup)
    echo "Creating VM '$VM_NAME'..."
    limactl create --name "$VM_NAME" "$LIMA_CONFIG"
    limactl start "$VM_NAME"
    echo ""
    echo "VM ready. Source mounted at /mnt/clone"
    echo "Run: ./scripts/linux-dev.sh build"
    ;;

  build)
    echo "Building Clone in VM..."
    limactl shell "$VM_NAME" -- bash -c '
      set -euo pipefail
      export PATH="$HOME/.cargo/bin:$PATH"
      cd /mnt/clone

      # Build Rust engine + render + audio
      cargo build

      # Build Swift compositor + SDK
      swift build

      # Assemble SDK frameworks
      bash scripts/build-sdk.sh

      # Build apps
      make apps

      echo ""
      echo "=== Build complete ==="
    '
    ;;

  run)
    echo "Launching CloneDesktop in VM..."
    limactl shell "$VM_NAME" -- bash -c '
      export PATH="$HOME/.cargo/bin:$PATH"
      export WGPU_BACKEND=vulkan
      cd /mnt/clone
      swift run CloneDesktop
    '
    ;;

  shell)
    limactl shell "$VM_NAME"
    ;;

  status)
    limactl list | grep "$VM_NAME" || echo "VM '$VM_NAME' not found"
    ;;

  stop)
    limactl stop "$VM_NAME"
    ;;

  teardown)
    echo "Destroying VM '$VM_NAME'..."
    limactl delete --force "$VM_NAME"
    echo "Done."
    ;;

  *)
    echo "Usage: $0 {setup|build|run|shell|status|stop|teardown}"
    echo ""
    echo "  setup     Create and provision the VM (once)"
    echo "  build     Build Clone inside the VM"
    echo "  run       Launch CloneDesktop in the VM"
    echo "  shell     Interactive shell in the VM"
    echo "  status    Show VM status"
    echo "  stop      Stop the VM"
    echo "  teardown  Destroy the VM completely"
    ;;
esac
