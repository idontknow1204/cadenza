# Jobs UI checks

Uses the production Jobs views, models, localization, assets and loading component.
`prepare.py` extracts the current shared header/separator and flow layout into the
temporary project because they live in larger production files. The repository and
session are isolated fixtures; no backend credentials or network access are used.

```sh
python3 Tests/JobsUI/prepare.py
# Use the printed directory below.
xcodebuild -project <printed-directory>/CadenzaJobsPreview.xcodeproj \
  -scheme CadenzaJobsPreview \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/cadenza-jobs-test-build \
  -resultBundlePath /tmp/cadenza-jobs-checks.xcresult \
  CODE_SIGNING_ALLOWED=NO test
```

Checks cover expired/closed/announced/inactive records, today and no-deadline records,
combined instrument/country/video/free filters, unknown fees, search with filters,
search failure, stale responses, navigation back to search, contact-copy feedback,
and German/dark mode/accessibility text. Screenshots are retained in the result bundle.
Regenerate the temporary project after editing the shared header or flow layout.
