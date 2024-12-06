
namespace IPI.Core.Entities.GeographicUnitAggregate
{
    public class Units
    {
        public int Id { get; set; }
        public string GeoId { get; set; }
        public string Name { get; set; }
        public string NameHi { get; set; }
        public int? ParentId { get; set; }
        public int SubId { get; set; }
        public string SubGeoId { get; set; }
        public string SubName { get; set; }
        public string SubNameHi { get; set; }
        public int? SubParentId { get; set; }
        public bool? Aspirational { get; set; }
        public string Abbreviation { get; set; }
        public string AbbreviationHi { get; set; }
    }
}
