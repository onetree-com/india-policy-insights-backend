using IPI.Dto;
using IPI.Core.Interfaces;
using IPI.Infrastructure.Data;
using Serilog;
using System;
using System.Threading.Tasks;
using System.Linq;
using System.Collections.Generic;

namespace IPI.Infrastructure.Repositories
{
    public class PdfReportsRepository : Repository, IPdfReportsRepository
    {
        public PdfReportsRepository(ISqlConnectionProvider sqlConnectionProvider) : base(sqlConnectionProvider)
        {
        }

        public async Task<GetIndicatorsBetterThanResponseDto> GetIndicatorsBetterThanAverage(GetIndicatorsBetterThanRequestDto req)
        {
            var query = string.Empty;
            var result = new GetIndicatorsBetterThanResponseDto
            {
                BetterThanAverage = 0,
                TotalIndicators = 0,
            };

            try
            {
                Log.Debug($"Building query string for {nameof(GetIndicatorsBetterThanAverage)}");
                switch (req.RegionType)
                {
                    case RegionDto.District:
                        if (req.RegionToCompareType == RegionDto.India)
                        {
                            query = PgsqlFunction.GetDistrictIndicatorsBetterThanAllIndia.Template(req.Year, req.RegionId);
                        }
                        else if (req.RegionToCompareType == RegionDto.State)
                        {
                            query = PgsqlFunction.GetDistrictIndicatorsBetterThanState.Template(req.Year, req.RegionId);
                        }
                        break;
                    case RegionDto.Pc:
                        if (req.RegionToCompareType == RegionDto.India)
                        {
                            query = PgsqlFunction.GetPcIndicatorsBetterThanAllIndia.Template(req.Year, req.RegionId);
                        }
                        else if (req.RegionToCompareType == RegionDto.State)
                        {
                            query = PgsqlFunction.GetPcIndicatorsBetterThanState.Template(req.Year, req.RegionId);
                        }
                        break;
                    case RegionDto.Ac:
                        if (req.RegionToCompareType == RegionDto.India)
                        {
                            query = PgsqlFunction.GetAcIndicatorsBetterThanAllIndia.Template(req.Year, req.RegionId);
                        }
                        else if (req.RegionToCompareType == RegionDto.State)
                        {
                            query = PgsqlFunction.GetAcIndicatorsBetterThanState.Template(req.Year, req.RegionId);
                        }
                        break;
                    case RegionDto.Village:
                        if (req.RegionToCompareType == RegionDto.India)
                        {
                            query = PgsqlFunction.GetVillageIndicatorsBetterThanAllIndia.Template(req.Year, req.RegionId);
                        }
                        else if (req.RegionToCompareType == RegionDto.District)
                        {
                            query = PgsqlFunction.GetVillageIndicatorsBetterThanDistrict.Template(req.Year, req.RegionId);
                        }
                        break;
                    default:
                        break;
                }

                var aux = await GetAll<GetIndicatorsBetterThanResponseDto>(query).ConfigureAwait(false);
                result = aux.FirstOrDefault();
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Log.Debug($"Error {ex.Message}");
            }

            return result;
        }

        public async Task<GetImprovementRankingResponseDto> GetImprovementRanking(GetImprovementRankingRequestDto req)
        {
            var query = string.Empty;
            var result = new GetImprovementRankingResponseDto
            {
                Ranking = 0,
                SharedBy = 0,
            };

            try
            {
                Log.Debug($"Building query string for {nameof(GetImprovementRanking)}");
                switch (req.RegionType)
                {
                    case RegionDto.District:
                        query = PgsqlFunction.GetDistrictImprovementRanking.Template(req.Year, req.YearEnd, req.RegionId);
                        break;
                    case RegionDto.Pc:
                        query = PgsqlFunction.GetPcImprovementRanking.Template(req.Year, req.YearEnd, req.RegionId);
                        break;
                    case RegionDto.Ac:
                        query = PgsqlFunction.GetAcImprovementRanking.Template(req.Year, req.YearEnd, req.RegionId);
                        break;
                    default:
                        break;
                }

                var aux = await GetAll<GetImprovementRankingResponseDto>(query).ConfigureAwait(false);
                result = aux.FirstOrDefault();
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Log.Debug($"Error {ex.Message}");
            }

            return result;
        }

