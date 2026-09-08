# ScreenResize — pre-release manual QA

Run before any release. Target: **under 15 minutes**. Times per case are budgets, not guesses.

Automated tests cover the pure logic (`./scripts/test.sh`, 133 tests). This checklist covers
only what a machine cannot: real windows, real apps, real permission dialogs.

---

## Setup (2 min)

```bash
./scripts/test.sh && ./scripts/build.sh
open -n ~/Library/Developer/Xcode/DerivedData/ScreenResize/Build/Products/Debug/ScreenResize.app
```

**Grant Accessibility first.** Every rebuild invalidates the grant — the designated requirement
is a bare cdhash. If a case fails with a permission error on a build that worked minutes ago:

```bash
tccutil reset Accessibility com.deiondrickroberts.ScreenResize
```

### Measure your display before trusting any number below

Expected values depend on your current resolution and Dock size. **The config has changed
between every session I've written this from so far** — re-measure rather than assuming:

```bash
cat > /tmp/d.swift <<'EOF'
import AppKit
for (i, s) in NSScreen.screens.enumerated() {
    print("screen[\(i)] scale=\(s.backingScaleFactor) frame=\(s.frame) visible=\(s.visibleFrame)")
}
EOF
swift /tmp/d.swift
```

Every number in this document assumes the configuration measured at time of writing:

| | |
|---|---|
| Display | 3008 × 1692 pt, **2× scale** (6016 × 3384 px) |
| Visible frame | 3008 × 1597 pt at AppKit origin (0, 65) |
| Chrome | 30 pt menu bar, 65 pt Dock |

**If your numbers differ, recompute:**
- Fits when `target ≤ 3008 × 1597` pt
- Centred AX origin: `x = (3008 − w) / 2`, `y = 1692 − (65 + (1597 − h) / 2 + h)`

**The menu is one flat list.** Aspect-ratio submenus (16:9, 16:10, 3:2, 21:9, 4:3) were
removed; every preset is now a single click under **Preset Sizes**, ordered largest first, with
**Favorites** and **Custom Sizes** as sections above it. The list scrolls if it outgrows the
popover.

**Presets are point values, applied as-is.** A `1920x1080` preset makes a window measuring
1920×1080 points, on any display, regardless of scale factor. There is no pixel conversion and no
sizing-mode toggle.

**Nothing is ever greyed out.** A preset larger than the display is labelled `— fills this
display` and, when picked, fills the visible frame instead of refusing. On a 1800×1065pt screen
that applies to most of the catalog, so expect a lot of rows to say it.

---

## 1. Native app that resizes cleanly (2 min)

1. Open Safari. Give it an obviously non-preset size by dragging a corner.
2. Click the ScreenResize menu bar icon.
3. Confirm the header reads **`Safari`**, its current size in points, and **`2× display`**.
4. Under **Preset Sizes**, click **`1280x720 — 720p / HD`**.

**Expected:**
- The window becomes **1280 × 720 pt** — the preset's numbers, used directly.
- Visually: equal margins left and right, and the window sits below the menu bar.
- Reopen the menu — header now reads **`1280 × 720 pt`**.
- No orange failure banner.

Repeat once with Finder to confirm it is not Safari-specific.

## 2. A window that refuses to resize (1 min)

Use a fixed-size window. **System Settings** works; so does most apps' About box
(Safari → About Safari).

1. Focus the fixed-size window.
2. Open the menu — the header should name that app.
3. Pick **`1280x720`** (any enabled size works; this keeps the numbers below concrete).

**Expected:**
- An orange banner: **`<App> refused to resize to 1280 × 720 pt.`**
- The window does **not** move or change size.
- The app does not crash or hang.

**A silent no-op here is the worst possible outcome** and is an immediate release blocker.
Silent failure is the one thing CLAUDE.md calls out as unacceptable.

⚠️ The message never states the size the window actually is — see Known Issue **3**.

## 3. Electron app (2 min)

Use VS Code, Slack, Discord, or Figma.

1. Focus the Electron window and resize it by dragging first.
2. Open the menu, pick **`1280x720`**.

**Expected (best case):** resizes exactly like case 1 (1280 × 720 pt), banner absent.

**Also acceptable:** a banner reading `… resized to <actual> instead of 1280 × 720 pt.` when the
app enforces a minimum size — that is a truthful partial result.

