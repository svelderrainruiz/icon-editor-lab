using System.IO;
using Newtonsoft.Json.Linq;
using VipbJsonTool;
using Xunit;

namespace VipbJsonTool.Tests;

public class YamlPatchApplierTests
{
    [Fact]
    public void Applies_DotPath_With_ArrayIndices()
    {
        var root = JToken.Parse(@"{ 'items': [ { 'val': 1 } ] }");

        var yaml = "items[0].val: 42";
        var file = Path.GetTempFileName();
        File.WriteAllText(file, yaml);

        YamlPatchApplier.ApplyYamlPatch(root, file);

        Assert.Equal(42, (int)root["items"]![0]!["val"]!);
    }

    [Fact]
    public void Ignores_Wrapper_And_Schema_Version()
    {
        var root = JToken.Parse(@"{ 'a': 1 }");

        var yaml =
@"schema_version: 1
patch:
  a: 2";
        var file = Path.GetTempFileName();
        File.WriteAllText(file, yaml);

        YamlPatchApplier.ApplyYamlPatch(root, file);

        Assert.Equal(2, (int)root["a"]!);
    }
}