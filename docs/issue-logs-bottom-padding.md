# Log entries hidden behind BottomNavigationView

## Summary

The last few log entries in the Logs tab are hidden behind the bottom navigation bar and cannot be scrolled into view.

## Root cause

`LogsFragment` used a `WindowInsets` listener that set the RecyclerView's bottom padding to `systemBars().bottom` (the system navigation bar height, typically ~48px). This overwrote the XML-defined `paddingBottom="96dp"` and did not account for the `BottomNavigationView` height, which overlays the bottom of the fragment content via `layout_gravity="bottom"` in a `CoordinatorLayout`.

## Fix

Replace the `WindowInsets` listener with a simple `post()` callback that sets padding to the actual measured height of `BottomNavigationView`:

```java
View bottomNav = requireActivity().findViewById(R.id.bottomNav);
if (bottomNav != null) {
    bottomNav.post(() ->
        logRecyclerView.setPadding(
            logRecyclerView.getPaddingLeft(),
            logRecyclerView.getPaddingTop(),
            logRecyclerView.getPaddingRight(),
            bottomNav.getHeight()));
}
```

`bottomNav.post()` ensures the measurement runs after layout, so `getHeight()` returns the correct value. No hardcoded dp values or window insets needed — the padding exactly matches whatever the BottomNavigationView occupies.
