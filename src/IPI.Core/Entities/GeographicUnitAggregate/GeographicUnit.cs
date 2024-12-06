using IPI.SharedKernel;

namespace IPI.Core.Entities.GeographicUnitsAggregate
{
    public abstract class GeographicUnit : BaseEntity
    {
        public string GeoId { get; set; }
        public string Name { get; set; }
    }
}
