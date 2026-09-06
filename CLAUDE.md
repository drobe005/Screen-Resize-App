# ScreenResize

A macOS menu bar app that resizes the currently focused window of any application
to preset resolutions and aspect ratios.

## Build and test

Always from the CLI. Never from the Xcode GUI.

```bash
./scripts/build.sh
```

```bash
./scripts/test.sh
```

Both wrap `xcodebuild`. `build.sh` takes an optional configuration argument
(`Debug` by default, e.g. `./scripts/build.sh Release`). `test.sh` takes an
optional `-only-testing:` filter (e.g. `./scripts/test.sh ScreenResizeTests/GeometryTests`).

### DerivedData lives outside the repo

Build output goes to `~/Library/Developer/Xcode/DerivedData/ScreenResize`, not into
the working tree. This is not a style choice. The repo sits under `~/Documents`,
which iCloud's "Desktop & Documents Folders" sync manages through a file provider.
That provider stamps `com.apple.FinderInfo` and `com.apple.fileprovider.fpfs#P` onto
everything written there, and `codesign` refuses to sign a bundle carrying them:

```
resource fork, Finder information, or similar detritus not allowed
```

Building inside the synced tree therefore fails at the code-signing step every time.
Override the location with `SCREENRESIZE_DERIVED_DATA` if needed. Do not "fix" a
recurrence of this error with `xattr -cr` — that treats the symptom and it will come
back on the next build.

---

## Stack

- Swift 5.9+
- SwiftUI, `MenuBarExtra` as the app's only scene
- Minimum deployment target: macOS 14
- Window control via the Accessibility API (`AXUIElement`)
- Built and tested exclusively from the command line with `xcodebuild`

## Hard constraints

These are properties of the platform, not preferences. Do not design around
them being negotiable.

### 1. No sandbox, therefore no Mac App Store

The Accessibility API cannot run inside the App Sandbox. `com.apple.security.app-sandbox`
must be off. This app can never ship on the Mac App Store.

Distribution is:
- Developer ID signing
- Notarization via Apple's notary service
- Shipped as a DMG

Do not add sandbox entitlements. Do not add App Store build configurations,
receipt validation, or StoreKit.

### 2. Points, not pixels

The AX API sets window size in **points**, not pixels. On a 2x Retina display,
3840x2160 pixels equals 1920x1080 points.

Every dimension in the codebase must be explicitly typed or named so points and
pixels can never be silently confused. A bare `CGSize` or a variable named
`width` crossing a function boundary is a bug waiting to happen.

Rules:
- Use distinct types for the two domains (e.g. `PointSize` and `PixelSize`), or
  at minimum unambiguous names (`widthInPoints`, `heightInPixels`). Never a bare
  `width`/`height`/`size` on any API that crosses a layer.
- Conversion between the two happens in exactly one place, in a pure function
  that takes the display's backing scale factor as an explicit parameter.
- Never read a scale factor from a global or ambient source inside geometry code.
- Presets are authored in pixels (that is how users think about resolutions) and
  converted to points at the moment of application. Both values must be visible
  and testable.

### 3. Every resize must be verified

Many windows reject resize requests:
- Fixed-size windows
- Some Electron apps
- Windows in a full-screen space
- Windows that snap to their own minimum or maximum size

After **every** size write, read the frame back from the AX element and compare
against what was requested. Never assume a write succeeded. Never report success
from the return value of the write alone.

The result of a resize is a three-state outcome, not a boolean:
- exact — the readback matches the request
- partial — the window resized but not to the requested size (report both values)
- rejected — the window did not change, or the AX call errored

The UI must surface partial and rejected outcomes to the user. Silent failure is
the single worst bug this app can have.

### 4. Oversized resolutions are handled explicitly

A requested resolution larger than the target display must be detected and
handled by our own code, with an explicit decision surfaced to the user. It must
never be left to the OS to clamp silently.

The geometry layer must be able to answer, before any AX write: does this
resolution fit on this display, and if not, by how much.

## Code rules

### Resolution presets live in a single data model

One source of truth for every preset (resolution, aspect ratio, label). UI code
reads from it. **Never hardcode a resolution in UI code** — no `1920`, `1080`,
`16:9` literal in any view.

### All geometry math is pure

Every calculation — aspect ratio fitting, point/pixel conversion, centering,
display-bounds fitting, oversize detection — lives in pure, dependency-free
functions with no reference to `AXUIElement`, `NSScreen`, or any app state.
They take their inputs as parameters and return values. This makes them unit
testable without real windows.

If a piece of math needs a screen, the screen's relevant numbers are passed in
as a plain value type.

### The Accessibility layer sits behind a protocol

All AX access goes through a protocol (e.g. `WindowController`). Concrete
`AXUIElement` implementation on one side, a mock on the other. Tests never touch
the real AX API, and never require Accessibility permission to run.

Permission checking (`AXIsProcessTrustedWithOptions`) is part of that protocol's
surface, not scattered through the app.

### Dependencies

No third-party dependencies, with one exception:

- `KeyboardShortcuts` by Sindre Sorhus — and only once we reach the hotkeys
  phase. Do not add it before then.

Nothing else. No Sparkle, no logging frameworks, no Snapshot/Quick/Nimble.
XCTest only.
