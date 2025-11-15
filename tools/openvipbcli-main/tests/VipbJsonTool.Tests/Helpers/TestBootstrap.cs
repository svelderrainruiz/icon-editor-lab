using System.Runtime.CompilerServices;

namespace VipbJsonTool.Tests.Helpers;

/// <summary>
/// Module initializer wires the null Git helper into production code for all tests.
/// </summary>
internal static class TestBootstrap
{
    [ModuleInitializer]
    internal static void Init()
    {
        VipbJsonTool.Program.Git = new NullGitHelper();
    }
}