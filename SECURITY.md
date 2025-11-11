# Security Policy

## Supported versions
We actively support CI and fixes for LabVIEW 2021/2023 and VIPM versions currently referenced in this repository.

## Reporting a vulnerability
Please create a private advisory or contact the maintainers. Do not open public issues for security reports. 
Include: component, version, steps to reproduce, and logs (with secrets redacted).

## Execution policy
All CI scripts should be signed before enabling AllSigned execution policy in Windows jobs. Ubuntu CI uses PSScriptAnalyzer and schema gates.
