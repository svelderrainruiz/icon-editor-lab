# TestSelection.psm1

**Path:** `tools/Dispatcher/TestSelection.psm1`

## Synopsis
Filtering helpers for the dispatcher: apply include/exclude glob patterns to test files and remove self-test entries when running single-test scenarios.

## Description
- `Test-DispatcherPatternMatch` supports matching file names or full paths against glob-like patterns (`*`, `?`). Used internally by the dispatcher when deciding which tests to run.
- `Invoke-DispatcherIncludeExcludeFilter` applies include/exclude lists and returns both the filtered file list and metadata describing how many files were affected.
- `Invoke-DispatcherPatternSelfTestSuppression` removes the pattern self-test file (`Invoke-PesterTests.Patterns.Tests.ps1`) to avoid recursive selection, resetting `-SingleTestFile` when necessary.

## Related
- `Invoke-PesterTests.ps1`
- `tools/Dispatcher/RunnerInvoker.psm1`
