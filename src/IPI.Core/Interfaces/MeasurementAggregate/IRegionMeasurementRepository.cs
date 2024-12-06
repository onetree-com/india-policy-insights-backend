using IPI.Core.Entities.MeasurementAggregate;
using IPI.Dto;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace IPI.Core.Interfaces
{
    public interface IRegionMeasurementRepository : IRepository
    {
        #region v1
        Task<IEnumerable<RegionMeasurement>> GetRegionMeasurement(SearchMetricDto sm);
        Task<CategoryIndicatorsDto> GetIndicatorsByCategory(SearchMetricDto sm);
        Task<IndicatorsDto> GetIndicatorRegion(SearchIndicatorRegionsDto sm);
        Task<IEnumerable<RegionMeasurement>> GetRegionMeasurements(SearchMetricDto sm);
        Task<RegionMeasurementChangeDto> GetRegionMeasurementChange(SearchMetricDto sm);
        Task<IEnumerable<IndicatorDecileDto>> GetIndicatorDeciles(SearchMetricDto sm);
        #endregion

        Task<RegionMeasurementDto> GetMeasurements(SearchMetricDto sm);
    }
}
