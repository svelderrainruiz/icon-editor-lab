using System;

namespace VipbJsonTool;

/// <summary>
/// Centralised stderr/stdout writer with token redaction (Security).
/// </summary>
internal static class Logger
{
    private static string? _token;   // cached replacement pattern

    public static void Initialise(string? githubToken)
        => _token = githubToken;

    public static void Info(string msg)
        => Console.WriteLine(Redact(msg));

    public static void Error(string msg)
        => Console.Error.WriteLine(Redact(msg));

    public static string Redact(string input)
        => string.IsNullOrEmpty(_token)
            ? input
            : input.Replace(_token, "***REDACTED***", StringComparison.Ordinal);
}