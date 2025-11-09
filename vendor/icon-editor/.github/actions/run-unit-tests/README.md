# Run Unit Tests ✅

Invoke **`RunUnitTests.ps1`** to execute LabVIEW unit tests and output a result table.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `minimum_supported_lv_version` | **Yes** | `2021` | LabVIEW major version. |
| `supported_bitness` | **Yes** | `32` or `64` | Target LabVIEW bitness. |
| `project-file` | No | `vendor/icon-editor/lv_icon_editor.lvproj` | Project override (absolute or repo-relative). |
| `label` | No | `run-unit-tests-64` | Overrides the suite/report label (defaults to `run-unit-tests-<bitness>`). |

## Quick-start
```yaml
- uses: ./.github/actions/run-unit-tests
  with:
    minimum_supported_lv_version: 2024
    supported_bitness: 64
    label: run-unit-tests-64
```

Each run is wrapped with `tools/Invoke-WithTranscript.ps1`, so the job summary links to
`tests/results/_agent/logs/run-unit-tests-*.log` and a structured JSON report under
`tests/results/_agent/reports/unit-tests/`.

## License
This directory inherits the root repository's license (MIT, unless otherwise noted).