⚠️ **A `refused to resize` banner while the window visibly did resize is a bug**, not a pass.
The readback now retries for up to 140ms to let async apps settle, so this should be rare. If it
still happens, note which app and whether the window actually moved — the settle budget may need
raising for that app.

## 4. Full-screen window (1 min)

1. Put Safari into full screen (green button, or ⌃⌘F).
2. Open the ScreenResize menu.
3. Pick any enabled size.

**Expected as currently built:**
- Either the header reads **`Safari has no resizable window.`** with no size lists, **or** a
  banner reading `Safari refused to resize to …`.
- The full-screen window is unchanged, and macOS does not leave full screen.

⚠️ Neither message mentions full screen. The app has no full-screen detection at all — see
Known Issue **2**. Both outcomes above are a pass *today*; neither is good.

## 5. Window straddling two displays (1 min — needs a second display)

1. Drag a Safari window so roughly **60%** sits on the external display and 40% on the laptop.
2. Open the menu and note which display's scale the header reports.
3. Pick **`1280x720`**.

**Expected:**
- The header reports the scale of the display holding **most** of the window.
- The window jumps **entirely onto that display**, centred there — it does not stay straddled.
- Repeat with the majority on the other display and confirm it follows.

Selection is by overlapping area, so the 60/40 split should be decisive. A 50/50 split is
undefined; do not test it.

## 6. Laptop vs external display (2 min — needs a second display)

Presets are points, so the same preset should produce the **same on-screen size** on both
displays. What changes between them is only whether it fits.

1. Put a Safari window **fully on the laptop**. Open the menu, pick **`1280x720`**.
   → Window becomes 1280 × 720 pt.
2. Move it **fully onto the external display**. Reopen the menu, pick **`1280x720`** again.
   → Window becomes 1280 × 720 pt again — the same size, regardless of that display's scale.

**Expected:** identical point size on both. The header's `1×`/`2× display` readout should change
to match the display, but it must not change the resulting window size.

Also check a preset larger than the smaller display (e.g. `2560x1440`): it should read
`— fills this display` on whichever screen cannot hold it, and fill that screen when picked.

⚠️ Do not leave the menu open while dragging the window between displays — see Known Issue **5**.

## 7. Verify a size against a real screenshot (2 min)

1. Pick **`1280x720`**. Capture the window without its shadow and measure:

```bash
screencapture -o -w ~/Desktop/size.png     # click the Safari window
sips -g pixelWidth -g pixelHeight ~/Desktop/size.png
```

**Expected on a 2× display: `pixelWidth: 2560`, `pixelHeight: 1440`.**
A 1280 × 720 **point** window is 2560 × 1440 **pixels** at 2×. That is correct, not a bug —
presets are points, so the pixel count doubles on a Retina panel.

On a 1× display the same window captures at 1280 × 720 pixels.

**If you need capture-exact pixel dimensions** (e.g. recording a true 1920×1080 video), a point
preset will not give it to you on a Retina display. That capability was removed along with the
sizing-mode toggle; say so if you want it back as an option.

## 8. Permission revoked mid-session (2 min)

1. With the app working, open System Settings → Privacy & Security → Accessibility.
2. Toggle **ScreenResize off**. Leave System Settings open.
3. Click the ScreenResize menu bar icon.

**Expected:**
- The menu body is **replaced entirely** by the permission call to action. No header, no
  favorites, no size lists anywhere.
- The onboarding window reappears on its own.

4. Toggle ScreenResize **back on**, then click the ScreenResize onboarding window.

**Expected:**
- Trust is re-detected on app activation, the onboarding window **closes by itself**, and the
  menu works again — **with no relaunch**.
- The Dock icon disappears again when onboarding closes. A Dock icon that stays behind is a bug.

## 9. Launch with no windows open anywhere (1 min)

1. Quit or close every window in every app, leaving only Finder with no windows.
2. Click the ScreenResize icon.

**Expected:**
- Header reads **`ScreenResize`** with a reason such as **`That application has no resizable
  window.`**
- **No size lists, no favorites** — only the reason, Settings, and Quit.
- No crash, no banner, no spinner.

3. Open a Finder window (⌘N) and reopen the menu — the full menu returns.

## 10. Favorites, custom sizes, hotkeys, login item (2 min)

1. Settings → **Favorites** → star `1280x720` and `1024x768`.
   → Menu shows a **Favorites** section at the top, in star order, with star icons.
   → The list is flat and includes any custom sizes, so those can be starred too.
