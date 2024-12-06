using System.Collections.Generic;

namespace IPI.Dto
{
    public class RegionUnitsDto
    {
        public int Id { get; set; }
        public string GeoId { get; set; }
        public string Name { get; set; }
        public string NameHi { get; set; }
        public string Abbreviation { get; set; }
        public string AbbreviationHi { get; set; }
        public int? ParentId { get; set; }
        public List<UnitsDto> Subregions { get; set; }
    }
}
