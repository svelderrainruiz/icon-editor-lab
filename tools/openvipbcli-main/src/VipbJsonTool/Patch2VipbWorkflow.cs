// Adapted from upstream v1.3.3
using System.IO;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace VipbJsonTool;

/// <summary>
/// FR‑3 orchestrator: apply YAML patch(es), overwrite JSON, convert to .vipb.
/// </summary>
internal static class Patch2VipbWorkflow
{
    public static void Run(string jsonPath, string patchPath, string alwaysPatchPath, string vipbOutPath)
    {
        if (!File.Exists(jsonPath))
            throw new FileNotFoundException("Input JSON file not found.", jsonPath);

        var root = JToken.Parse(File.ReadAllText(jsonPath));

        // Apply first the transient patch, then the always‑on patch.
        YamlPatchApplier.ApplyYamlPatch(root, patchPath);
        YamlPatchApplier.ApplyYamlPatch(root, alwaysPatchPath);

        // Overwrite source JSON deterministically.
        File.WriteAllText(jsonPath, root.ToString(Newtonsoft.Json.Formatting.Indented));

        // Convert to .vipb
        JsonToVipbConverter.Convert(jsonPath, vipbOutPath);
    }
}