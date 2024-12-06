using IPI.Core.Entities.MeasurementAggregate;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace IPI.Core.Interfaces
{
    public interface IVillageMeasurementRepository : IRepository
    {
        Task<IEnumerable<VillageMeasurement>> GetDistrictVillageMeasurements(int districtId, int indicator, int year);
    }
}
