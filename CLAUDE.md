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

### Accessibility permission is bound to the binary signature

Anything that touches windows needs ScreenResize to be trusted in
System Settings > Privacy & Security > Accessibility.

**The grant does not survive a rebuild.** This is not a quirk, it is exactly what the
signature says. Measured on a normal Debug build:

```
$ codesign -d -r- ScreenResize.app
# designated => cdhash H"68da219988da65029f94b556b86c070497e279ff"

$ codesign -dvv ScreenResize.app
Signature=adhoc          TeamIdentifier=not set
```

The designated requirement is **a bare cdhash** — no identifier, no certificate. There is no
Developer ID on this machine, so the app is ad-hoc signed, and TCC has nothing stabler than
the code hash to match a grant against. Every build produces a new hash, so every build
silently invalidates the grant while the entry still sits in the list looking enabled.

The symptom is `WindowManagerError.permissionDenied`, or an AX call returning
`kAXErrorAPIDisabled` (-25211), from a build that worked minutes earlier.

#### The real fix: sign with a self-signed certificate

Give the binary a stable identity and the requirement stops being hash-based:

```
# after (illustrative):
# designated => identifier "com.deiondrickroberts.ScreenResize"
#               and certificate leaf = H"..."
```

That requirement survives rebuilds, so the grant does too. Create the certificate once:

1. Keychain Access → Certificate Assistant → **Create a Certificate…**
2. Name `ScreenResize Dev`, Identity Type **Self Signed Root**, Certificate Type **Code Signing**
3. Create, then set `CODE_SIGN_IDENTITY = "ScreenResize Dev"` in the project's Debug configuration
4. Rebuild and confirm with `codesign -d -r-` that the requirement now names the certificate

This needs the Keychain Access GUI and an admin prompt, so it is a human step. It has not been
performed on this machine yet — the requirement above is what the certificate *will* produce,
not something measured here.

#### The fallback: reset and re-grant

Until that certificate exists, the fastest recovery is one command rather than toggling
switches in System Settings:

```bash
tccutil reset Accessibility com.deiondrickroberts.ScreenResize
```

Then relaunch and grant again. The app's onboarding window reappears automatically when it is
untrusted, and dismisses itself once permission is granted — no relaunch needed after granting.

---

## Stack

- Swift 5.9+
- SwiftUI. `MenuBarExtra` is the primary scene and the only one visible in normal
  use. Two others exist: a `Window` shown only during first-run onboarding while the
  app is untrusted, and a standard `Settings` scene. Because the app is `LSUIElement`,
  any such window must go through `ActivationPolicyCoordinator` rather than setting
  `NSApp.setActivationPolicy` directly, or windows bury each other
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

This is enforced mechanically, not by review. `scripts/check-ui-literals.sh` scans
the `ScreenResize/` app target for resolution-shaped numbers and runs as the first
step of `scripts/test.sh`. Comments are stripped before scanning; string literals
are not, because a hardcoded `"1920x1080"` in a view is exactly the violation.

If it flags a legitimate layout number, name the constant rather than widening the
script's exclusions.

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
