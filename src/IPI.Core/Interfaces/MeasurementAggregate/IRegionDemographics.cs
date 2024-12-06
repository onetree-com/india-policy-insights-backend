using IPI.Dto;
using System.Threading.Tasks;

namespace IPI.Core.Interfaces
{
    public interface IRegionDemographics : IRepository
    {
        Task<RegionDemographicsDto> GetRegionDemographics(SearchMetricDto search);
    }
}
