using IPI.Dto;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace IPI.Core.Interfaces
{
    public interface IIndicatorChangeRepository : IRepository
    {
        Task<IEnumerable<IndicatorChangeDto>> GetIndicatorsChange(SearchMetricDto search);
    }
}
