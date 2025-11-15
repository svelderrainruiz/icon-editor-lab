// Adapted from upstream v1.3.3
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;

namespace VipbJsonTool
{
    internal static class GitHelper
    {
        /// <summary>
        /// Commit <paramref name="paths"/> to <paramref name="branchName"/> and, optionally,
        /// open a PR back to the default branch.
        /// </summary>
        /// <exception cref="InvalidOperationException">Thrown on any non‑zero CLI exit‑code.</exception>
        public static void CommitAndPush(IEnumerable<string> paths,
                                         string branchName,
                                         bool autoPr)
        {
            if (string.IsNullOrWhiteSpace(branchName))
                throw new ArgumentException("branchName must be non‑empty.", nameof(branchName));

            // 1. Ensure clean git working dir
            Run("git", "status --porcelain");

            // 2. Checkout new branch (or reuse existing)
            Run("git", $"checkout -B {branchName}");

            // 3. Stage paths
            foreach (var p in paths)
            {
                if (!File.Exists(p) && !Directory.Exists(p))
                    Console.Error.WriteLine($"[warning] Path not found, skipping: {p}");
                else
                    Run("git", $"add \"{p}\"");
            }

            // 4. Commit (allow amend if identical tree)
            var msg = $"VipbJsonTool auto‑update {DateTime.UtcNow:yyyy‑MM‑dd HH:mm:ss}Z";
            var commitResult = Run("git", $"commit -m \"{msg}\"", ignoreError: true);
            if (commitResult.ExitCode != 0 && !commitResult.StdErr.Contains("nothing to commit"))
                Throw($"git commit failed\n{commitResult.StdErr}");

            // 5. Push (force-with-lease in case branch exists remotely)
            Run("git", $"push --force-with-lease -u origin {branchName}");

            if (autoPr)
                CreatePullRequest(branchName);
        }

        #region internals

        private static void CreatePullRequest(string branchName)
        {
            var token = Environment.GetEnvironmentVariable("GITHUB_TOKEN");
            var repo  = Environment.GetEnvironmentVariable("GITHUB_REPOSITORY"); // owner/repo
            if (string.IsNullOrWhiteSpace(token) || string.IsNullOrWhiteSpace(repo))
            {
                Console.Error.WriteLine("[warning] GITHUB_TOKEN or GITHUB_REPOSITORY not set; skipping PR creation.");
                return;
            }

            var apiUrl = $"https://api.github.com/repos/{repo}/pulls";
            var json   =
                $"{{\"title\":\"VipbJsonTool automated update\",\"head\":\"{branchName}\",\"base\":\"main\"}}";

            // Use curl because it's guaranteed in the Actions runner (§ 2.4)
            var headers = $"-H \"Authorization: Bearer {token}\" " +
                          "-H \"Accept: application/vnd.github+json\" " +
                          "-H \"User-Agent: VipbJsonTool\"";
            Run("curl",
                $"{headers} -X POST {apiUrl} -d \"{json.Replace("\"", "\\\"")}\"");
        }

        private static (int ExitCode, string StdOut, string StdErr)
            Run(string fileName, string arguments, bool ignoreError = false)
        {
            var psi = new ProcessStartInfo
            {
                FileName               = fileName,
                Arguments              = arguments,
                RedirectStandardOutput = true,
                RedirectStandardError  = true,
                UseShellExecute        = false,
            };

            var proc = Process.Start(psi)!;
            var stdout = new StringBuilder();
            var stderr = new StringBuilder();
            proc.OutputDataReceived += (_, e) => stdout.AppendLine(e.Data);
            proc.ErrorDataReceived  += (_, e) => stderr.AppendLine(e.Data);
            proc.BeginOutputReadLine();
            proc.BeginErrorReadLine();
            proc.WaitForExit();

            if (!ignoreError && proc.ExitCode != 0)
                Throw($"Command '{fileName} {arguments}' failed with exit‑code {proc.ExitCode}\n{stderr}");
            return (proc.ExitCode, stdout.ToString(), stderr.ToString());
        }

        private static void Throw(string msg)
        {
            Console.Error.WriteLine(msg);
            throw new InvalidOperationException(msg);
        }

        #endregion
    }
}