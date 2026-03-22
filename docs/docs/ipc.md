# IPC Protocol

Apps communicate with the compositor over Unix domain sockets using length-prefixed JSON.

## Socket

`/tmp/clone-compositor.sock` — the compositor listens; apps connect on launch.

## Wire Format

Each message is prefixed with a 4-byte **big-endian** length, followed by UTF-8 JSON:

```
[length: u32 BE][json payload: UTF-8 bytes]
```

## Message Types

### AppMessage (app → compositor)

| Message | Fields | Description |
|---------|--------|-------------|
| `register` | title, width, height, ... | Register a new window |
| `frame` | commands | Submit render commands for the current frame |
| `setTitle` | title | Update window title |
| `close` | | Close the window |
| `launchApp` | appId | Request compositor to launch another app |
| `restoreApp` | appId | Bring an app's window to front |
| `registerMenus` | menus | Register app menu structure |
| `menuAction` | itemId | Report a menu item was activated |
| `tapHandled` | | Acknowledge a tap event was handled |
| `showOpenPanel` | allowedTypes | Show a file open dialog |
| `sessionReady` | | LoginWindow signals session is ready to start |

### CompositorMessage (compositor → app)

| Message | Fields | Description |
|---------|--------|-------------|
| `windowCreated` | windowId | Confirms window registration |
| `requestFrame` | | Asks app to submit a new frame |
| `resize` | width, height | Window was resized |
| `pointerDown` | x, y | Mouse button pressed |
| `pointerUp` | x, y | Mouse button released |
| `pointerMoved` | x, y | Mouse moved |
| `keyDown` | key, modifiers | Key pressed |
| `keyUp` | key, modifiers | Key released |
| `keyChar` | character | Character input (text entry) |
| `focusChanged` | focused | Window gained or lost focus |
| `minimizedApps` | appIds | List of currently minimized apps |
| `appMenus` | appName, menus | Active app's menu structure (for MenuBar) |
| `openPanelResult` | path | Result of a file open dialog |
