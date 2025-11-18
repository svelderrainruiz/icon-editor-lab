using System;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using XCli.Simulation;

namespace XCli.Vipm;

public static class VipmBuildVipCommand
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };
    private sealed class BuildRequest
    {
        public string? RepoRoot { get; init; }
        public string? Workspace { get; init; }
        public string? ReleaseNotesPath { get; init; }
        public bool SkipReleaseNotes { get; init; }
        public bool SkipVipbUpdate { get; init; }
        public bool SkipBuild { get; init; }
        public bool CloseLabVIEW { get; init; }
        public bool DownloadArtifacts { get; init; }
        public string? BuildToolchain { get; init; } = "g-cli";
        public string? BuildProvider { get; init; }
        public string? JobName { get; init; }
        public string? RunId { get; init; }
        public string? LogPath { get; init; }
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
                Console.Error.WriteLine($"[x-cli] vipm-build-vip: unknown argument '{arg}'.");
                return new SimulationResult(false, 1);
            }
        }

        if (string.IsNullOrWhiteSpace(requestPath))
        {
            Console.Error.WriteLine("[x-cli] vipm-build-vip: --request PATH is required.");
            return new SimulationResult(false, 1);
        }

        requestPath = Path.GetFullPath(requestPath);
        if (!File.Exists(requestPath))
        {
            Console.Error.WriteLine($"[x-cli] vipm-build-vip: request not found at '{requestPath}'.");
            return new SimulationResult(false, 1);
        }

        BuildRequest? request;
        try
        {
            request = JsonSerializer.Deserialize<BuildRequest>(File.ReadAllText(requestPath), JsonOptions);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[x-cli] vipm-build-vip: failed to parse request JSON: {ex.Message}");
            return new SimulationResult(false, 1);
        }

        if (request == null)
        {
            Console.Error.WriteLine("[x-cli] vipm-build-vip: empty request payload.");
            return new SimulationResult(false, 1);
        }

        var repoRoot = ResolveRepoRoot(request.RepoRoot);
        if (string.IsNullOrWhiteSpace(repoRoot))
        {
            Console.Error.WriteLine("[x-cli] vipm-build-vip: unable to resolve repo root.");
            return new SimulationResult(false, 1);
        }

        var scriptPath = Path.Combine(repoRoot, "src", "tools", "icon-editor", "Invoke-VipmPackageBuildJob.ps1");
        if (!File.Exists(scriptPath))
        {
            Console.Error.WriteLine($"[x-cli] vipm-build-vip: build job script not found at '{scriptPath}'.");
            return new SimulationResult(false, 1);
        }

        var workspace = ResolvePathOrDefault(request.Workspace, repoRoot);
        var releaseNotes = resolveRelative(request.ReleaseNotesPath ?? "Tooling/deployment/release_notes.md", workspace);

        var guardScript = Path.Combine(repoRoot, "src", "tools", "icon-editor", "Test-VipbCustomActions.ps1");
        var vipbPath = Path.Combine(repoRoot, ".github", "actions", "build-vi-package", "NI_Icon_editor.vipb");
        var pwsh = Environment.GetEnvironmentVariable("XCLI_PWSH") ?? "pwsh";

        if (File.Exists(guardScript))
        {
            if (!File.Exists(vipbPath))
            {
                Console.Error.WriteLine($"[x-cli] vipm-build-vip: VIPB not found at '{vipbPath}'.");
                return new SimulationResult(false, 1);
            }

            var guardPsi = new ProcessStartInfo(pwsh)
            {
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true,
                WorkingDirectory = workspace
            };
            guardPsi.ArgumentList.Add("-NoLogo");
            guardPsi.ArgumentList.Add("-NoProfile");
            guardPsi.ArgumentList.Add("-File");
            guardPsi.ArgumentList.Add(guardScript);
            guardPsi.ArgumentList.Add("-VipbPath");
            guardPsi.ArgumentList.Add(vipbPath);
            guardPsi.ArgumentList.Add("-Workspace");
            guardPsi.ArgumentList.Add(workspace);

            using var guardProcess = Process.Start(guardPsi);
            var guardStdOut = guardProcess?.StandardOutput.ReadToEnd();
            var guardStdErr = guardProcess?.StandardError.ReadToEnd();
            guardProcess?.WaitForExit();
            if (!string.IsNullOrEmpty(guardStdOut)) Console.Write(guardStdOut);
            if (!string.IsNullOrEmpty(guardStdErr)) Console.Error.Write(guardStdErr);
            if (guardProcess == null || guardProcess.ExitCode != 0)
            {
                Console.Error.WriteLine("[x-cli] vipm-build-vip: custom action guard failed.");
                return new SimulationResult(false, guardProcess?.ExitCode ?? 1);
            }
        }

        var psi = new ProcessStartInfo(pwsh)
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            WorkingDirectory = workspace
        };

        psi.ArgumentList.Add("-NoLogo");
        psi.ArgumentList.Add("-NoProfile");
        psi.ArgumentList.Add("-File");
        psi.ArgumentList.Add(scriptPath);
        psi.ArgumentList.Add("-Workspace");
        psi.ArgumentList.Add(workspace);
        psi.ArgumentList.Add("-ReleaseNotesPath");
        psi.ArgumentList.Add(releaseNotes);

        if (!string.IsNullOrWhiteSpace(request.JobName))
        {
            psi.ArgumentList.Add("-JobName");
            psi.ArgumentList.Add(request.JobName!);
        }
        if (!string.IsNullOrWhiteSpace(request.RunId))
        {
            psi.ArgumentList.Add("-RunId");
            psi.ArgumentList.Add(request.RunId!);
        }
        if (!string.IsNullOrWhiteSpace(request.LogPath))
        {
            psi.ArgumentList.Add("-LogPath");
            psi.ArgumentList.Add(resolveRelative(request.LogPath!, workspace));
        }
        if (!string.IsNullOrWhiteSpace(request.RunId))
        {
            psi.ArgumentList.Add("-RunId");
            psi.ArgumentList.Add(request.RunId!);
        }

        if (request.SkipReleaseNotes) psi.ArgumentList.Add("-SkipReleaseNotes");
        if (request.SkipVipbUpdate) psi.ArgumentList.Add("-SkipVipbUpdate");
        if (request.SkipBuild) psi.ArgumentList.Add("-SkipBuild");
        if (request.CloseLabVIEW) psi.ArgumentList.Add("-CloseLabVIEW");
        if (request.DownloadArtifacts) psi.ArgumentList.Add("-DownloadArtifacts");

        if (!string.IsNullOrWhiteSpace(request.BuildToolchain))
        {
            psi.ArgumentList.Add("-BuildToolchain");
            psi.ArgumentList.Add(request.BuildToolchain!);
        }
        if (!string.IsNullOrWhiteSpace(request.BuildProvider))
        {
            psi.ArgumentList.Add("-BuildProvider");
            psi.ArgumentList.Add(request.BuildProvider!);
        }

        using var process = Process.Start(psi);
        if (process == null)
        {
            Console.Error.WriteLine("[x-cli] vipm-build-vip: failed to start PowerShell process.");
            return new SimulationResult(false, 1);
        }

        var stdOut = process.StandardOutput.ReadToEnd();
        var stdErr = process.StandardError.ReadToEnd();
        process.WaitForExit();

        if (!string.IsNullOrEmpty(stdOut)) Console.Write(stdOut);
        if (!string.IsNullOrEmpty(stdErr)) Console.Error.Write(stdErr);

        var exitCode = process.ExitCode;
        return new SimulationResult(exitCode == 0, exitCode == 0 ? 0 : exitCode);
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

    private static string ResolvePathOrDefault(string? path, string workspace)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return workspace;
        }
        return Path.GetFullPath(Path.IsPathRooted(path) ? path : Path.Combine(workspace, path));
    }

    private static string resolveRelative(string path, string workspace)
    {
        if (Path.IsPathRooted(path))
        {
            return Path.GetFullPath(path);
        }
        return Path.GetFullPath(Path.Combine(workspace, path));
    }
}
