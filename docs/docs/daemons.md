# Daemons

Clone runs several background daemons alongside the compositor. Each daemon is a separate process with a library module (business logic) and an executable target.

## Overview

| Daemon | Socket | Purpose |
|--------|--------|---------|
| `cloned` | `/tmp/clone-daemon.sock` | Now-playing info aggregation, media remote commands |
| `keychaind` | `/tmp/clone-keychain.sock` | SQLite-backed keychain storage |
| `launchservicesd` | `/tmp/clone-launchservices.sock` | App bundle resolution, `/Applications/` scanning |
| `avocadoeventsd` | `/tmp/clone-events.sock` | Typed inter-process event pub/sub |

## Lifecycle

Daemons start with the compositor (before LoginWindow). They run for the entire session and are available to all apps.

```
CloneDesktop starts →
  cloned, keychaind, launchservicesd, avocadoeventsd
    → LoginWindow (pre-session gate)
      → on login → Dock, MenuBar, Finder, ...
```

## cloned (Now-Playing)

**Library:** `CloneDaemon`

Aggregates now-playing information from audio apps. Apps publish their playback state via `MPNowPlayingInfoCenter`, and `cloned` routes this to observers (e.g. MenuBar's now-playing widget).

Also handles `MPRemoteCommandCenter`: media key events (play/pause, next, previous) are routed to the active audio publisher.

## keychaind (Keychain)

**Library:** `CloneKeychain`

Provides the Keychain Services API (`SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, `SecItemDelete`) backed by a local SQLite database. On macOS the `KeychainServices` framework delegates to this daemon; on Linux it's the sole keychain implementation.

## launchservicesd (App Launching)

**Library:** `CloneLaunchServices`

Scans `/Applications/*.app/` bundles and resolves app identifiers to executable paths. Handles `launchApp` and `restoreApp` IPC messages from the compositor. Maintains the registry of installed applications.

## avocadoeventsd (Event Routing)

**Library:** `AvocadoEvents`

Typed pub/sub event system for inter-process communication. Apps can publish and subscribe to typed events (e.g. "app launched", "file opened", "theme changed") without direct socket connections to each other. The daemon routes events between publishers and subscribers.
