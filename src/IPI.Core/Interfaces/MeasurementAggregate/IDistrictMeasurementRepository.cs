using IPI.Core.Entities.MeasurementAggregate;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace IPI.Core.Interfaces
{
    public interface IDistrictMeasurementRepository : IRepository
    {
        Task<IEnumerable<DistrictMeasurement>> GetRankedMeasurements(int indicator, int year, int? stateId);
    }
}
