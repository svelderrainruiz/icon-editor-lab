using System.Collections.Generic;
using VipbJsonTool;

namespace VipbJsonTool.Tests.Helpers;

/// <summary>No‑op implementation used in the test suite (Git not required).</summary>
internal sealed class NullGitHelper : IGitHelper
{
    public void CommitAndPush(IEnumerable<string> paths, string branchName, bool autoPr) { /* noop */ }
}