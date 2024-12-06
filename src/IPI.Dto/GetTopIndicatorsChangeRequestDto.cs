
namespace IPI.Dto
{
    public class GetTopIndicatorsChangeRequestDto
    {
        public int Year { get; set; }
        public int YearEnd { get; set; }
        public RegionDto? RegionType { get; set; }
        public int RegionId { get; set; }
        public int Count { get; set; }
        public bool Improvement { get; set; }
    }
}
