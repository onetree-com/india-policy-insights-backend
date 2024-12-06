using IPI.Dto;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace IPI.Core.Interfaces
{
    public interface IPdfReportsRepository : IRepository
    {
        Task<GetIndicatorsBetterThanResponseDto> GetIndicatorsBetterThanAverage(GetIndicatorsBetterThanRequestDto req);
        Task<GetImprovementRankingResponseDto> GetImprovementRanking(GetImprovementRankingRequestDto req);
        Task<List<GetIndicatorsAmountPerChangeResponseDto>> GetIndicatorsAmountPerChange(GetIndicatorsAmountPerChangeRequestDto req);
        Task<List<GetTopIndicatorsChangeResponseDto>> GetTopIndicatorsChange(GetTopIndicatorsChangeRequestDto req);
        Task<List<IndicatorsForTableWithCategory>> GetTableOfIndicators(GetTableOfIndicatorsRequestDto req);
        Task<List<GetIndicatorsPerDecileResponseDto>> GetIndicatorsPerDecile(GetIndicatorsPerDecileRequestDto req);
    }
}
