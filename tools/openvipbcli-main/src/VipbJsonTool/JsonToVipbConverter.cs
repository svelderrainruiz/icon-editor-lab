// Adapted from upstream v1.3.3
using System;
using System.IO;
using System.Xml;

namespace VipbJsonTool;

/// <summary>
/// FR‑2 implementation: converts a JSON file into a .vipb XML file.
/// </summary>
internal static class JsonToVipbConverter
{
    public static void Convert(string jsonPath, string xmlPath)
    {
        if (string.IsNullOrWhiteSpace(jsonPath))
            throw new ArgumentException("Input JSON path is required.", nameof(jsonPath));
        if (!File.Exists(jsonPath))
            throw new FileNotFoundException("Input JSON file not found.", jsonPath);

        var json = File.ReadAllText(jsonPath);
        var doc  = JsonToXmlConverter.Convert(json);
        doc.PreserveWhitespace = true; // help diff‑stability

        // Write with indenting for readability.
        var settings = new XmlWriterSettings
        {
            Indent = true,
            Encoding = System.Text.Encoding.UTF8,
            OmitXmlDeclaration = false
        };
        using var writer = XmlWriter.Create(xmlPath, settings);
        doc.Save(writer);
    }
}