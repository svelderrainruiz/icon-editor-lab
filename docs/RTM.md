# RTM (Requirements Traceability Matrix)

This table will expand over time; for now we seed clearly verifiable traces only.

| Req | Test | Code | Evidence |
|-----|------|------|----------|
| RQ-COV-0001 | tests/Sanity.Tests.ps1 | src/tools/Tools.psm1 | `.github/workflows/coverage.yml` uploads `artifacts/coverage/coverage.xml` + `artifacts/test-results/results.xml` |
| RQ-COV-0002 | tests/smoke/Smoke.Tests.ps1 | src/tools/icon-editor/IconEditorPackage.psm1 | Coverage workflow artifacts retained under `coverage-xml` and `junit-results` |

Future requirements should be added only when the linked test, code, and evidence are available in the repository or CI artifacts.
