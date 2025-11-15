// Adapted from upstream v1.3.3
using Newtonsoft.Json;
using System.Xml;

namespace VipbJsonTool;

/// <summary>
/// Utility that transforms a JSON string into an XmlDocument rooted at &lt;Package/&gt;.
/// </summary>
internal static class JsonToXmlConverter
{
    public static XmlDocument Convert(string json)
    {
        var doc = JsonConvert.DeserializeXmlNode(json, "Package") 
                  ?? throw new XmlException("Failed to convert JSON to XML.");

        // Ensure declaration (<?xml ...?>) exists.
        if (doc.FirstChild is not XmlDeclaration)
        {
            var decl = doc.CreateXmlDeclaration("1.0", "utf-8", null);
            doc.InsertBefore(decl, doc.DocumentElement);
        }

        return doc;
    }
}