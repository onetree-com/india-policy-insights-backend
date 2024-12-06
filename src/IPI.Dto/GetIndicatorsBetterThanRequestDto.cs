
namespace IPI.Dto
{
    public class GetIndicatorsBetterThanRequestDto
    {
        public int Year { get; set; }
        public RegionDto? RegionType { get; set; }
        public int RegionId { get; set; }
        public RegionDto? RegionToCompareType { get; set; }
    }
}
