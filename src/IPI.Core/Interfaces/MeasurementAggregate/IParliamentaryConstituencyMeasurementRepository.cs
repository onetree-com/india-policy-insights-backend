using IPI.Core.Entities.MeasurementAggregate;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace IPI.Core.Interfaces
{
    public interface IParliamentaryConstituencyMeasurementRepository : IRepository
    {
        Task<IEnumerable<ParliamentaryConstituencyMeasurement>> GetMeasurements(int indicator, int year);
        Task<IEnumerable<ParliamentaryConstituencyMeasurement>> GetStateParliamentaryConstituencyMeasurements(int stateId, int indicator, int year);

    }
}
