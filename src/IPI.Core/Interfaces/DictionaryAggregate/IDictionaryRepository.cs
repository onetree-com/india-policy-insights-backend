using IPI.Core.Entities.DictionaryAggregate;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace IPI.Core.Interfaces
{
    public interface IDictionaryRepository : IRepository
    {
        Task<IEnumerable<Indicators>> GetIndicators();
        Task<IEnumerable<Categories>> GetCategories();
        Task<IEnumerable<IndicatorCategories>> GetIndicatorCategories(int cntReg, int cntIgn, int catId);
    }
}
