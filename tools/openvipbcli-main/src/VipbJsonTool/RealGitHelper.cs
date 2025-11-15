using System.Collections.Generic;

namespace VipbJsonTool;

/// <summary>
/// Thin adapter that forwards to the existing static <c>GitHelper</c>.
/// </summary>
internal sealed class RealGitHelper : IGitHelper
{
    public void CommitAndPush(IEnumerable<string> paths, string branchName, bool autoPr) =>
        GitHelper.CommitAndPush(paths, branchName, autoPr);
}