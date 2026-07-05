# Touchpad overlay intercepts GBoard key presses and IME fails to show

## Summary

Two related IME issues when using the touchpad with an external display:

1. **GBoard keys unresponsive:** When GBoard appears on the built-in display, alphabet keys and prediction candidates don't work — the touchpad overlay intercepts their touch events.
2. **IME doesn't appear on tap:** Tapping an input field (especially HTML `<input>` in WebView/Chrome) on the external display via the trackpad often fails to bring up the keyboard.

## Environment

- Device: Pixel 10 Pro
- IME: GBoard
- IME policy: `DISPLAY_IME_POLICY_FALLBACK_DISPLAY` (GBoard renders on Display 0 for inputs on the external display)

---

## Issue 1: GBoard keys intercepted by overlay

### Symptoms

| Input | Behavior |
|-------|----------|
| Alphabet keys (a-z) | No response; finger drag moves mouse cursor |
| Enter / Backspace | Works reliably |
| Space / Period | Occasionally works |
| Prediction candidates | Tapping dismisses keyboard without inserting text |

### Root cause

The touchpad uses a `TYPE_APPLICATION_OVERLAY` (or `TYPE_ACCESSIBILITY_OVERLAY`) positioned exactly over `touchpadArea`. Its `OnTouchListener` returns `true` unconditionally, consuming every touch event within its bounds.

When GBoard appears, it is layered above the overlay visually (thanks to `FLAG_ALT_FOCUSABLE_IM`), but touch dispatch still delivers events to the overlay for the overlapping region. The overlay consumes them as trackpad gestures, so GBoard never receives the taps.

**Why Enter/Backspace worked:** On the tested device layout, these keys sit over the `scrollStrip` view — which is adjacent to (not underneath) the overlay. Touches in that region reach GBoard normally.

**Why prediction candidates failed:** The overlay's actual screen position differs from `touchpadArea.getLocationOnScreen()` by the status bar height (172px), because the accessibility overlay is placed in absolute screen coordinates. The initial shrink calculation was short by that offset.

### Fix

Detect IME visibility via `WindowInsets.Type.ime()` and shrink the overlay height so it does not cover the keyboard. Use the overlay's own `getLocationOnScreen()` rather than `touchpadArea`'s position for the calculation.

```java
if (imeVisible && imeHeight > 0 && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
    WindowInsets rootInsets = getWindow().getDecorView().getRootWindowInsets();
    if (rootInsets != null) {
        Insets imeInsets = rootInsets.getInsets(WindowInsets.Type.ime());
        View decorView = getWindow().getDecorView();
        int[] decorLoc = new int[2];
        decorView.getLocationOnScreen(decorLoc);
        int imeTop = decorLoc[1] + decorView.getHeight() - imeInsets.bottom;

        int overlayY = loc[1];
        if (touchpadOverlay != null) {
            int[] overlayLoc = new int[2];
            touchpadOverlay.getLocationOnScreen(overlayLoc);
            overlayY = overlayLoc[1];
        }
        if (overlayY + height > imeTop) {
            height = Math.max(0, imeTop - overlayY);
        }
    }
}
```

---

## Issue 2: IME doesn't appear when tapping input fields

### Symptoms

- Tapping Chrome's URL bar (native EditText) via the trackpad → IME appears reliably
- Tapping a Google Search page input field (HTML `<input>` in WebView) → IME often fails to appear
- Tapping a second time sometimes works

### Root causes (two sub-issues)

#### 2a. Missing window focus before tap injection

The `_replayPendingTap()` method in the inputManager path injected touch events to the external display **without first setting window focus** on that display. Without window focus, `InputMethodManager` ignores `showSoftInput()` requests from the tapped View.

The accessibility path already called `service.setFocus(displayId)` before dispatch, which is why the issue was less frequent there.

**Fix:** Call `setFocus(inputManager, displayId)` before injecting tap events:

```java
ipcExecutor.execute(() -> {
    setFocus(inputManager, displayId);
    for (MotionEvent event : toReplay) {
        // ... inject events
    }
});
```

#### 2b. Overlay shrink dismisses IME immediately

When the IME appeared, the `WindowInsets` listener detected `imeVisible=true` and immediately called `_syncTouchpadOverlay()`, which resized the `FLAG_ALT_FOCUSABLE_IM` overlay via `updateViewLayout()`. This layout change caused the system to dismiss the IME it had just shown.

Additionally, `touchpadArea`'s `OnLayoutChangeListener` fired from the IME-induced layout shift and called `_syncTouchpadOverlay()` directly, bypassing any delay.

**Fix:** Delay the overlay shrink by 300ms after IME becomes visible, and block `OnLayoutChangeListener` from triggering a shrink during that window:

```java
private boolean imeShrinkPending = false;
private final Runnable imeShrinkRunnable = () -> {
    imeShrinkPending = false;
    _syncTouchpadOverlay();
};

// In OnLayoutChangeListener:
if (!imeShrinkPending) {
    _syncTouchpadOverlay();
}

// In WindowInsets listener:
if (imeVisible) {
    imeShrinkPending = true;
    mainHandler.postDelayed(imeShrinkRunnable, 300);
} else {
    imeShrinkPending = false;
    _syncTouchpadOverlay();  // restore immediately
}
```

---

## Additional fix: LogsFragment bottom padding

The log list's bottom padding used `systemBars().bottom` (navigation bar height only), which didn't account for the `BottomNavigationView` height. The last log entries were hidden behind the tab bar.

**Fix:** Use the actual `BottomNavigationView` height after layout:

```java
View bottomNav = requireActivity().findViewById(R.id.bottomNav);
if (bottomNav != null) {
    bottomNav.post(() ->
        logRecyclerView.setPadding(..., bottomNav.getHeight()));
}
```

---

## Tradeoff

While the IME is visible, the touchpad's usable area is reduced (the bottom portion is cut off to make room for the keyboard). This is acceptable because the alternative — keyboard input being completely broken — is far worse. Users can still use the upper portion of the touchpad for cursor movement while typing.
