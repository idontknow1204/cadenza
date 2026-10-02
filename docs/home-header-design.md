# Home header design

The compact home header uses `CadenzaBrowseHeader`, shared with Jobs, in
`Cadenza/Features/Feed/FeedView.swift`. The original navigation title and native
search field remain in the `homeContent` fallback branch. Post cards are unchanged.

The `homeCompactHeaderEnabled` UserDefaults setting defaults to `true`.
To restore the original design by default, change its `@AppStorage` initial value
to `false`. No other UI changes need to be reverted.

For a temporary simulator comparison without rebuilding, terminate the app and
launch with an override:

```sh
xcrun simctl terminate booted com.cadenza.app.kkiri-coporation
xcrun simctl launch booted com.cadenza.app.kkiri-coporation -homeCompactHeaderEnabled NO
```

Use `YES` instead of `NO` to preview the compact header again. A normal launch
without arguments uses the default setting.

Header actions reuse the existing notification tab and activity creation sheet.
The home search spans the full header width; major filters were removed.
