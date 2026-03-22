# IPC Protocol

Apps communicate with the compositor over Unix domain sockets using length-prefixed JSON.

## Socket

`/tmp/clone-compositor.sock` — the compositor listens; apps connect on launch.

## Wire Format

Each message is prefixed with a 4-byte little-endian length, followed by UTF-8 JSON:

```
[length: u32 LE][json payload: UTF-8 bytes]
```

## Message Types

### AppMessage (app → compositor)

| Message | Description |
|---------|-------------|
| `register` | Register a new window |
| `frame` | Submit render commands for the current frame |
| `setTitle` | Update window title |
| `close` | Close the window |
| `launchApp` | Request compositor to launch another app |
| `restoreApp` | Bring an app's window to front |
| `registerMenus` | Register app menu structure |
| `menuAction` | Report a menu item was activated |
| `tapHandled` | Acknowledge a tap event was handled |

### CompositorMessage (compositor → app)

| Message | Description |
|---------|-------------|
| `windowCreated` | Confirms window registration with assigned ID |
| `requestFrame` | Asks app to submit a new frame |
| `resize` | Window was resized |
| `pointerDown` / `pointerUp` / `pointerMoved` | Mouse events |
| `keyDown` / `keyUp` | Keyboard events |
| `focusChanged` | Window gained or lost focus |
