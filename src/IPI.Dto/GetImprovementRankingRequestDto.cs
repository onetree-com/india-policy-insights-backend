
namespace IPI.Dto
{
    public class GetImprovementRankingRequestDto
    {
        public int Year { get; set; }
        public int YearEnd { get; set; }
        public RegionDto? RegionType { get; set; }
        public int RegionId { get; set; }
    }
}
