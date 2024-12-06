using IPI.Core.Entities.DictionaryAggregate;
using IPI.Core.Interfaces;
using IPI.Dto;
using IPI.Infrastructure.Data;
using Serilog;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IPI.Infrastructure.Repositories
{
    internal class IndicatorChangeRepository : Repository, IIndicatorChangeRepository
    {
        public IndicatorChangeRepository(ISqlConnectionProvider sqlConnectionProvider) : base(sqlConnectionProvider)
        {
        }

        public async Task<IEnumerable<IndicatorChangeDto>> GetIndicatorsChange(SearchMetricDto search)
        {
            var result = new List<IndicatorChangeDto>();

            Log.Debug($"Building indicators string {nameof(IndicatorChangeRepository)}.{nameof(GetIndicatorsChange)}");
            var listInd = string.Join(',', search.Indicators);
            listInd = $"'{listInd}'";

            try
            {
                Log.Debug($"Building query string for {nameof(IndicatorChangeRepository)}.{nameof(GetIndicatorsChange)}");

                string query = string.Empty;
                switch (search.RegionType)
                {
                    case RegionDto.Ac:
                        query = PgsqlFunction.GetIndicatorChangeAc.Template(search.RegCount, search.RegIgnored, listInd); ;
                        break;

                    case RegionDto.Pc:
                        query = PgsqlFunction.GetIndicatorChangePc.Template(search.RegCount, search.RegIgnored, listInd); ;
                        break;

                    case RegionDto.District:
                        query = PgsqlFunction.GetIndicatorChange.Template(search.RegCount, search.RegIgnored, listInd); ;
                        break;
                }

                var aux = await GetAll<IndicatorChangeDto>(query).ConfigureAwait(false);
                result = aux.ToList();
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Log.Debug($"Error {ex.Message}");
            }

            return result;
        }
    }
}
