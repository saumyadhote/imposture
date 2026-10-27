# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

- **Project:** Imposture
- **Bundle ID:** com.saumyad.imposture
- **Description:** Native iOS posture app: a ten-day guided programme, an exercise catalogue, an on-device side-view posture assessment (Vision), and progress tracking. Mascot demos are pre-rendered Blender loops (see Docs/MASCOT_ASSETS.md).
- **Type:** SwiftUI app (e.g., SwiftUI app, widget, SPM package)
- **Platforms:** iOS 27, iPhone only, portrait
- **Architecture:** MVVM with @Observable

## Build and Run

```bash
# Open in Xcode
open Imposture.xcodeproj
# or for workspace:
# open Imposture.xcworkspace

# Build (iOS)
xcodebuild -project "Imposture.xcodeproj" \
  -scheme "Imposture" \
  -configuration Debug \
  -sdk iphonesimulator \
  build

# Build (macOS)
xcodebuild -project "Imposture.xcodeproj" \
  -scheme "Imposture" \
  -destination 'platform=macOS' \
  build

# Build (watchOS)
xcodebuild -project "Imposture.xcodeproj" \
  -scheme "ImpostureWatch" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  build

# Build (visionOS)
xcodebuild -project "Imposture.xcodeproj" \
  -scheme "Imposture" \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro' \
  build

# Run tests
xcodebuild -project "Imposture.xcodeproj" \
  -scheme "Imposture" \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  test

# For SPM packages
swift build
swift test
```

## Architecture (MVVM with @Observable)

### Folder Structure
```
Imposture/
  App/
    ImpostureApp.swift      # @main entry point
    ContentView.swift               # Root navigation
  Models/                           # Pure data structures (including @Model for SwiftData)
  ViewModels/                       # @Observable classes, business logic
  Views/                            # SwiftUI views (thin, declarative)
  Services/                         # Protocol-defined services
  Extensions/                       # Swift extensions
  Resources/                        # Assets, configs, localization
```

### MVVM Rules

- **Models** = Pure Swift data types (structs/enums). No UI imports, no business logic. Use `Codable`, `Hashable`, `Identifiable` as needed. For persistence, use `@Model` (SwiftData).
- **ViewModels** = `@MainActor @Observable` classes. Own all business logic and state. Call services via protocol abstractions. Never import SwiftUI (use `import Foundation`).
- **Views** = Thin SwiftUI structs. Declarative layout only. No business logic. Bind to ViewModels with `@Bindable` or read via `@State`/`@Environment`.
- **Services** = Protocol-defined. Handle networking, persistence, system APIs. Injected into ViewModels. Easy to mock for testing.

### Quick Pattern
```swift
// Model
struct Item: Identifiable, Codable {
    let id: UUID
    var name: String
}

// ViewModel
import Foundation
import Observation

@MainActor @Observable
class ItemListViewModel {
    var items: [Item] = []
    var isLoading = false
    var errorMessage: String?

    private let service: ItemServiceProtocol

    init(service: ItemServiceProtocol = ItemService()) {
        self.service = service
    }

    func loadItems() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await service.fetchItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// View
struct ItemListView: View {
    @Bindable var viewModel: ItemListViewModel

    var body: some View {
        List(viewModel.items) { item in
            Text(item.name)
        }
        .task { await viewModel.loadItems() }
    }
}
```

## SwiftUI Best Practices

### Data Flow Decision Guide

| Scenario | Use |
|----------|-----|
| View-local transient state (toggles, text input) | `@State` |
| Passing value to child view | `@Binding` |
| ViewModel owned by parent, child needs mutation | `@Bindable` |
| Shared data passed through environment | `@Environment` |
| App-wide dependency injection | `@Environment` with custom key |
| ViewModel created and owned by this view | `@State var vm = ViewModel()` |

### Navigation
- Use `NavigationStack` with `NavigationPath` for programmatic navigation
- Use `.navigationDestination(for:)` for type-safe routing
- Prefer `sheet()` for modal content, `fullScreenCover()` for immersive flows
- Use `TabView` for top-level navigation (max 5 tabs)
- macOS: Use `NavigationSplitView` for sidebar-based navigation

### Lifecycle & Async
- Use `.task { }` for async work on appear (auto-cancelled on disappear)
- Use `.task(id:)` to re-trigger when a value changes
- Never use `onAppear` for async work (use `.task` instead)
- Use `#Preview` macro for all views

### General
- Prefer small, composable views over monolithic ones
- Extract reusable modifiers with `ViewModifier`
- Use `@ViewBuilder` for conditional content in custom views
- Prefer `LazyVStack`/`LazyHStack` inside `ScrollView` for long lists

## iOS 26 / Liquid Glass

### Automatic Glass
These components get liquid glass styling automatically in iOS 26:
- `TabView` (floating tab bar)
- `NavigationStack` (navigation bar)
- Toolbars and bottom bars
- System alerts, sheets, popovers

### Manual Glass
```swift
// Apply glass effect to custom views
.glassEffect(.regular)

// Glass effect container for grouping
GlassEffectContainer {
    // Child views share glass context
}
```

### Guidelines
- Let system components handle glass automatically -- do not override
- Use `.glassEffect` sparingly on custom floating elements
- Do NOT apply glass to content backgrounds, cards, or list rows
- Use `MeshGradient` for rich, dynamic backgrounds behind glass
- Test glass appearance in both light and dark mode
- Respect `accessibilityReduceTransparency`

