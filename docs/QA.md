# ScreenResize — pre-release manual QA

Run before any release. Target: **under 15 minutes**. Times per case are budgets, not guesses.

Automated tests cover the pure logic (`./scripts/test.sh`, 129 tests). This checklist covers
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

Expected values depend on your current resolution and Dock size. **The config changed between
two of my own sessions**, so re-measure rather than assuming:

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
| Display | 1800 × 1169 pt, **2× scale** (3600 × 2338 px) |
| Visible frame | 1800 × 1065 pt at AppKit origin (0, 65) |
| Chrome | 39 pt menu bar, 65 pt Dock |

**If your numbers differ, recompute:**
- Fits when `target ≤ 1800 × 1065` pt
- Centred AX origin: `x = (1800 − w) / 2`, `y = 1169 − (65 + (1065 − h) / 2 + h)`

---

## 1. Native app that resizes cleanly (2 min)

1. Open Safari. Give it an obviously non-preset size by dragging a corner.
2. Click the ScreenResize menu bar icon.
3. Confirm the header reads **`Safari`**, its current size in points, and **`2× display`**.
4. Set the mode picker to **Logical**.
5. Open **16:9** and click **`1280x720 — 720p / HD`**.

**Expected:**
- Safari becomes exactly **1280 × 720 pt**, centred: AX origin **(260, 211.5)**.
- Visually: equal margins left and right, and the window sits below the menu bar.
- Reopen the menu — header now reads **`1280 × 720 pt`**.
- No orange failure banner.

Repeat once with Finder to confirm it is not Safari-specific.

## 2. A window that refuses to resize (1 min)

Use a fixed-size window. **System Settings** works; so does most apps' About box
(Safari → About Safari).

1. Focus the fixed-size window.
2. Open the menu — the header should name that app.
3. Pick any enabled size.

**Expected:**
- An orange banner: **`<App> refused to resize to 1280 × 720 pt.`**
- The window does **not** move or change size.
- The app does not crash or hang.

**A silent no-op here is the worst possible outcome** and is an immediate release blocker.
Silent failure is the one thing CLAUDE.md calls out as unacceptable.

⚠️ The message never states the size the window actually is — see Known Issue **5**.

## 3. Electron app (2 min)

Use VS Code, Slack, Discord, or Figma.

1. Focus the Electron window and resize it by dragging first.
2. Open the menu, pick **`1280x720`** in Logical mode.

**Expected (best case):** resizes exactly like case 1, banner absent.

**Also acceptable:** a banner reading `… resized to <actual> instead of 1280 × 720 pt.` when the
app enforces a minimum size — that is a truthful partial result.

⚠️ **A `refused to resize` banner while the window visibly did resize is a bug**, not a pass.
That is Known Issue **3** — there is no settle time before the readback. Note which app and
whether the window actually moved.

## 4. Full-screen window (1 min)

1. Put Safari into full screen (green button, or ⌃⌘F).
2. Open the ScreenResize menu.
3. Pick any enabled size.

**Expected as currently built:**
- Either the header reads **`Safari has no resizable window.`** with no size lists, **or** a
  banner reading `Safari refused to resize to …`.
- The full-screen window is unchanged, and macOS does not leave full screen.

⚠️ Neither message mentions full screen. The app has no full-screen detection at all — see
Known Issue **4**. Both outcomes above are a pass *today*; neither is good.

## 5. Window straddling two displays (1 min — needs a second display)

1. Drag a Safari window so roughly **60%** sits on the external display and 40% on the laptop.
2. Open the menu and note which display's scale the header reports.
3. Pick **`1280x720`** in Logical mode.

**Expected:**
- The header reports the scale of the display holding **most** of the window.
- The window jumps **entirely onto that display**, centred there — it does not stay straddled.
- Repeat with the majority on the other display and confirm it follows.

Selection is by overlapping area, so the 60/40 split should be decisive. A 50/50 split is
undefined; do not test it.

## 6. Laptop vs external display with a different scale factor (2 min — needs a second display)

