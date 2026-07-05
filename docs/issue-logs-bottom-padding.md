# Log entries hidden behind BottomNavigationView

## Summary

The last few log entries in the Logs tab are hidden behind the bottom navigation bar and cannot be scrolled into view.

## Root cause

`LogsFragment` used a `WindowInsets` listener that set the RecyclerView's bottom padding to `systemBars().bottom`. This is the system navigation bar height (~16-48dp), but the actual element overlapping the RecyclerView is `BottomNavigationView` (whose measured height includes the system nav bar padding internally, via Material Components). The padding needs to match `BottomNavigationView`'s height, not just the system nav bar.

## Fix

Use `bottomNav.addOnLayoutChangeListener()` to set padding to the actual measured height of `BottomNavigationView`. This fires after layout (including rotation), so the height is always correct. Fall back to the original `systemBars().bottom` if `bottomNav` is not found.

```java
View bottomNav = requireActivity().findViewById(R.id.bottomNav);
if (bottomNav != null) {
    bottomNav.addOnLayoutChangeListener(
        (nav, left, top, right, bBottom, oldLeft, oldTop, oldRight, oldBottom) -> {
          int bottom = nav.getHeight();
          logRecyclerView.setPadding(
              logRecyclerView.getPaddingLeft(), logRecyclerView.getPaddingTop(),
              logRecyclerView.getPaddingRight(), bottom);
        });
} else {
    // fallback: use system nav bar height
    ViewCompat.setOnApplyWindowInsetsListener(logRecyclerView, (v, insets) -> {
        int bottom = insets.getInsets(WindowInsetsCompat.Type.systemBars()).bottom;
        v.setPadding(v.getPaddingLeft(), v.getPaddingTop(), v.getPaddingRight(), bottom);
        return insets;
    });
}
```

- `OnLayoutChangeListener` fires after every layout pass, so rotation is handled correctly
- `bottomNav.getHeight()` includes Material Components' internal padding for the system nav bar
- Fallback preserves original behavior if `bottomNav` is absent
