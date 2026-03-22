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

Text, VStack, HStack, ZStack, Button, Image, Rectangle, RoundedRectangle, Circle, Capsule, Spacer, Divider, ScrollView, List, ForEach, Section, NavigationStack, NavigationSplitView, GeometryReader, Toggle, Slider, Picker, TextField, Menu, Label, TabView, Group, AnyView, EmptyView.

## Modifiers

Standard SwiftUI modifiers: `.frame()`, `.padding()`, `.background()`, `.foregroundStyle()`, `.font()`, `.bold()`, `.opacity()`, `.cornerRadius()`, `.overlay()`, `.onTapGesture()`, `.onAppear()`, `.task()`, etc.

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

## Key Differences from Apple

- `ViewNode` is the internal IR — never referenced in app code
- Layout uses Clone's own engine (not Apple's private layout system)
- Rendering goes through IPC to the Rust compositor
- `CGFloat` everywhere in public API; `Float` only at the engine boundary
