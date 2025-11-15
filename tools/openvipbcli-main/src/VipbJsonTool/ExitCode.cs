namespace VipbJsonTool;

/// <summary>
/// Centralised process exit codes (SRS §3.1 UI‑2).
/// </summary>
internal static class ExitCode
{
    public const int Success      = 0;
    public const int Usage        = 1;
    public const int UnknownMode  = 2;
    public const int Fatal        = 99;
}