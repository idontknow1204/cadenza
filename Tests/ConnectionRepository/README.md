# Connection Repository Tests

These tests use an ephemeral URLSession and URLProtocol-backed responses at
`connection-tests.invalid`. They never send requests to the live database.

Run from the repository root after resolving the app's Supabase package into
`build/SourcePackages/checkouts/supabase-swift`:

```sh
mkdir -p /private/tmp/CadenzaConnectionsTests
CADENZA_ROOT="$PWD" xcodegen generate --spec Tests/ConnectionRepository/project.yml --project /private/tmp/CadenzaConnectionsTests
xcodebuild -project /private/tmp/CadenzaConnectionsTests/CadenzaConnectionsTests.xcodeproj -scheme CadenzaConnectionsTests -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Covers send/cancel/re-send, preserving accepted connections and incoming
requests, and propagating failed status reads instead of reporting no connection.
