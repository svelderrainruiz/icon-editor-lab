// Adapted from upstream v1.3.3
using System;
using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json.Linq;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace VipbJsonTool;

/// <summary>
/// Applies a YAML patch (dot‑path → value) onto a mutable <see cref="JToken"/>.
/// SRS: IO‑2 (dot‑path, [n] indices, ignore schema_version + wrapper).
/// </summary>
internal static class YamlPatchApplier
{
    public static void ApplyYamlPatch(JToken root, string yamlPath)
    {
        if (string.IsNullOrWhiteSpace(yamlPath) || !File.Exists(yamlPath))
            return;                                       // nothing to do

        var yaml = File.ReadAllText(yamlPath);
        if (string.IsNullOrWhiteSpace(yaml)) return;

        var deser = new DeserializerBuilder()
            .WithNamingConvention(CamelCaseNamingConvention.Instance)
            .Build();

        var obj = deser.Deserialize<object>(yaml);

        if (obj is not Dictionary<object, object> top) return;

        // Unwrap "patch:" wrapper if present
        if (top.TryGetValue("patch", out var patchObj) &&
            patchObj is Dictionary<object, object> inner)
        {
            top = inner;
        }

        foreach (var kv in top)
        {
            if (kv.Key is not string path || path.Equals("schema_version", StringComparison.OrdinalIgnoreCase))
                continue;

            ApplyPath(root, path, kv.Value);
        }
    }

    #region path navigation helpers
    private readonly struct Segment
    {
        internal readonly string Property;
        internal readonly int    Index;
        internal readonly bool   IsIndex;
        internal Segment(string p) { Property = p; Index = -1; IsIndex = false; }
        internal Segment(int i)   { Property = string.Empty; Index = i; IsIndex = true; }
    }

    private static List<Segment> ParsePath(string path)
    {
        var list = new List<Segment>();
        int i = 0;
        while (i < path.Length)
        {
            if (path[i] == '.') { i++; continue; }

            if (path[i] == '[')                 // array index
            {
                int end = path.IndexOf(']', i);
                int idx = int.Parse(path[(i + 1)..end]);
                list.Add(new Segment(idx));
                i = end + 1;
            }
            else                                // property name
            {
                int start = i;
                while (i < path.Length && path[i] != '.' && path[i] != '[') i++;
                list.Add(new Segment(path[start..i]));
            }
        }
        return list;
    }

    private static void ApplyPath(JToken root, string path, object value)
    {
        var segments = ParsePath(path);
        JToken current = root;

        for (int s = 0; s < segments.Count; s++)
        {
            var seg = segments[s];
            bool last = s == segments.Count - 1;

            if (seg.IsIndex)                    // ---------- array ----------
            {
                var arr = current as JArray ?? ReplaceWith(current, new JArray());
                EnsureSize(arr, seg.Index);

                if (last)
                    arr[seg.Index] = JToken.FromObject(value);
                else
                {
                    if (arr[seg.Index] == null || arr[seg.Index]!.Type == JTokenType.Null)
                        arr[seg.Index] = new JObject();
                    current = arr[seg.Index]!;
                }
            }
            else                                // ---------- object ----------
            {
                var obj = current as JObject ?? ReplaceWith(current, new JObject());

                if (last)
                    obj[seg.Property] = JToken.FromObject(value);
                else
                {
                    if (obj[seg.Property] == null || obj[seg.Property]!.Type == JTokenType.Null)
                        obj[seg.Property] = new JObject();
                    current = obj[seg.Property]!;
                }
            }
        }
    }

    private static void EnsureSize(JArray arr, int index)
    {
        while (arr.Count <= index) arr.Add(JValue.CreateNull());
    }

    private static T ReplaceWith<T>(JToken oldToken, T replacement) where T : JToken
    {
        if (oldToken.Parent is JProperty prop)
            prop.Value = replacement;
        else if (oldToken.Parent is JArray arr)
            arr[arr.IndexOf(oldToken)] = replacement;

        return replacement;
    }
    #endregion
}