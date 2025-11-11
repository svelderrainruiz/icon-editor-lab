# Get-FileSha256.ps1

**Path:** `tools/Get-FileSha256.ps1`

## Synopsis
Computes the SHA-256 digest of a file, outputting hex (default) or Base64.

## Description
- Validates that `-Path` points to a file, resolves it to an absolute path, and streams it through `System.Security.Cryptography.SHA256`.
- `-AsBase64` switches the output format from the default lowercase hex string to Base64.
- Handy for verifying bundle contents before publishing artifacts or for doc tables that include checksum columns.

### Parameters
| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `Path` | string (required) | - | File to hash. |
| `AsBase64` | switch | Off | Emit Base64 digest instead of hex. |

## Exit Codes
- `0` on success; errors are thrown for missing files.

## Related
- `tools/Export-LabTooling.ps1`
