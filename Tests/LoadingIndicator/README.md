# Loading Indicator Checks

An isolated preview app exercises the production loading components without an
account or backend requests. It does not change the main app's launch behavior.

```sh
mkdir -p /private/tmp/CadenzaLoadingPreview
env CADENZA_ROOT="$PWD" xcodegen generate --spec Tests/LoadingIndicator/project.yml --project /private/tmp/CadenzaLoadingPreview
xcodebuild -project /private/tmp/CadenzaLoadingPreview/CadenzaLoadingPreview.xcodeproj -scheme CadenzaLoadingPreview -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Checks cover continuous forward rotation, repeated speed variation, the paused
state, native refresh decoration and cleanup, and repeated refresh actions.
Screenshots include gray logos on light, dark and burgundy backgrounds. Determinate progress retains
its linear indicator. The existing `FeedRefreshUITests.testRepeatedPullToRefresh`
also exercises the installed main app against its configured backend.
