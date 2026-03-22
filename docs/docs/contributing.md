# Contributing

## Build

```bash
make all    # Full build
make test   # Run tests
```

## Code Style

- All DSL types are structs, not free functions
- `CGFloat` everywhere in public API
- `ViewNode` is internal — never reference in app code
- App code must compile against real Apple SwiftUI

## Commit Messages

- Imperative verb to start: Add, Fix, Update, Remove
- No conventional prefixes (`feat:`, `fix:`)
- Single subject line, explains "why" when helpful
