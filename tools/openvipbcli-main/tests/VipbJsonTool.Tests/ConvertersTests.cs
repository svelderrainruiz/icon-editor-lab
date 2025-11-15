using System;
using System.IO;
using System.Xml;
using VipbJsonTool;
using Xunit;

namespace VipbJsonTool.Tests
{
    public class ConvertersTests
    {
        [Fact]
        public void Vipb_Json_Vipb_Roundtrip_ProducesEquivalentXml()
        {
            // minimal but valid VIPB (no XML prolog)
            const string xml = "<Package><Name>Test</Name></Package>";
            var tmp = Path.GetTempPath();
            var vipb = Path.Combine(tmp, Guid.NewGuid() + ".vipb");
            var json = Path.ChangeExtension(vipb, ".json");
            var vipb2 = Path.Combine(tmp, "out_" + Path.GetFileName(vipb));

            File.WriteAllText(vipb, xml);

            VipbToJsonConverter.Convert(vipb, json);
            JsonToVipbConverter.Convert(json, vipb2);

            var d2 = new XmlDocument(); 
            d2.Load(vipb2);

            // Expect no extra <Package> nesting on roundtrip
            Assert.Equal(
                xml,
                d2.DocumentElement!.OuterXml.Trim());
        }
    }
}
