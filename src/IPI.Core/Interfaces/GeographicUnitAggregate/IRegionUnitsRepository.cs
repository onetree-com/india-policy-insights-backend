using System.Collections.Generic;
using System.Threading.Tasks;
using IPI.Dto;

namespace IPI.Core.Interfaces
{
    public interface IRegionUnitsRepository : IRepository
    {
        Task<IEnumerable<RegionUnitsDto>> GetRegionUnits(SearchUnitDto search);
        Task<DivisionDto> GetRegionHierarchy(SearchUnitDto search);
        Task<IEnumerable<RegionUnitsDto>> GetDistrictsByFilter(SearchDto search);
    }
}