Best with a 1× external monitor beside the 2× laptop panel.

1. Put a Safari window **fully on the laptop** (2×). Open the menu.
   - Header shows **`2× display`**.
   - In **Capture** mode, `2560x1440` should be **enabled** (→ 1280 × 720 pt).
2. Move the same window **fully onto the external display** (1×). Reopen the menu.
   - Header shows **`1× display`**.
   - In **Capture** mode, `2560x1440` is now **disabled** unless that display is at least
     2560 × 1440 pt of visible space, because at 1× the target is 2560 × 1440 points.

**Expected:** the same preset changes availability purely because the display changed. That is
the whole point of Capture mode, and getting the same answer on both displays is a bug.

⚠️ Do not leave the menu open while dragging the window between displays — see Known Issue **7**.

## 7. Logical vs Capture, against a real screen recording (3 min)

The one case that proves Capture mode does what it claims. **Use the same preset in both modes.**

**7a — Logical**
1. Mode picker → **Logical**. Pick **16:9 → `1280x720`**.
2. Capture the window without its shadow, then measure:

```bash
screencapture -o -w ~/Desktop/logical.png     # click the Safari window
sips -g pixelWidth -g pixelHeight ~/Desktop/logical.png
```

**Expected: `pixelWidth: 2560`, `pixelHeight: 1440`.**
Logical means points: a 1280 × 720 pt window on a 2× display is 2560 × 1440 **pixels**.

**7b — Capture**
1. Mode picker → **Capture**. Pick **16:9 → `1280x720`** again.
2. Repeat the capture:

```bash
screencapture -o -w ~/Desktop/capture.png
sips -g pixelWidth -g pixelHeight ~/Desktop/capture.png
```

**Expected: `pixelWidth: 1280`, `pixelHeight: 720`.**
The window is now 640 × 360 pt (AX origin **(580, 391.5)**), which is exactly 1280 × 720 pixels.

**The pass condition is that these two differ by exactly 2×.** If both give 2560 × 1440, the
mode picker is not taking effect.

**On using an actual recording:** ⌘⇧5 → *Record Selected Window* also works, and
`mdls -name kMDItemPixelWidth -name kMDItemPixelHeight <file>` reads its dimensions — but the
window recorder **includes the drop shadow**, so expect roughly 100–200 px of padding on each
axis. Use it to confirm the recording looks right; use `screencapture -o` above for the exact
number.

## 8. Permission revoked mid-session (2 min)

1. With the app working, open System Settings → Privacy & Security → Accessibility.
2. Toggle **ScreenResize off**. Leave System Settings open.
3. Click the ScreenResize menu bar icon.

**Expected:**
- The menu body is **replaced entirely** by the permission call to action. No header, no mode
  picker, no favorites, no size lists anywhere.
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
- **No size lists, no favorites, no mode picker** — only the reason, Settings, and Quit.
- No crash, no banner, no spinner.

3. Open a Finder window (⌘N) and reopen the menu — the full menu returns.

⚠️ The mode picker is unreachable in this state — see Known Issue **10**.

## 10. Favorites, custom sizes, hotkeys, login item (2 min)

1. Settings → **Favorites** → star `1280x720` and `1024x768`.
   → Menu shows a **Favorites** section above the groups, in star order, with star icons.
2. Settings → **Custom Sizes** → enter `1720` × `1000`.
   → Live ratio reads **`43:25`** before you click Add. After Add, a **Custom** submenu appears
   above 16:9 containing `1720x1000 — 43:25`.
   → Enter `1920` × `1080` and click Add: **`1920x1080 is already in your custom sizes.`**
3. Settings → **Shortcuts** → record a shortcut for **Favorite 1**. Close Settings, focus Safari,
   press it.
   → Safari resizes to `1280x720`.
4. Settings → **General** → **Launch at login**.
   → Running from DerivedData this is **disabled**, with text telling you to move the app to
   Applications. That is correct behaviour, not a bug.
