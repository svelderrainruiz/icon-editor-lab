using System;
using System.Diagnostics;
using System.IO;
using VipbJsonTool;
using Xunit;

namespace VipbJsonTool.Tests;

[Trait("Category", "Perf")]
public class PerfTests
{
    // generate ~200 KB VIPB on the fly
    private static string CreateLargeVipb()
    {
        var sb = new System.Text.StringBuilder();
        sb.Append("<?xml version=\"1.0\"?><Package>");
        for (int i = 0; i < 5000; i++)
            sb.Append("<Item idx=\"" + i + "\">value</Item>");
        sb.Append("</Package>");
        var path = Path.Combine(Path.GetTempPath(), Guid.NewGuid() + ".vipb");
        File.WriteAllText(path, sb.ToString());
        return path;
    }

    [Fact]
    public void Vipb2Json_Finishes_Under_500ms_And_128MB()
    {
        var vipb = CreateLargeVipb();
        var json = Path.ChangeExtension(vipb, ".json");

        var sw = Stopwatch.StartNew();
        VipbToJsonConverter.Convert(vipb, json);
        sw.Stop();

        var mem = GC.GetTotalMemory(forceFullCollection: true) / (1024.0 * 1024.0); // MB

        Assert.True(sw.ElapsedMilliseconds <= 500, $"Elapsed {sw.ElapsedMilliseconds} ms");
        Assert.True(mem <= 128.0, $"Memory {mem:F1} MB");
    }
}