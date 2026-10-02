# Record composer layout loop

The previous chip grid measured a button after vertical padding and saved that
height in `@State`. It then applied the saved height to the text before adding
the same padding again. Each layout pass added another 16 points, causing another
preference update and layout pass. Opening the composer could keep the main
thread busy indefinitely rather than completing the sheet transition.

`EqualHeightChipLayout` now measures the complete buttons at their column width
with an unspecified height, then places them using the tallest intrinsic height.
Geometry is never fed into view state. Column widths scale with Dynamic Type.

The root tab binding also treats Record as an action. It presents the composer
without switching to the empty tab and then reversing that navigation.

## Regression checks

Install the current app on an authenticated simulator, then run the independent
UI test project (requires XcodeGen):

```sh
mkdir -p /private/tmp/CadenzaComposerUI
xcodegen generate --spec Tests/ComposerUI/project.yml --project /private/tmp/CadenzaComposerUI
xcodebuild -project /private/tmp/CadenzaComposerUI/CadenzaComposerUI.xcodeproj -scheme CadenzaComposerUI -destination 'platform=iOS Simulator,name=iPhone 17' test
```

The checks cover Record from Home and Profile, chip selection with stable height,
returning to the original tab on cancel, and the header composer in English and
German. They do not publish test posts.
