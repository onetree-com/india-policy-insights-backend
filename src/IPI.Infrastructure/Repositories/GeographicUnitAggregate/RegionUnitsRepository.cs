using IPI.Core.Entities.GeographicUnitAggregate;
using IPI.Core.Interfaces;
using IPI.Dto;
using IPI.Infrastructure.Data;
using Serilog;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace IPI.Infrastructure.Repositories
{
    public class RegionUnitsRepository : Repository, IRegionUnitsRepository
    {
        public RegionUnitsRepository(ISqlConnectionProvider sqlConnectionProvider) : base(sqlConnectionProvider)
        {
        }

        public async Task<IEnumerable<RegionUnitsDto>> GetRegionUnits(SearchUnitDto search)
        {
            Log.Debug($"Building query string for {nameof(RegionUnitsRepository)}.{nameof(GetRegionUnits)}");
            var query = string.Empty;
            var result = new List<RegionUnitsDto>();

            try
            {
                switch (search.RegionType)
                {
                    case RegionDto.District:
                        query = PgsqlFunction.GetDctUnits.Template(search.RegionId, search.StateId, search.RegCount, search.RegIgnored);
                        break;
                    case RegionDto.Pc:
                        query = PgsqlFunction.GetPcUnits.Template(search.RegionId, search.StateId, search.RegCount, search.RegIgnored);
                        break;
                    case RegionDto.Ac:
                        query = PgsqlFunction.GetAcUnits.Template(search.RegionId, search.StateId, search.RegCount, search.RegIgnored);
                        break;
                    case RegionDto.Village:
                        query = PgsqlFunction.GetVgeUnits.Template(search.RegionId, search.RegCount, search.RegIgnored);
                        break;
                }

                if (query != string.Empty)
                {
                    var aux = await GetAll<Units>(query).ConfigureAwait(false);
                    var resultDb = aux.GroupBy(u => u.Id).Select(grp => grp.ToList()).ToList();

                    foreach (var r in resultDb)
                    {
                        var model = r.First();
                        var state = new RegionUnitsDto
                        {
                            Id = model.Id,
                            Name = model.Name,
                            NameHi = model.NameHi,
                            GeoId = model.GeoId,
                            Abbreviation = model.Abbreviation,
                            AbbreviationHi = model.AbbreviationHi,
                            Subregions = Mapping.Mapper.Map<List<UnitsDto>>(r)
                        };

                        result.Add(state);
                    }
                }
            }

            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
            }

            return result;
        }
    
        public async Task<DivisionDto> GetRegionHierarchy(SearchUnitDto search)
        {
            Log.Debug($"Building query string for {nameof(RegionUnitsRepository)}.{nameof(GetRegionHierarchy)}");
            var query = string.Empty;
            var result = new DivisionDto();

            try
            {
                switch (search.RegionType)
                {
                    case RegionDto.District:
                        query = PgsqlFunction.GetDctHch.Template(search.RegionId);
                        break;
                    case RegionDto.Pc:
                        query = PgsqlFunction.GetPcHch.Template(search.RegionId);
                        break;
                    case RegionDto.Ac:
                        query = PgsqlFunction.GetAcHch.Template(search.RegionId);
                        break;
                    case RegionDto.Village:
                        query = PgsqlFunction.GetVgeHch.Template(search.RegionId);
                        break;
                }

                if (query != string.Empty)
                {
                    var aux = await Get<Division>(query).ConfigureAwait(false);
                    result = Mapping.Mapper.Map<DivisionDto>(aux);

                    if (search.RegionType == RegionDto.Pc || search.RegionType == RegionDto.District)
                    {
                        result.Parent = result.Parent.Parent;
                    }
                    
                    if(result.Parent.Id == 0)
                    {
                        result.Parent = null;
                    }
                }
            }

            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
            }

            return result;
        }

        public async Task<IEnumerable<RegionUnitsDto>> GetDistrictsByFilter(SearchDto search)
        {
            var filter = string.IsNullOrEmpty(search.Filter) ? $"''" : $"'{search.Filter}'";
            var result = new List<RegionUnitsDto>();
            var resultDb = new List<List<Units>>();

            try
            {
                Log.Debug($"Building districts query string for {nameof(RegionUnitsRepository)}.{nameof(GetDistrictsByFilter)}");
                var query = PgsqlFunction.GetDistrictFilter.Template(filter, search.RegCount, search.RegIgnored);
                   
                Log.Debug("Executing query");
                var aux = await GetAll<Units>(query).ConfigureAwait(false);

                if (aux.Count == 0)
                {
                    Log.Debug($"No districts found by given filter for {nameof(RegionUnitsRepository)}.{nameof(GetDistrictsByFilter)}");
                    Log.Debug($"Building villages query string for {nameof(RegionUnitsRepository)}.{nameof(GetDistrictsByFilter)}");
                    query = PgsqlFunction.GetDistrictsVillages.Template(filter, search.RegCount);

                    Log.Debug("Executing query");
                    aux = await GetAll<Units>(query).ConfigureAwait(false);
                }
                
                resultDb = aux.GroupBy(u => u.Id).Select(grp => grp.ToList()).ToList();
                foreach (var r in resultDb)
                {
                    var model = r.First();
                    var state = new RegionUnitsDto
                    {
                        Id = model.Id,
                        Name = model.Name,
                        NameHi = model.NameHi,
                        GeoId = model.GeoId,
                        ParentId = model.ParentId,
                        Subregions = Mapping.Mapper.Map<List<UnitsDto>>(r)
                    };

                    result.Add(state);
                }
                
            }

            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
            }

            return result;
        }
    }
}
