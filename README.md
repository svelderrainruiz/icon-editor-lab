# Icon Editor Lab

Tooling, pipelines, and tests that support the Icon Editor lab experience.

## Release

1. Ensure the latest `develop` commit is green (CI + coverage gates ≥75%).
2. Tag the commit with the next semantic version (e.g., `git tag v0.2.0 && git push origin v0.2.0`).
3. The `release.yml` workflow runs automatically for `v*` tags or via `workflow_dispatch`, executes the Pester suite, enforces the coverage floors, uploads test/coverage artifacts, and creates the GitHub Release with those artifacts attached.
