using System.Collections.Generic;

namespace VipbJsonTool;

/// <summary>
/// Abstraction over Git operations so unit‑tests can swap in a stub.
/// </summary>
public interface IGitHelper
{
    void CommitAndPush(IEnumerable<string> paths, string branchName, bool autoPr);
}