## Xcode MCP Tools

When Xcode is running, prefer MCP tools over CLI equivalents:

| Task | Tool |
|------|------|
| Build project | `mcp__xcode__BuildProject` (Xcode open) or `xcodebuild` (CI/headless) |
| Run all tests | `mcp__xcode__RunAllTests` |
| Run specific tests | `mcp__xcode__RunSomeTests` |
| Get test list | `mcp__xcode__GetTestList` |
| Validate UI changes | `mcp__xcode__RenderPreview` |
| Check build errors | `mcp__xcode__GetBuildLog` + `XcodeListNavigatorIssues` |
| File diagnostics | `mcp__xcode__XcodeRefreshCodeIssuesInFile` |
| Search docs | `mcp__xcode__DocumentationSearch` |
| Read/write files | `mcp__xcode__XcodeRead` / `XcodeWrite` / `XcodeUpdate` |
| Search project files | `mcp__xcode__XcodeGrep` / `XcodeGlob` |
| File management | `mcp__xcode__XcodeLS` / `XcodeMV` / `XcodeRM` / `XcodeMakeDir` |
| List Xcode windows | `mcp__xcode__XcodeListWindows` |
| Run Swift snippet | `mcp__xcode__ExecuteSnippet` |

Use `RenderPreview` after UI changes to validate visually. Fall back to `xcodebuild` for CI/headless builds.

## Code Style

### Naming
- Follow Swift API Design Guidelines
- Types: `UpperCamelCase` (e.g., `UserProfile`, `NetworkService`)
- Functions/properties: `lowerCamelCase` (e.g., `fetchUser()`, `isLoading`)
- Protocols describing capability: `-able`/`-ible` suffix (e.g., `Loadable`)
- Protocols describing role: noun (e.g., `DataSource`, `Coordinator`)

### Concurrency
- Use `async/await` for all asynchronous work (never completion handlers in new code)
- Use `@MainActor` on ViewModels and any UI-updating code
- Use `actor` for shared mutable state requiring synchronization
- Ensure `Sendable` conformance for types crossing isolation boundaries
- Use `TaskGroup` for concurrent parallel work

### General
- Use `guard` for early exits and precondition validation
- Never force-unwrap (`!`) -- use `guard let`, `if let`, or nil coalescing (`??`)
- Prefer value types (`struct`, `enum`) over reference types (`class`) unless identity matters
- Use access control (`private`, `fileprivate`, `internal`, `public`) intentionally
- Keep files focused -- one primary type per file

## Human Interface Guidelines

- Use **SF Symbols** for all icons (prefer over custom assets)
- Support **Dynamic Type** -- never hardcode font sizes, use `.font(.body)` etc.
- Support **Dark Mode** -- use system colors (`Color.primary`, `.secondary`, `.accentColor`)
- Minimum **44pt touch targets** for all interactive elements
- Use **system colors and materials** for platform consistency
- Implement **accessibility labels** on all interactive elements and meaningful images
- Prefer **native components** over custom implementations (DatePicker, ColorPicker, ShareLink, PhotosPicker, etc.)
- Respect **safe areas** -- do not clip content under system UI
- Provide **loading, empty, and error states** for all data-driven views
- Use **haptic feedback** (`UIImpactFeedbackGenerator`) for meaningful interactions

## LSP (Required)

The `swift-lsp` plugin is installed. You MUST use it:

- Run **diagnostics** on files after editing -- fix all errors and warnings
- Use **go-to-definition** to understand types before modifying them
- Use **find-references** before renaming or removing any symbol
- **Resolve all warnings** before considering work complete
- Use LSP **hover** to verify types and signatures when unsure

## Testing

Use the **Swift Testing** framework (not XCTest for new tests):

```swift
import Testing

struct ItemListViewModelTests {
    @Test("loads items successfully")
    func loadItems() async {
        let mockService = MockItemService(items: [.sample])
        let vm = ItemListViewModel(service: mockService)

        await vm.loadItems()

        #expect(vm.items.count == 1)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    @Test("handles service error")
    func loadItemsError() async {
        let mockService = MockItemService(error: TestError.network)
        let vm = ItemListViewModel(service: mockService)

        await vm.loadItems()

        #expect(vm.items.isEmpty)
        #expect(vm.errorMessage != nil)
    }
}
```

### Testing Rules
- Test **ViewModels** thoroughly (all public methods and state transitions)
- Use **protocol mocks** for service dependencies (no network calls in tests)
- Use `#Preview` for visual validation of views (not unit tests for layout)
- Test **error paths** and edge cases, not just happy paths
- Name tests descriptively: what is being tested and expected outcome

## Dependencies (SPM Only)

- Use **Swift Package Manager** exclusively (no CocoaPods, no Carthage)
- Add packages via Xcode: File > Add Package Dependencies
- Prefer **Apple frameworks** over third-party (e.g., `URLSession` over Alamofire, `SwiftData` over Realm)
- Pin package versions to specific releases (not branches)
- Evaluate necessity before adding any dependency

## Key Files

SwiftUI screens and reusable components, exercise model and movement library, navigation and tab structure, workout session flow, progress tracking, and app design system.

- `Imposture/App/ImpostureApp.swift` -- App entry point
- `Imposture/App/ContentView.swift` -- Root view / navigation
- `Imposture/Models/` -- Data models
- `Imposture/ViewModels/` -- Observable ViewModels
- `Imposture/Views/` -- SwiftUI views
- `Imposture/Services/` -- Service protocols and implementations
