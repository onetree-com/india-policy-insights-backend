namespace IPI.Core.Entities.MeasurementAggregate
{
    public class VillageMeasurement : Measurement
    {
        public int StateId { get; set; }
        public int DistrictId { get; set; }
        public int PcId { get; set; }
        public int AcId { get; set; }
    }
}
