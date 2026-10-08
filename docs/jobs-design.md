# Jobs design

Jobs follows the compact home header and feed rather than introducing another visual system.

- `CadenzaBrowseHeader` is shared with Home. Jobs hides the logo so the section title
  carries less brand weight, while preserving the Home title scale, 16-point gutters,
  44-point actions, 8-point corners, search field and `BrandSurface`. The Home
  notification/create/search actions and accessibility identifiers remain intact.
- Listings use full-width system-background surfaces with the Home `PostSeparator`.
  Organization and type precede the title, then location, instruments and relevant
  application facts. The type is communicated by its name and symbol; the accent
  color is shared. No card shadows or colored side stripes.
- Deadline badges use the same component in the list and detail. Only an open
  opportunity due within three days receives brand emphasis. Closed and upcoming
  opportunities have explicit labels.
- The filter row remains visible during search. Its visible chips are compact, but
  each control keeps a 44-point hit target. My instrument, open status and video
  rounds are shortcuts into the same filter state used by the full sheet.
  Other instruments, countries, costs, scholarships, types and sorting remain available.
- Search results use the active filters and sort. Requests debounce for 300 ms;
  cancelled or older responses cannot replace newer results. Loading, failure and
  genuinely empty results have distinct states. Existing data survives refresh errors.
- Open means active, open status and a deadline that is today or later (or unspecified).
  Turning off Open includes the other statuses returned by the existing repository.
- Detail retains description, requirements, contact and owner controls, and displays
  available video, free application, scholarship, event-date and age information.
  Contact copy gives temporary text confirmation. Closing an opportunity removes it
  from the calling Jobs list immediately.

## Suggested next steps (not implemented)

1. Save opportunities with optional deadline reminders. Ask about reminders only after
   saving, and keep reminder preferences per opportunity.
2. Preserve the user's preferred filters and offer explicit “save this search” alerts.
   Show why an opportunity matches (instrument/city), rather than an unexplained score.
3. Add pagination before presenting counts as archive-wide totals: the existing
   `jobs()` repository fetch is capped at 80 active records. Closed user posts are
   excluded by that endpoint even when the UI's Open filter is disabled.
4. Display structured fee currency once sources provide trustworthy fee data. The
   ingestion schema and application URL are implemented; unknown fees remain unlabeled.
5. Move list filters and cursor pagination fully to the server before the archive grows
   beyond the current 80-row list and 50-row search limits. The scheduled English/German
   ingestion pipeline is documented in
   [jobs-data-pipeline-analysis.md](jobs-data-pipeline-analysis.md).

## Validation

The application builds for iOS Simulator. `Tests/JobsUI` exercises the production Jobs
screens with an isolated in-memory repository; it does not authenticate, publish or
close real opportunities. See its README for repeatable checks and screenshots.

Validated on iPhone 17 / iOS 26.3: two filter tests and four UI tests passed.
After the accessibility layout adjustment, the dark/large-text and search/detail
checks passed again, and the full app build passed.

Fixture screenshots: [list](screenshots/jobs/list.png),
[detail](screenshots/jobs/detail.png),
[dark mode at maximum accessibility text size](screenshots/jobs/dark-large-text.png).
The preview uses a single Jobs tab; the production application's tabs are unchanged.
