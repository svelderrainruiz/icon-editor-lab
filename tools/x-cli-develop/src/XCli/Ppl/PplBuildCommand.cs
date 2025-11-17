using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using XCli.Simulation;

namespace XCli.Ppl;

public static class PplBuildCommand
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };
    private sealed class BuildRequest
    {
        public string? RepoRoot { get; init; }
        public string? IconEditorRoot { get; init; }
        public int? MinimumSupportedLVVersion { get; init; }
        public int? Major { get; init; }
        public int? Minor { get; init; }
        public int? Patch { get; init; }
        public int? Build { get; init; }
        public string? Commit { get; init; }
        public string[]? BitnessTargets { get; init; }
    }

    private sealed record BuildResult(string Bitness, int ExitCode, string StdOut, string StdErr);

    private sealed class CommandResult
    {
        public string Schema { get; init; } = "icon-editor/ppl-build@v1";
        public string IconEditorRoot { get; init; } = string.Empty;
        public BuildResult[] Runs { get; init; } = Array.Empty<BuildResult>();
        public bool Success { get; init; }
    }

    public static SimulationResult Run(string[] args)
    {
        string? requestPath = null;
        for (var i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            if (arg == "--request" && i + 1 < args.Length)
            {
                requestPath = args[++i];
            }
            else
            {
                Console.Error.WriteLine($"[x-cli] ppl-build: unknown argument '{arg}'.");
                return new SimulationResult(false, 1);
            }
        }

        if (string.IsNullOrWhiteSpace(requestPath))
        {
            Console.Error.WriteLine("[x-cli] ppl-build: --request PATH is required.");
            return new SimulationResult(false, 1);
        }

        requestPath = Path.GetFullPath(requestPath);
        if (!File.Exists(requestPath))
        {
            Console.Error.WriteLine($"[x-cli] ppl-build: request file not found at '{requestPath}'.");
            return new SimulationResult(false, 1);
        }

        BuildRequest? request;
        try
        {
            request = JsonSerializer.Deserialize<BuildRequest>(File.ReadAllText(requestPath), JsonOptions);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[x-cli] ppl-build: failed to parse request JSON: {ex.Message}");
            return new SimulationResult(false, 1);
        }

        if (request == null)
        {
            Console.Error.WriteLine("[x-cli] ppl-build: empty request payload.");
            return new SimulationResult(false, 1);
        }

        var repoRoot = ResolveRepoRoot(request.RepoRoot);
        if (string.IsNullOrWhiteSpace(repoRoot))
        {
            Console.Error.WriteLine("[x-cli] ppl-build: unable to resolve repo root.");
            return new SimulationResult(false, 1);
        }

        var iconEditorRoot = string.IsNullOrWhiteSpace(request.IconEditorRoot)
            ? Path.Combine(repoRoot, "vendor", "icon-editor")
            : ResolvePath(request.IconEditorRoot!, repoRoot);

        if (!Directory.Exists(iconEditorRoot))
        {
            Console.Error.WriteLine($"[x-cli] ppl-build: IconEditorRoot '{iconEditorRoot}' not found.");
            return new SimulationResult(false, 1);
        }

        var scriptPath = Path.Combine(iconEditorRoot, ".github", "actions", "build-lvlibp", "Build_lvlibp.ps1");
        if (!File.Exists(scriptPath))
        {
            Console.Error.WriteLine($"[x-cli] ppl-build: Build_lvlibp.ps1 not found at '{scriptPath}'.");
            return new SimulationResult(false, 1);
        }

        var bitnessTargets = request.BitnessTargets is { Length: > 0 }
            ? request.BitnessTargets!
            : new[] { "32", "64" };

        var runs = new List<BuildResult>();
        var pwsh = Environment.GetEnvironmentVariable("XCLI_PWSH") ?? "pwsh";
        foreach (var target in bitnessTargets)
        {
            var psi = new ProcessStartInfo(pwsh)
            {
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            psi.ArgumentList.Add("-NoLogo");
            psi.ArgumentList.Add("-NoProfile");
            psi.ArgumentList.Add("-File");
            psi.ArgumentList.Add(scriptPath);

            if (request.MinimumSupportedLVVersion.HasValue)
            {
                psi.ArgumentList.Add("-MinimumSupportedLVVersion");
                psi.ArgumentList.Add(request.MinimumSupportedLVVersion.Value.ToString());
            }
            psi.ArgumentList.Add("-SupportedBitness");
            psi.ArgumentList.Add(target);
            psi.ArgumentList.Add("-IconEditorRoot");
            psi.ArgumentList.Add(iconEditorRoot);
            if (request.Major.HasValue) { psi.ArgumentList.Add("-Major"); psi.ArgumentList.Add(request.Major.Value.ToString()); }
            if (request.Minor.HasValue) { psi.ArgumentList.Add("-Minor"); psi.ArgumentList.Add(request.Minor.Value.ToString()); }
            if (request.Patch.HasValue) { psi.ArgumentList.Add("-Patch"); psi.ArgumentList.Add(request.Patch.Value.ToString()); }
            if (request.Build.HasValue) { psi.ArgumentList.Add("-Build"); psi.ArgumentList.Add(request.Build.Value.ToString()); }
            if (!string.IsNullOrWhiteSpace(request.Commit))
            {
                psi.ArgumentList.Add("-Commit");
                psi.ArgumentList.Add(request.Commit!);
            }

            using var process = Process.Start(psi);
            if (process == null)
            {
                Console.Error.WriteLine($"[x-cli] ppl-build: failed to launch PowerShell for bitness {target}.");
                return new SimulationResult(false, 1);
            }

            var stdOut = process.StandardOutput.ReadToEnd();
            var stdErr = process.StandardError.ReadToEnd();
            process.WaitForExit();

            if (!string.IsNullOrEmpty(stdOut)) Console.Write(stdOut);
            if (!string.IsNullOrEmpty(stdErr)) Console.Error.Write(stdErr);

            runs.Add(new BuildResult(target, process.ExitCode, stdOut, stdErr));
        }

        var success = runs.TrueForAll(r => r.ExitCode == 0);
        var response = new CommandResult
        {
            IconEditorRoot = iconEditorRoot,
            Runs = runs.ToArray(),
            Success = success
        };
        Console.WriteLine(JsonSerializer.Serialize(response, new JsonSerializerOptions { WriteIndented = true }));
        return new SimulationResult(success, success ? 0 : 1);
    }

    private static string? ResolveRepoRoot(string? candidate)
    {
        var root = candidate;
        if (string.IsNullOrWhiteSpace(root))
        {
            root = Environment.GetEnvironmentVariable("XCLI_REPO_ROOT");
        }
        if (string.IsNullOrWhiteSpace(root))
        {
            return null;
        }
        try
        {
            return Path.GetFullPath(root);
        }
        catch
        {
            return null;
        }
    }

    private static string ResolvePath(string path, string repoRoot)
    {
        return Path.GetFullPath(Path.IsPathRooted(path) ? path : Path.Combine(repoRoot, path));
    }
}
