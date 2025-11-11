# Cross-Repo Dependencies

The following files still reference `compare-vi-cli-action` (hard-coded repo
names, local paths, or GitHub metadata). They need follow-up work before we can
declare this repository fully standalone.

| File | Reference | Why it matters | Proposed action |
| --- | --- | --- | --- |
| `.gitignore` | `compare-vi-cli-action.sln` entries | Legacy ignore rules copied from the composite action | Remove once the history is trimmed; they have no effect here |
| `README.md` / `docs/MIGRATION.md` | Text mentions of the old repo | Informational only | Keep but ensure messaging stays current |
| `tools/Check-PRMergeable.ps1`, `tools/Get-BranchProtectionRequiredChecks.ps1`, `tools/Publish-VICompareSummary.ps1`, `tools/Test-ForkSimulation.ps1` | Hard-coded `compare-vi-cli-action` repository names / slugs | These helpers were built for the composite repo’s GitHub automation | Decide whether they belong in the lab repo; otherwise drop or rename the metadata (e.g., point to `icon-editor-lab`) |
| `tools/dashboard/dashboard.html` | Absolute paths under `.../compare-vi-cli-action/...` baked into template sample data | Template is stale and refers to artifacts that only exist in the composite repo | Either remove the sample data block or update it to point at `icon-editor-lab` artifacts |

## Other shared helpers

The copied test suites currently rely only on modules that are now present in
this repo. Keep an eye on these directories whenever upstream changes land:

- `tests/_helpers` – not currently used by the icon-editor suites, but confirm
  before trimming.
- Shared schema or reporting modules under `tools/` that may still be required
  by `compare-vi-cli-action`. When in doubt, document the interface in
  `docs/CONSUMPTION.md` so downstream consumers can pin specific versions.

Open questions:

1. **GitHub API helpers** – do we still need `tools/Check-PRMergeable.ps1`,
   `tools/Publish-VICompareSummary.ps1`, etc., in the lab repo? If not, move
   them back to the composite repo or delete them here.
2. **Dashboard assets** – if the lab repo won’t host the HTML dashboards, drop
   `tools/dashboard/**` entirely to avoid misleading references.

Track resolutions in `docs/MIGRATION.md` as each dependency is removed or
updated.
