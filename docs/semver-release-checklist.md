# SemVer Bundle Pre-Release Checklist

To keep evidence consistent across releases, run the VS Code task **SemVer: Export & Verify** (Command Palette → Tasks: Run Task). That task executes the steps below in sequence:

1. `SemVer: Export Bundle`
   ```powershell
   pwsh -NoLogo -NoProfile -File tools/Export-SemverBundle.ps1 \
       -IncludeWorkflow -GenerateIssueTemplate -Zip
   ```
   - Emits `out/semver-bundle/<timestamp>/` + `.zip`
   - Includes workflow, checklist, issue template, bundle manifest
2. `SemVer: Verify Bundle`
   ```powershell
   pwsh -NoLogo -NoProfile -File tools/Verify-SemverBundle.ps1 \
       -BundlePath out/semver-bundle/<timestamp>
   ```
   - Confirms hashes from `bundle.json`

**Default Pre-Release Flow**
- Run “SemVer: Export & Verify” before pushing release commits.
- Attach the generated `…/semver-bundle/<timestamp>.zip` to the GitHub issue/release.
- Copy `ISSUE-TEMPLATE.md` from the bundle into the tracking issue.
- Keep the task output as evidence that the bundle was produced and verified locally.
