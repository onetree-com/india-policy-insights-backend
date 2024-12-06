namespace IPI.Core.Entities.MeasurementAggregate
{
    public class DistrictMeasurement : Measurement
    {
        public int DistrictId { get; set; }
        public int StateId { get; set; }
        public int Ranking { get; set; }
    }
}
