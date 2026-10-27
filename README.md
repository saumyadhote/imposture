# Imposture

A native iOS posture app built with SwiftUI. Imposture combines a ten-day guided programme, an exercise catalogue and an on-device camera posture check, and it tracks progress without inventing numbers.

## Features

- **Onboarding with a body scan.** The camera scan uses Vision to measure neck angle and shoulder level. Only values that were actually measured are shown, and the scan can be skipped.
- **Home.** The Recommended Sessions carousel leads with today's programme day, followed by Guided Sessions and Explore by Concern.
- **Posture check.** A five-step desk-setup preparation flow, then a side-view camera assessment.
- **Progress.** Shows sessions, exercise time, consistency, tracking days, and a Posture Score detail screen. Missing data shows as "Not enough data", never as zero.
- **Design.** Dark mode by default, centralised colour tokens (primary `#A9CC53`), SF Symbols, Dynamic Type and native Liquid Glass controls.

## Requirements

- Xcode 26 or later
- iOS 26 or later, iPhone only

The camera scan needs a real device.

## Build and run

```bash
open Imposture.xcodeproj
```

To run the tests:

```bash
xcodebuild -project Imposture.xcodeproj -scheme Imposture \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

## Architecture

MVVM with `@Observable` and Swift 6 strict concurrency.

| Folder | Contents |
| --- | --- |
| `Imposture/App` | Entry point and root navigation |
| `Imposture/Models` | Plain data types |
| `Imposture/ViewModels` | `@MainActor @Observable` state and logic |
| `Imposture/Services` | Protocol-backed camera, motion, storage and reminder services |
| `Imposture/Views` | SwiftUI screens |
| `Imposture/DesignSystem` | Theme tokens, button styles and shared components |

Unit tests use Swift Testing and live in `ImpostureTests`. UI flows live in `ImpostureUITests`.
