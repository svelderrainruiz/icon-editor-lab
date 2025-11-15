// Adapted from upstream v1.3.3
using System;
using System.IO;
using System.Xml;
using Newtonsoft.Json;

namespace VipbJsonTool
{
    /// <summary>
    /// FR‑1 implementation: converts a .vipb XML file to an indented JSON file.
    /// </summary>
    internal static class VipbToJsonConverter
    {
        /// <exception cref="ArgumentException">When <paramref name="xmlPath"/> is null/empty.</exception>
        /// <exception cref="FileNotFoundException">When the input file is missing.</exception>
        public static void Convert(string xmlPath, string jsonPath)
        {
            if (string.IsNullOrWhiteSpace(xmlPath))
                throw new ArgumentException("Input XML path is required.", nameof(xmlPath));
            if (!File.Exists(xmlPath))
                throw new FileNotFoundException("Input .vipb file not found.", xmlPath);

            var doc = new XmlDocument { PreserveWhitespace = true };
            doc.Load(xmlPath);

            // Indented JSON, omit root object for correct round-trip.
            var json = JsonConvert.SerializeXmlNode(doc, Newtonsoft.Json.Formatting.Indented, omitRootObject: true);
            File.WriteAllText(jsonPath, json);
        }
    }
}