5. Quit and relaunch. Favorites, custom sizes and sizing mode all persist
   (`~/Library/Preferences/com.deiondrickroberts.ScreenResize.plist`).

---

# Known broken or unhandled

Findings from reading the code as committed at `66b6221`. Ordered by severity.

### 1. A clamped resize is silently shrunk — violates CLAUDE.md constraint 4

`MenuBarModel.swift:356` — `let (target, _) = WindowGeometry.clamped(...)`.

`ClampAdjustment` was built in Phase 3 precisely so a shrink-to-fit could never be silent, and
`apply()` discards it. If a target does not fit the display at click time, the window is quietly
resized to something the user did not choose, with no banner. This is a self-inflicted regression
against a hard constraint. **Most likely to bite in case 5 or 6.**

### 2. Opening Settings erases the failure banner

`MenuBarContentView.swift` subscribes to `NSWindow.didBecomeKeyNotification` for **any** window in
the process, and calls `model.refresh()`, which clears `failureMessage`. So the sequence
"resize refused → open Settings to investigate" wipes the explanation. It also re-runs the whole
AX read whenever Settings or onboarding takes focus, menu closed or not.

### 3. No settle time before the readback — false rejections likely on Electron

`AXWindowManager.applyFrame` reads the frame back **immediately** after the write loop, with no
delay or retry. Apps that resize asynchronously (Electron, Java/Swing) can still report their old
frame at that instant, producing `refused to resize` for a window that visibly did resize. This is
the most likely cause of a bogus failure in case 3.

### 4. No full-screen or minimized detection

`kAXFullScreen` and `kAXMinimized` are never read anywhere. A full-screen window degrades to a
generic "refused to resize", and a minimized window's off-screen AX position produces
`That window is not on any display.` Both are truthful but unhelpful, and CLAUDE.md explicitly
lists full screen as a rejection cause worth naming.

### 5. The rejection message throws away the actual size

`apply()` catches `resizeRejected(let requested, _)` and discards `actual`. The error carries the
window's real size and the UI never shows it, so the banner cannot say what the window *is*, only
what it refused to become.

### 6. Hotkey failures are invisible until you open the menu

`applyFavoriteSlot` sets `failureMessage` for an empty slot, an out-of-range slot, or a size too
large — but a hotkey fires with no menu open, so nothing is displayed. Pressing a shortcut bound
to an empty slot appears to do nothing at all.

### 7. `isEnabled` goes stale if the window changes display while the menu is open

Options are computed against the display found at menu-open; `apply()` re-resolves the display at
click time. Move the window to a different-scale display with the menu open and an option shown as
enabled may no longer fit — at which point issue **1** silently shrinks it.

### 8. A hotkey pressed while ScreenResize's own window is focused targets an unseen window

The frontmost tracker deliberately ignores ScreenResize itself, so a shortcut pressed while
Settings or onboarding has focus resizes whatever app was active before — a window the user is not
looking at.

### 9. Duplicate custom size blames the wrong list

`CustomSizeError.duplicate` always reads `<name> is already in your custom sizes.`, but the check
runs against `allResolutions`, which includes the shipped catalog. Adding `1920x1080` — a built-in
preset you never created — claims it is already in *your* custom sizes. Correct refusal, wrong
explanation. Visible in case 10 step 2.

### 10. The sizing mode picker is unreachable with no target window

In `.noTargetWindow` the menu renders only the reason and the footer. Sizing mode can still be
changed in Settings, but not from the menu, which is where it lives the rest of the time.

### Not bugs, but expect them

- **Launch at login is disabled** unless the app is in an Applications folder. Deliberate: a login
  item pointing into DerivedData would break on the next clean build.
- **Accessibility permission dies on every rebuild.** The designated requirement is a bare cdhash.
  A self-signed certificate fixes it permanently — steps are in CLAUDE.md.
- **1080-tall targets are borderline.** At 1800 × 1169 pt the visible frame is only 1065 pt tall,
  so anything 1080 pt tall is *too large by 15 points*. This has caught me twice in test
  expectations; it will look like a bug and is not.
