// ModuleIndex: CLI entry point coordinating parsing, logging, and simulation.
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using XCli.Cli;
using XCli.Logging;
using XCli.Simulation;
using XCli.Security;
using XCli.Util;
using XCli.Echo;
using XCli.Reverse;
using XCli.Upper;
using XCli.Telemetry;
using XCli.Foo;

namespace XCli;

public static class Program
{
    private const int DefaultMaxDurationMs = 2000;

    public static async Task<int> Main(string[] args)
    {
        IsolationGuard.Enforce();
        var sw = Stopwatch.StartNew();
        var parsed = Cli.Cli.Parse(args);
        var logger = new InvocationLogger();
        const string HostTag = "x-cli";
        if (parsed.ShowHelp)
        {
            Console.WriteLine(Cli.Cli.HelpText);
            logger.Log("help", parsed.PayloadArgs, string.Empty, new SimulationResult(true, 0), sw.ElapsedMilliseconds);
            return 0;
        }
        if (parsed.ShowVersion)
        {
            var version = Cli.VersionInfo.Version;
            Console.WriteLine(version);
            logger.Log("version", parsed.PayloadArgs, string.Empty, new SimulationResult(true, 0), sw.ElapsedMilliseconds);
            return 0;
        }
        if (parsed.Subcommand == null)
        {
            Console.Error.WriteLine($"{HostTag}: missing subcommand");
            logger.Log("missing", parsed.PayloadArgs, "missing subcommand", new SimulationResult(false, 1), sw.ElapsedMilliseconds);
            return 1;
        }
        if (!Cli.Cli.Subcommands.Contains(parsed.Subcommand))
        {
            Console.Error.WriteLine($"[{HostTag}] error: unknown subcommand '{parsed.Subcommand}'. See --help.");
            logger.Log(
                "unknown",
                parsed.PayloadArgs,
                $"error: unknown subcommand '{parsed.Subcommand}'. See --help.",
                new SimulationResult(false, 1),
                sw.ElapsedMilliseconds);
            return 1;
        }
        var subcommand = parsed.Subcommand;
        if (subcommand == "echo")
        {
            var text = string.Join(" ", parsed.PayloadArgs);
            var echoed = EchoCommand.Execute(text);
            Console.WriteLine(echoed);
            var echoResult = new SimulationResult(true, 0);
            logger.Log(subcommand, parsed.PayloadArgs, string.Empty, echoResult, sw.ElapsedMilliseconds);
            return 0;
        }
        if (subcommand == "reverse")
        {
            var text = string.Join(" ", parsed.PayloadArgs);
            var reversed = ReverseCommand.Execute(text);
            Console.WriteLine(reversed);
            var reverseResult = new SimulationResult(true, 0);
            logger.Log(subcommand, parsed.PayloadArgs, string.Empty, reverseResult, sw.ElapsedMilliseconds);
            return 0;
        }
        if (subcommand == "upper")
        {
            var text = string.Join(" ", parsed.PayloadArgs);
            var uppered = UpperCommand.Execute(text);
            Console.WriteLine(uppered);
            var upperResult = new SimulationResult(true, 0);
            logger.Log(subcommand, parsed.PayloadArgs, string.Empty, upperResult, sw.ElapsedMilliseconds);
            return 0;
        }
        if (subcommand == "foo")
        {
            var text = string.Join(" ", parsed.PayloadArgs);
            var outText = FooCommand.Execute(text);
            Console.WriteLine(outText);
            var fooResult = new SimulationResult(true, 0);
            logger.Log(subcommand, parsed.PayloadArgs, string.Empty, fooResult, sw.ElapsedMilliseconds);
            return 0;
        }
        if (subcommand == "log-replay")
        {
            var code = await Replay.LogReplayCommand.Run(parsed.PayloadArgs);
            return code;
        }
        if (subcommand == "log-diff")
        {
            var code = Replay.LogDiffCommand.Run(parsed.PayloadArgs);
            return code;
        }
        if (subcommand == "telemetry")
        {
            var code = TelemetryCommand.Run(parsed.PayloadArgs);
            return code;
        }
        if (subcommand == "labview-devmode-enable" || subcommand == "labview-devmode-disable")
        {
            var devmodeResult = Labview.LabviewDevmodeCommand.Run(subcommand, parsed.PayloadArgs);
            logger.Log(subcommand, parsed.PayloadArgs, string.Empty, devmodeResult, sw.ElapsedMilliseconds);
            return devmodeResult.ExitCode;
        }
        var planResult = SimulationPlan.ForCommand(subcommand);
        var simulator = new Simulator();
        var result = await simulator.Execute(subcommand, planResult);
        var logMessage = planResult.Plan.Fail ? planResult.Plan.Message : string.Empty;
        logger.Log(subcommand, parsed.PayloadArgs, logMessage, result, sw.ElapsedMilliseconds);
        var threshold = Env.GetInt("XCLI_MAX_DURATION_MS", DefaultMaxDurationMs);
        if (sw.ElapsedMilliseconds > threshold)
        {
            Console.Error.WriteLine($"[{HostTag}] warning: duration {sw.ElapsedMilliseconds}ms exceeded {threshold}ms");
        }
        return result.ExitCode;
    }
}
