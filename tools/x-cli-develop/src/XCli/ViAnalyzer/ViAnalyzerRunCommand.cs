using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using XCli.Simulation;

namespace XCli.ViAnalyzer;

public static class ViAnalyzerRunCommand
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };

    private sealed class RunRequest
    {
        public string? RepoRoot { get; init; }
        public string? ConfigPath { get; init; }
        public string? OutputRoot { get; init; }
        public string? Label { get; init; }
        public string? ReportSaveType { get; init; }
        public int? LabVIEWVersion { get; init; }
        public int? Bitness { get; init; }
        public string? LabVIEWCLIPath { get; init; }
        public bool CaptureResultsFile { get; init; }
        public string? ReportPath { get; init; }
        public string? ResultsPath { get; init; }
        public int? TimeoutSeconds { get; init; }
        public string[]? AdditionalArguments { get; init; }
        public string? ConfigPassword { get; init; }
        public string? ReportSort { get; init; }
        public string[]? ReportInclude { get; init; }
    }

    private sealed class RunResponse
    {
        public string Schema { get; init; } = "icon-editor/vi-analyzer-run@v1";
        public string Label { get; init; } = string.Empty;
        public string OutputRoot { get; init; } = string.Empty;
        public string RunDirectory { get; init; } = string.Empty;
        public string ResultPath { get; init; } = string.Empty;
        public string? ReportPath { get; init; }
        public string? ResultsPath { get; init; }
        public JsonElement? AnalyzerSummary { get; init; }
        public int ScriptExitCode { get; init; }
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
                Console.Error.WriteLine($"[x-cli] vi-analyzer-run: unknown argument '{arg}'.");
                return new SimulationResult(false, 1);
            }
        }

        if (string.IsNullOrWhiteSpace(requestPath))
        {
            Console.Error.WriteLine("[x-cli] vi-analyzer-run: --request PATH is required.");
            return new SimulationResult(false, 1);
        }

        requestPath = Path.GetFullPath(requestPath);
        if (!File.Exists(requestPath))
        {
            Console.Error.WriteLine($"[x-cli] vi-analyzer-run: request file not found at '{requestPath}'.");
            return new SimulationResult(false, 1);
        }

        RunRequest? request;
        try
        {
            request = JsonSerializer.Deserialize<RunRequest>(File.ReadAllText(requestPath), JsonOptions);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[x-cli] vi-analyzer-run: failed to parse request JSON: {ex.Message}");
            return new SimulationResult(false, 1);
        }

        if (request is null)
        {
            Console.Error.WriteLine("[x-cli] vi-analyzer-run: empty request payload.");
            return new SimulationResult(false, 1);
        }

        var repoRoot = ResolveRepoRoot(request.RepoRoot);
        if (string.IsNullOrWhiteSpace(repoRoot))
        {
            Console.Error.WriteLine("[x-cli] vi-analyzer-run: unable to resolve repo root. Provide repoRoot in the request or set XCLI_REPO_ROOT.");
            return new SimulationResult(false, 1);
        }

        var scriptPath = Path.Combine(repoRoot, "src", "tools", "icon-editor", "Invoke-VIAnalyzer.ps1");
        if (!File.Exists(scriptPath))
        {
            Console.Error.WriteLine($"[x-cli] vi-analyzer-run: Invoke-VIAnalyzer.ps1 not found at '{scriptPath}'.");
            return new SimulationResult(false, 1);
        }

        if (string.IsNullOrWhiteSpace(request.ConfigPath))
        {
            Console.Error.WriteLine("[x-cli] vi-analyzer-run: request missing 'configPath'.");
            return new SimulationResult(false, 1);
        }

        var configPath = ResolvePath(request.ConfigPath!, repoRoot);
        if (!File.Exists(configPath))
        {
            Console.Error.WriteLine($"[x-cli] vi-analyzer-run: configPath not found at '{configPath}'.");
            return new SimulationResult(false, 1);
        }

        var outputRoot = string.IsNullOrWhiteSpace(request.OutputRoot)
            ? Path.Combine(repoRoot, "tests", "results", "_agent", "vi-analyzer")
            : ResolvePath(request.OutputRoot!, repoRoot, ensureDirectory: true);

        var label = !string.IsNullOrWhiteSpace(request.Label)
            ? request.Label!
            : $"vi-analyzer-{DateTime.UtcNow:yyyyMMddHHmmss}";

        var runDirectory = Path.Combine(outputRoot, label);
        var pwshPath = Environment.GetEnvironmentVariable("XCLI_PWSH") ?? "pwsh";
        var psi = new ProcessStartInfo(pwshPath)
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
        psi.ArgumentList.Add("-ConfigPath");
        psi.ArgumentList.Add(configPath);
        psi.ArgumentList.Add("-OutputRoot");
        psi.ArgumentList.Add(outputRoot);
        psi.ArgumentList.Add("-Label");
        psi.ArgumentList.Add(label);

        if (!string.IsNullOrWhiteSpace(request.ReportSaveType))
        {
            psi.ArgumentList.Add("-ReportSaveType");
            psi.ArgumentList.Add(request.ReportSaveType!);
        }
        if (request.LabVIEWVersion.HasValue)
        {
            psi.ArgumentList.Add("-LabVIEWVersion");
            psi.ArgumentList.Add(request.LabVIEWVersion.Value.ToString());
        }
        if (request.Bitness.HasValue)
        {
            psi.ArgumentList.Add("-Bitness");
            psi.ArgumentList.Add(request.Bitness.Value.ToString());
        }
        if (!string.IsNullOrWhiteSpace(request.LabVIEWCLIPath))
        {
            psi.ArgumentList.Add("-LabVIEWCLIPath");
            psi.ArgumentList.Add(ResolvePath(request.LabVIEWCLIPath!, repoRoot));
        }
        if (request.CaptureResultsFile)
        {
            psi.ArgumentList.Add("-CaptureResultsFile");
        }
        if (!string.IsNullOrWhiteSpace(request.ReportPath))
        {
            psi.ArgumentList.Add("-ReportPath");
            psi.ArgumentList.Add(ResolvePath(request.ReportPath!, repoRoot));
        }
        if (!string.IsNullOrWhiteSpace(request.ResultsPath))
        {
            psi.ArgumentList.Add("-ResultsPath");
            psi.ArgumentList.Add(ResolvePath(request.ResultsPath!, repoRoot));
        }
        if (request.TimeoutSeconds.HasValue)
        {
            psi.ArgumentList.Add("-TimeoutSeconds");
            psi.ArgumentList.Add(request.TimeoutSeconds.Value.ToString());
        }
        if (!string.IsNullOrWhiteSpace(request.ConfigPassword))
        {
            psi.ArgumentList.Add("-ConfigPassword");
            psi.ArgumentList.Add(request.ConfigPassword!);
        }
        if (!string.IsNullOrWhiteSpace(request.ReportSort))
        {
            psi.ArgumentList.Add("-ReportSort");
            psi.ArgumentList.Add(request.ReportSort!);
        }
        if (request.ReportInclude is { Length: > 0 })
        {
            var includeValues = new List<string>();
            foreach (var include in request.ReportInclude)
            {
                if (!string.IsNullOrWhiteSpace(include))
                {
                    includeValues.Add(include);
                }
            }
            if (includeValues.Count > 0)
            {
                psi.ArgumentList.Add("-ReportInclude");
                foreach (var value in includeValues)
                {
                    psi.ArgumentList.Add(value);
                }
            }
        }
        if (request.AdditionalArguments is { Length: > 0 })
        {
            foreach (var arg in request.AdditionalArguments)
            {
                if (!string.IsNullOrWhiteSpace(arg))
                {
                    psi.ArgumentList.Add(arg);
                }
            }
        }

        using var process = Process.Start(psi);
        if (process == null)
        {
            Console.Error.WriteLine("[x-cli] vi-analyzer-run: failed to launch PowerShell process.");
            return new SimulationResult(false, 1);
        }

        var stdOut = process.StandardOutput.ReadToEnd();
        var stdErr = process.StandardError.ReadToEnd();
        process.WaitForExit();

        if (!string.IsNullOrEmpty(stdOut))
        {
            Console.Write(stdOut);
        }
        if (!string.IsNullOrEmpty(stdErr))
        {
            Console.Error.Write(stdErr);
        }

        var exitCode = process.ExitCode;
        var resultPath = Path.Combine(runDirectory, "vi-analyzer.json");
        JsonElement? summary = null;
        string? reportPath = null;
        string? resultsPath = null;

        if (File.Exists(resultPath))
        {
            try
            {
                using var doc = JsonDocument.Parse(File.ReadAllText(resultPath));
                summary = doc.RootElement.Clone();
                if (summary.Value.TryGetProperty("reportPath", out var reportProp) && reportProp.ValueKind == JsonValueKind.String)
                {
                    reportPath = reportProp.GetString();
                }
                if (summary.Value.TryGetProperty("resultsPath", out var resultsProp) && resultsProp.ValueKind == JsonValueKind.String)
                {
                    resultsPath = resultsProp.GetString();
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[x-cli] vi-analyzer-run: warning - failed to parse result JSON: {ex.Message}");
            }
        }
        else
        {
            Console.Error.WriteLine($"[x-cli] vi-analyzer-run: result JSON not found at '{resultPath}'.");
        }

        var response = new RunResponse
        {
            Label = label,
            OutputRoot = outputRoot,
            RunDirectory = runDirectory,
            ResultPath = resultPath,
            ReportPath = reportPath,
            ResultsPath = resultsPath,
            AnalyzerSummary = summary,
            ScriptExitCode = exitCode
        };
        var responseJson = JsonSerializer.Serialize(response, new JsonSerializerOptions { WriteIndented = true });
        Console.WriteLine(responseJson);

        var success = exitCode == 0;
        return new SimulationResult(success, success ? 0 : exitCode);
    }

    private static string? ResolveRepoRoot(string? candidate)
    {
        var repoRoot = candidate;
        if (string.IsNullOrWhiteSpace(repoRoot))
        {
            repoRoot = Environment.GetEnvironmentVariable("XCLI_REPO_ROOT");
        }
        if (string.IsNullOrWhiteSpace(repoRoot))
        {
            return null;
        }
        try
        {
            return Path.GetFullPath(repoRoot);
        }
        catch
        {
            return null;
        }
    }

    private static string ResolvePath(string path, string repoRoot, bool ensureDirectory = false)
    {
        var candidate = Path.IsPathRooted(path) ? path : Path.Combine(repoRoot, path);
        var fullPath = Path.GetFullPath(candidate);
        if (ensureDirectory && !Directory.Exists(fullPath))
        {
            Directory.CreateDirectory(fullPath);
        }
        return fullPath;
    }
}
