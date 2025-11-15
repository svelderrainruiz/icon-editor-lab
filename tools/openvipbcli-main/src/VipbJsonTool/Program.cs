using System;
using System.IO;
using System.Collections.Generic;

namespace VipbJsonTool;

internal static class Program
{
    private const string ToolName = "VipbJsonTool";

    /// <summary>
    /// Injected Git client.  
    /// • Production → <see cref="RealGitHelper"/> (default)  
    /// • Tests      → overridden with <c>NullGitHelper</c>
    /// </summary>
    public static IGitHelper Git { get; set; } = new RealGitHelper();

    private static int Main(string[] args)
    {
        try
        {
            if (args.Length < 2)
            {
                WriteUsage();
                return ExitCode.Usage;
            }

            var mode     = args[0].Trim().ToLowerInvariant();
            var inFile   = args[1];

            var outFile  = args.Length > 2
                ? args[2]
                : Path.ChangeExtension(
                    inFile,
                    mode switch
                    {
                        "vipb2json" => ".json",
                        "json2vipb" => ".vipb",
                        "patch2vipb" => ".vipb",
                        _ => string.Empty
                    });

            var patchFile   = args.Length > 3 ? args[3] : string.Empty;
            var alwaysPatch = args.Length > 4 ? args[4] : string.Empty;
            var branchName  = args.Length > 5 ? args[5] : string.Empty;
            var autoPr      = args.Length > 6 && bool.TryParse(args[6], out var b) && b;

            switch (mode)
            {
                case "vipb2json":
                    VipbToJsonConverter.Convert(inFile, outFile);
                    Commit(branchName, new[] { inFile, outFile, patchFile }, autoPr);
                    return ExitCode.Success;

                case "json2vipb":
                    JsonToVipbConverter.Convert(inFile, outFile);
                    Commit(branchName, new[] { inFile, outFile, patchFile }, autoPr);
                    return ExitCode.Success;

                case "patch2vipb":
                    Patch2VipbWorkflow.Run(inFile, patchFile, alwaysPatch, outFile);
                    Commit(branchName, new[] { inFile, outFile, patchFile, alwaysPatch }, autoPr);
                    return ExitCode.Success;

                default:
                    Console.Error.WriteLine($"{ToolName}: unknown mode '{mode}'.");
                    return ExitCode.UnknownMode;
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"{ToolName}: fatal error – {ex.Message}");
            return ExitCode.Fatal;
        }
    }

    private static void WriteUsage()
    {
        Console.Error.WriteLine(
            $"Usage: {ToolName} <mode> <inFile> [outFile] [patchFile] [alwaysPatch] [branchName] [autoPr]");
        Console.Error.WriteLine("  mode ∈ { vipb2json | json2vipb | patch2vipb }");
    }

    /// <summary>
    /// Invoke the configured IGitHelper only when a branch was supplied.
    /// </summary>
    private static void Commit(string branch, IEnumerable<string> paths, bool autoPr)
    {
        if (!string.IsNullOrWhiteSpace(branch))
            Git.CommitAndPush(paths, branch, autoPr);
    }
}
