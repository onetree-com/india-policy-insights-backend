using IPI.Core.Entities.DictionaryAggregate;
using IPI.Core.Interfaces;
using IPI.Infrastructure.Data;
using Serilog;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace IPI.Infrastructure.Repositories
{
    public class DictionaryRepository : Repository, IDictionaryRepository
    {
        public DictionaryRepository(ISqlConnectionProvider sqlConnectionProvider) : base(sqlConnectionProvider)
        {
        }

        public async Task<IEnumerable<Categories>> GetCategories()
        {
            Log.Debug($"Building query string for {nameof(DictionaryRepository)}.{nameof(GetCategories)}");
            var query = PgsqlFunction.GetCategories.Template();
            return await GetAll<Categories>(query).ConfigureAwait(false);
        }

        public async Task<IEnumerable<Indicators>> GetIndicators()
        {
            Log.Debug($"Building query string for {nameof(DictionaryRepository)}.{nameof(GetIndicators)}");
            var query = PgsqlFunction.GetIndicators.Template();
            return await GetAll<Indicators>(query).ConfigureAwait(false);
        }
        public async Task<IEnumerable<IndicatorCategories>> GetIndicatorCategories(int cntReg, int cntIgn, int catId)
        {
            Log.Debug($"Building query string for {nameof(DictionaryRepository)}.{nameof(GetIndicatorCategories)}");
            var query = PgsqlFunction.GetIndicatorCategories.Template(cntReg, cntIgn, catId);
            var aux = await GetAll<ListIndicatorCategories>(query).ConfigureAwait(false);

            var resultDb = aux.GroupBy(u => u.CatId)
                    .Select(grp => grp.ToList())
                    .ToList();

            var result = new List<IndicatorCategories>();
            foreach (var r in resultDb)
            {
                var model = r.First();
                var state = new IndicatorCategories
                {
                    CatId = model.CatId,
                    CatName = model.CatName,
                    CatNameHi = model.CatNameHi,
                    Indicators = r
                };
                result.Add(state);
            }

            return result;
        }
    }
}
