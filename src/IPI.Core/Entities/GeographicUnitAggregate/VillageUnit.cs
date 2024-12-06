namespace IPI.Core.Entities.GeographicUnitsAggregate
{
    public class VillageUnit : GeographicUnit
    {
        public string StateGeoId { get; set; }
        public string DistrictGeoId { get; set; }
        public string PcGeoId { get; set; }
        public string AcGeoId { get; set; }
    }
}
