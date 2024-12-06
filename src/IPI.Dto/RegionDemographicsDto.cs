
namespace IPI.Dto
{
    public class RegionDemographicsDto
    {
        public string Region { get; set; }
        public int Id { get; set; }
        public int RegionId { get; set; }
        public int Population { get; set; }
        public int Density { get; set; }
        public int SexRatio { get; set; }
        public int Female { get; set; }
        public int Male { get; set; }
        public decimal Urban { get; set; }
        public int Literate { get; set; }
    }
}