        public async Task<List<GetIndicatorsAmountPerChangeResponseDto>> GetIndicatorsAmountPerChange(GetIndicatorsAmountPerChangeRequestDto req)
        {
            var query = string.Empty;
            var result = new List<GetIndicatorsAmountPerChangeResponseDto>();

            try
            {
                Log.Debug($"Building query string for {nameof(GetIndicatorsAmountPerChange)}");
                switch (req.RegionType)
                {
                    case RegionDto.District:
                        query = PgsqlFunction.GetDistrictIndicatorsAmountPerChange.Template(req.Year, req.YearEnd, req.RegionId);
                        break;
                    case RegionDto.Pc:
                        query = PgsqlFunction.GetPcIndicatorsAmountPerChange.Template(req.Year, req.YearEnd, req.RegionId);
                        break;
                    case RegionDto.Ac:
                        query = PgsqlFunction.GetAcIndicatorsAmountPerChange.Template(req.Year, req.YearEnd, req.RegionId);
                        break;
                    default:
                        break;
                }

                var aux = await GetAll<GetIndicatorsAmountPerChangeResponseDto>(query).ConfigureAwait(false);
                var resultDb = aux.ToList();
                foreach (var r in resultDb)
                {
                    result.Add(r);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Log.Debug($"Error {ex.Message}");
            }

            return result;
        }

        public async Task<List<GetTopIndicatorsChangeResponseDto>> GetTopIndicatorsChange(GetTopIndicatorsChangeRequestDto req)
        {
            var query = string.Empty;
            var result = new List<GetTopIndicatorsChangeResponseDto>();

            try
            {
                Log.Debug($"Building query string for {nameof(GetTopIndicatorsChange)}");
                switch (req.RegionType)
                {
                    case RegionDto.District:
                        query = PgsqlFunction.GetDistrictTopIndicatorsChange.Template(req.Year, req.YearEnd, req.RegionId, req.Count, req.Improvement);
                        break;
                    case RegionDto.Pc:
                        query = PgsqlFunction.GetPcTopIndicatorsChange.Template(req.Year, req.YearEnd, req.RegionId, req.Count, req.Improvement);
                        break;
                    case RegionDto.Ac:
                        query = PgsqlFunction.GetAcTopIndicatorsChange.Template(req.Year, req.YearEnd, req.RegionId, req.Count, req.Improvement);
                        break;
                    default:
                        break;
                }

                var aux = await GetAll<GetTopIndicatorsChangeResponseDto>(query).ConfigureAwait(false);
                var resultDb = aux.ToList();
                foreach (var r in resultDb)
                {
                    result.Add(r);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Log.Debug($"Error {ex.Message}");
            }

            return result;
        }

        public async Task<List<IndicatorsForTableWithCategory>> GetTableOfIndicators(GetTableOfIndicatorsRequestDto req)
        {
            var query = string.Empty;
            var result = new List<IndicatorsForTableWithCategory>();

            try
            {
                Log.Debug($"Building query string for {nameof(GetTableOfIndicators)}");
                switch (req.RegionType)
                {
                    case RegionDto.District:
                        query = PgsqlFunction.GetDistrictTableOfIndicators.Template(req.Year, req.YearEnd, req.RegionId);
                        break;
                    case RegionDto.Pc:
                        query = PgsqlFunction.GetPcTableOfIndicators.Template(req.Year, req.YearEnd, req.RegionId);
                        break;
                    case RegionDto.Ac:
                        query = PgsqlFunction.GetAcTableOfIndicators.Template(req.Year, req.YearEnd, req.RegionId);
                        break;
                    case RegionDto.Village:
                        query = PgsqlFunction.GetVillageTableOfIndicators.Template(req.YearEnd, req.RegionId);
                        break;
                    default:
                        break;
                }

                var aux = await GetAll<GetTableOfIndicatorsResponseDto>(query).ConfigureAwait(false);
                var resultDb = aux.GroupBy(u => u.CatId)
                    .Select(grp => grp.ToList())
                    .ToList();
                foreach (var r in resultDb)
                {
                    var model = r.First();
                    var tableRow = new IndicatorsForTableWithCategory
                    {
                        CatId = model.CatId,
                        CatName = model.CatName,
                        CatNameHi = model.CatNameHi,
                        Indicators = r
                    };
                    result.Add(tableRow);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Log.Debug($"Error {ex.Message}");
            }

            return result;
        }

        public async Task<List<GetIndicatorsPerDecileResponseDto>> GetIndicatorsPerDecile(GetIndicatorsPerDecileRequestDto req)
        {
            var query = string.Empty;
            var result = new List<GetIndicatorsPerDecileResponseDto>();

            try
            {
                Log.Debug($"Building query string for {nameof(GetIndicatorsPerDecile)}");
                switch (req.RegionType)
                {
                    case RegionDto.Village:
                        query = PgsqlFunction.GetVillageIndicatorsPerDecile.Template(req.RegionId);
                        break;
                    default:
                        break;
                }

                var aux = await GetAll<GetIndicatorsPerDecileResponseDto>(query).ConfigureAwait(false);
                var resultDb = aux.ToList();
                foreach (var r in resultDb)
                {
                    result.Add(r);
                }
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