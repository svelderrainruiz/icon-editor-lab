using System;
using System.Diagnostics;
using System.IO;
using XCli.Simulation;

namespace XCli.ViAnalyzer;

public static class ViAnalyzerVerifyCommand
{
    public static SimulationResult Run(string[] args)
    {
        string? labviewPath = null;
        string? labviewCliPath = null;

        for (var i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            if (arg == "--labview-path" && i + 1 < args.Length)
            {
                labviewPath = args[++i];
            }
            else if (arg == "--labviewcli" && i + 1 < args.Length)
            {
                labviewCliPath = args[++i];
            }
            else
            {
                Console.Error.WriteLine($"[x-cli] vi-analyzer-verify: unknown argument '{arg}'.");
                return new SimulationResult(false, 1);
            }
        }

        if (string.IsNullOrWhiteSpace(labviewPath))
        {
            Console.Error.WriteLine("[x-cli] vi-analyzer-verify: --labview-path PATH is required.");
            return new SimulationResult(false, 1);
        }

        string resolvedLabviewPath;
        try
        {
            resolvedLabviewPath = ResolveLabVIEWExecutable(labviewPath!);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[x-cli] vi-analyzer-verify: {ex.Message}");
            return new SimulationResult(false, 1);
        }

        string resolvedCliPath;
        try
        {
            resolvedCliPath = ResolveLabVIEWCliPath(labviewCliPath, resolvedLabviewPath);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[x-cli] vi-analyzer-verify: {ex.Message}");
            return new SimulationResult(false, 1);
        }

        Console.WriteLine($"[x-cli] vi-analyzer-verify: LabVIEW executable found at '{resolvedLabviewPath}'.");
        Console.WriteLine($"[x-cli] vi-analyzer-verify: LabVIEWCLI.exe found at '{resolvedCliPath}'.");
        return new SimulationResult(true, 0);
    }
    private static string ResolveLabVIEWExecutable(string candidate)
    {
        var fullPath = Path.GetFullPath(candidate);
        if (Directory.Exists(fullPath))
        {
            var exeCandidate = Path.Combine(fullPath, "LabVIEW.exe");
            if (!File.Exists(exeCandidate))
            {
                throw new FileNotFoundException($"LabVIEW.exe not found in '{fullPath}'.");
            }
            return exeCandidate;
        }

        if (!File.Exists(fullPath))
        {
            throw new FileNotFoundException($"LabVIEW path not found: '{fullPath}'.");
        }

        return fullPath;
    }

    private static string ResolveLabVIEWCliPath(string? explicitPath, string labviewExePath)
    {
        if (!string.IsNullOrWhiteSpace(explicitPath))
        {
            var cliPath = Path.GetFullPath(explicitPath);
            if (!File.Exists(cliPath))
            {
                throw new FileNotFoundException($"LabVIEWCLI.exe not found at '{cliPath}'.");
            }
            return cliPath;
        }

        var root = Path.GetDirectoryName(labviewExePath);
        if (string.IsNullOrWhiteSpace(root))
        {
            throw new InvalidOperationException("Unable to resolve LabVIEW installation root.");
        }

        var defaultCli = Path.Combine(root, "LabVIEWCLI.exe");
        if (!File.Exists(defaultCli))
        {
            throw new FileNotFoundException($"LabVIEWCLI.exe not found at '{defaultCli}'.");
        }
        return defaultCli;
    }

    private static string ReadLogTail(string logPath, int maxLines)
    {
        if (!File.Exists(logPath))
            return string.Empty;

        try
        {
            var lines = File.ReadAllLines(logPath);
            var tail = Math.Max(0, lines.Length - maxLines);
            return string.Join(Environment.NewLine, lines[tail..]);
        }
        catch
        {
            return string.Empty;
        }
    }
}
