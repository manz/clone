# SwiftUI API

Clone's SwiftUI module provides the same API surface as Apple's SwiftUI. App code must compile against both without modification (except `#if canImport(CloneClient)` guards for Clone-specific lifecycle).

## View Protocol

All UI elements are structs conforming to `View`:

```swift
public protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}
```

## Available Views

### Layout containers

VStack, HStack, ZStack, Spacer, Divider, GeometryReader, Group

### Text & Images

Text, Image, Label, AsyncImage

### Controls

Button, Toggle, Slider, Picker, TextField, SecureField, Stepper, Menu, Link, ShareLink

### Lists & Collections

List, ForEach, Section, ScrollView, LazyVGrid, LazyVStack, LazyHStack

### Navigation

NavigationStack, NavigationSplitView, NavigationLink, TabView

### Shapes

Rectangle, RoundedRectangle, Circle, Capsule

### Containers

Form, LabeledContent, ContentUnavailableView, ProgressView

### Stub views (compile but no rendering)

Table, TableColumn, ToolbarItem, NSViewRepresentable, TextEditor, ScrollViewReader

## ViewBuilder

Type-preserving result builder that supports up to 10 children via `buildBlock`, unlimited children via `buildPartialBlock`, conditionals (`if`/`else`/`switch`), optionals, `for...in` loops, and `#available` checks.

## Modifiers

Standard SwiftUI modifiers: `.frame()`, `.padding()`, `.background()`, `.foregroundStyle()`, `.foregroundColor()`, `.font()`, `.bold()`, `.italic()`, `.fontWeight()`, `.opacity()`, `.cornerRadius()`, `.overlay()`, `.clipShape()`, `.onTapGesture()`, `.onAppear()`, `.task()`, `.sheet()`, `.alert()`, `.confirmationDialog()`, `.toolbar()`, `.navigationTitle()`, `.searchable()`, `.contextMenu()`, `.help()`, `.disabled()`, etc.

### Text-specific modifiers

`.font()`, `.bold()`, `.italic()`, `.foregroundColor()`, `.fontWeight()` on `Text` return `Text` for type-safe chaining. Generic modifiers return `_ModifiedView`.

## App Protocol

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

The `@main` entry point connects to the compositor via Unix socket, registers a window, and enters the render loop.

## State Management

- `@State` — local view state
- `@Binding` — two-way binding to parent state
- `@Environment` — read values from the environment
- `@StateObject` / `@ObservedObject` — Combine-era observable objects
- `@AppStorage` — UserDefaults-backed persistence

## Key Differences from Apple

- `ViewNode` is the internal IR — never referenced in app code
- Layout uses Clone's own engine (not Apple's private layout system)
- Rendering goes through IPC to the Rust compositor
- `CGFloat` everywhere in public API; `Float` only at the engine boundary
- All views are structs with modifier chaining, matching Apple's API exactly