2. Settings → **Custom Sizes** → enter `1720` × `1000`.
   → Live ratio reads **`43:25`** before you click Add. After Add, a **Custom Sizes**
   section appears in the menu above Preset Sizes, containing `1720x1000 — 43:25`.
   (Custom sizes are points too.)
   → Enter `1920` × `1080` and click Add: **`1920x1080 is already in your custom sizes.`**
3. Settings → **Shortcuts** → record a shortcut for **Favorite 1**. Close Settings, focus Safari,
   press it.
   → Safari's window becomes 1280 × 720 pt.
4. Settings → **General** → **Launch at login**.
   → Running from DerivedData this is **disabled**, with text telling you to move the app to
   Applications. That is correct behaviour, not a bug.
5. Quit and relaunch. Favorites and custom sizes both persist
   (`~/Library/Preferences/com.deiondrickroberts.ScreenResize.plist`).

---

# Known broken or unhandled

Findings from reading the code, updated after the resize-reliability work. Ordered by severity.

### 1. Opening Settings erases the failure banner

`MenuBarContentView.swift` subscribes to `NSWindow.didBecomeKeyNotification` for **any** window in
the process, and calls `model.refresh()`, which clears `failureMessage`. So the sequence
"resize refused → open Settings to investigate" wipes the explanation. It also re-runs the whole
AX read whenever Settings or onboarding takes focus, menu closed or not.

### 2. No full-screen or minimized detection

`kAXFullScreen` and `kAXMinimized` are never read anywhere. A full-screen window degrades to a
generic "refused to resize", and a minimized window's off-screen AX position produces
`That window is not on any display.` Both are truthful but unhelpful, and CLAUDE.md explicitly
lists full screen as a rejection cause worth naming.

*Partly addressed:* the Finder **desktop** is now detected (Finder + empty window title) and
reported as "no resizable window" rather than being resized. Full screen and minimized are still
undetected.

### 3. The rejection message throws away the actual size

`apply()` catches `resizeRejected(let requested, _)` and discards `actual`. The error carries the
window's real size and the UI never shows it, so the banner cannot say what the window *is*, only
what it refused to become.

### 4. Hotkey failures are invisible until you open the menu

`applyFavoriteSlot` sets `failureMessage` for an empty slot, an out-of-range slot, or a size too
large — but a hotkey fires with no menu open, so nothing is displayed. Pressing a shortcut bound
to an empty slot appears to do nothing at all.

### 5. `isEnabled` goes stale if the window changes display while the menu is open

Options are computed against the display found at menu-open; `apply()` re-resolves the display at
click time. Move the window to a different-scale display with the menu open and an option shown as
enabled may no longer fit — it is now shrunk to fit **and the shrink is reported**, so this
degrades gracefully rather than silently.

### 6. A hotkey pressed while ScreenResize's own window is focused targets an unseen window

The frontmost tracker deliberately ignores ScreenResize itself, so a shortcut pressed while
Settings or onboarding has focus resizes whatever app was active before — a window the user is not
looking at.

### 7. Duplicate custom size blames the wrong list

`CustomSizeError.duplicate` always reads `<name> is already in your custom sizes.`, but the check
runs against `allResolutions`, which includes the shipped catalog. Adding `1920x1080` — a built-in
preset you never created — claims it is already in *your* custom sizes. Correct refusal, wrong
explanation. Visible in case 10 step 2.

### Not bugs, but expect them

- **The sizing-mode toggle is gone.** Every preset now always targets pixels-relative-to-the-
  active-display (what used to be called "Capture" mode); there is no way to force a preset's raw
  numbers to be points regardless of scale. If you're looking for a "Logical" option from an
  earlier build, it was intentionally removed — see the note in Setup.
- **Launch at login is disabled** unless the app is in an Applications folder. Deliberate: a login
  item pointing into DerivedData would break on the next clean build.
- **Accessibility permission dies on every rebuild.** The designated requirement is a bare cdhash.
  A self-signed certificate fixes it permanently — steps are in CLAUDE.md.
- **A seemingly-safe round-number target can still miss by a few points.** The automated test
  fixtures deliberately include a case where a 1080pt-tall target misses a 1075pt-tall visible
  frame by 5 points — the menu bar and Dock eat more of the display than intuition suggests. The
  exact numbers depend entirely on *your* live display's chrome (see Setup); don't assume a given
  preset fits just because the display "looks big enough."
