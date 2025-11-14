# render-ci-composite.ps1

**Path:** `tools/workflows/render-ci-composite.ps1`

## Synopsis
Renders the GitHub Actions composite workflow (`.github/workflows/ci-composite.yml`) from a Handlebars-style template, with an optional vendor variant for the embedded icon-editor repository.

## Description
- Loads `tools/workflows/templates/ci-composite.yml.tmpl`, evaluates `{{var}}` and `{{#if var}} ... {{/if}}` blocks using the provided context, and writes the result to `.github/workflows/ci-composite.yml`.
- By default also renders a vendor-specific file at `vendor/labview-icon-editor/.github/workflows/ci-composite.yml` unless `-RenderVendor:$false` is passed.
- Context variables capture runner labels, job dependencies, and path overrides for repo vs vendor clones, allowing one template to drive both workflows.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `RenderVendor` | switch | On | When set (default), render the vendor copy in `vendor/labview-icon-editor/...`. |

## Outputs
- `.github/workflows/ci-composite.yml` (root workflow).
- `vendor/labview-icon-editor/.github/workflows/ci-composite.yml` when `-RenderVendor` (default).

## Related
- `docs/LABVIEW_GATING.md`
- `tools/workflows/templates/ci-composite.yml.tmpl`

