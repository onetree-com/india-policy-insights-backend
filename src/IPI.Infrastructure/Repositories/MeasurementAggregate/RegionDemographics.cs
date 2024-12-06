using IPI.Core.Interfaces;
using IPI.Dto;
using IPI.Infrastructure.Data;
using Serilog;
using System;
using System.Threading.Tasks;

namespace IPI.Infrastructure.Repositories
{
    public class RegionDemographics : Repository, IRegionDemographics
    {
        public RegionDemographics(ISqlConnectionProvider sqlConnectionProvider) : base(sqlConnectionProvider)
        {
        }

        public async Task<RegionDemographicsDto> GetRegionDemographics(SearchMetricDto search)
        {
            Log.Debug($"Building query string for {nameof(RegionDemographics)}.{nameof(GetRegionDemographics)}");
            var result = new RegionDemographicsDto();

            try
            {
                var query = PgsqlFunction.GetCensus.Template();
                result = await Get<RegionDemographicsDto>(query).ConfigureAwait(false);
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
