using IPI.Core.Entities.MeasurementAggregate;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace IPI.Core.Interfaces
{
    public interface IAssemblyConstituencyMeasurementRepository : IRepository
    {
        Task<IEnumerable<AssemblyConstituencyMeasurement>> GetMeasurements(int indicator, int year);
        Task<IEnumerable<AssemblyConstituencyMeasurement>> GetStateAssemblyConstituencyMeasurements(int stateId, int indicator, int year);
        Task<IEnumerable<AssemblyConstituencyMeasurement>> GetParliamentaryConstituencyAssemblyConstituencyMeasurements(int pcId, int indicator, int year);
        
    }
}
