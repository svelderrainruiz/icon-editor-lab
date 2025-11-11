# Build-VSCExtension.ps1

**Path:** `tools/Build-VSCExtension.ps1`

## Synopsis
Packages the CompareVI VS Code helper extension via `@vscode/vsce`, optionally bumps the patch version, and installs the resulting VSIX locally.

## Description
- Validates the extension workspace (`vscode/comparevi-helper` by default) and `package.json` metadata (`publisher`, `name`, `version`).
- Optional `-BumpPatch` increments the patch portion of `package.json` and writes it back (preserving formatting).
- Detects `npx`/`npm` to execute `vsce package --no-dependencies`; emits warnings when Node/npm/npx are missing.
- Places the VSIX under `artifacts/vsix/<publisher>.<name>-<version>.vsix` (override with `-OutDir`) and logs the absolute path.
- When `-Install` is set, attempts `code --install-extension <vsix> --force` (falling back to `code-insiders`/`codium` if needed).

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `ExtensionDir` | string | `vscode/comparevi-helper` | Extension source directory. |
| `OutDir` | string | `artifacts/vsix` | Where the packaged VSIX is stored. |
| `Install` | switch | Off | Installs the VSIX using the VS Code CLI after packaging. |
| `BumpPatch` | switch | Off | Increment the patch version in `package.json` before packaging. |
| `VsceVersion` | string | `latest` | Version of `@vscode/vsce` to run via `npx`/`npm exec`. |

## Exit Codes
- `0` when packaging (and optional install) succeed.
- Non-zero when prerequisites (Node/npm/npx, VS Code CLI, package.json fields) are missing or vsce/code commands fail.

## Related
- `vscode/comparevi-helper/package.json`
- `artifacts/vsix/`
