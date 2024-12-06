using IPI.Dto;
using IPI.Core.Entities.MeasurementAggregate;
using IPI.Core.Interfaces;
using IPI.Infrastructure.Data;
using Serilog;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Linq;
using IPI.Core.Entities.DictionaryAggregate;

namespace IPI.Infrastructure.Repositories
{
    public class RegionMeasurementRepository : Repository, IRegionMeasurementRepository
    {
        public RegionMeasurementRepository(ISqlConnectionProvider sqlConnectionProvider) : base(sqlConnectionProvider)
        {
        }

        #region V1
        public async Task<IEnumerable<RegionMeasurement>> GetRegionMeasurement(SearchMetricDto sm)
        {
            Log.Debug($"Building query string for {nameof(DictionaryRepository)}.{nameof(GetRegionMeasurement)}");
            var query = string.Empty;

            try
            {
                switch (sm.RegionType)
                {
                    case RegionDto.State:
                        query = PgsqlFunction.GetStateIndicators.Template(sm.Year, sm.RegionId, sm.RegCount, sm.RegIgnored);
                        break;

                    case RegionDto.Ac:
                        query = PgsqlFunction.GetAcIndicators.Template(sm.Year, sm.RegionId, sm.RegCount, sm.RegIgnored);
                        break;

                    case RegionDto.Pc:
                        query = PgsqlFunction.GetPcIndicators.Template(sm.Year, sm.RegionId, sm.RegCount, sm.RegIgnored);
                        break;

                    case RegionDto.District:
                        query = PgsqlFunction.GetDistrictIndicators.Template(sm.Year, sm.RegionId, sm.RegCount, sm.RegIgnored);
                        break;

                    case RegionDto.Village:
                        query = PgsqlFunction.GetVillageIndicators.Template(sm.Year, sm.RegionId, sm.RegCount, sm.RegIgnored);
                        break;

                    case RegionDto.India:
                        query = PgsqlFunction.GetIndiaIndicators.Template(sm.Year, sm.RegCount, sm.RegIgnored);
                        break;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Log.Debug($"Error {ex.Message}");
            }

            return await GetAll<RegionMeasurement>(query).ConfigureAwait(false);
        }

        public async Task<CategoryIndicatorsDto> GetIndicatorsByCategory(SearchMetricDto sm)
        {
            var result = new CategoryIndicatorsDto
            {
                Indicators = new List<ListCategoryIndicatorsDto>(),
                AllIndia = new CategoryIndicatorsDto
                {
                    Indicators = new List<ListCategoryIndicatorsDto>()
                }
            };

            if (sm.StateId > 0)
            {
                result.State = new CategoryIndicatorsDto { Indicators = new List<ListCategoryIndicatorsDto>() };
            }

            var query = string.Empty;
            var ind = ListToString(sm.Indicators);

            try
            {
                switch (sm.RegionType)
                {
                    case RegionDto.State:
                        query = PgsqlFunction.GetStateCatIndicators.Template(sm.Year, sm.YearEnd, sm.RegionId, ind, sm.Filter);
                        break;

                    case RegionDto.Ac:
                        query = PgsqlFunction.GetAcCatIndicators.Template(sm.Year, sm.YearEnd, sm.RegionId, ind, sm.Filter, sm.StateId);
                        break;

                    case RegionDto.Pc:
                        query = PgsqlFunction.GetPcCatIndicators.Template(sm.Year, sm.YearEnd, sm.RegionId, ind, sm.Filter, sm.StateId);
                        break;

                    case RegionDto.District:
                        query = PgsqlFunction.GetDistrictCatIndicators.Template(sm.Year, sm.YearEnd, sm.RegionId, ind, sm.Filter, sm.StateId);
                        break;

                    case RegionDto.Village:
                        query = PgsqlFunction.GetVillageCatIndicators.Template(sm.Year, sm.YearEnd, sm.RegionId, ind, sm.Filter, sm.StateId);
                        break;
                }

                var data = await GetAll<ListCategoryIndicatorsDto>(query).ConfigureAwait(false);
                var rec = data.FirstOrDefault();

                if (rec != null)
                {
                    result.CatName = rec.CatName;
                    result.CatNameHi = rec.CatNameHi;
                    result.CatId = rec.CatId;
                }

                foreach (var r in data)
                {
                    if (r.Type == RegionDto.None)
                    {
                        result.Indicators = OneObjectForIndId(r, result.Indicators);
                    }
                    if (r.Type == RegionDto.State)
                    {
                        result.State.Indicators = OneObjectForIndId(r, result.State.Indicators);
                    }
                    if (r.Type == RegionDto.India)
                    {
                        result.AllIndia.Indicators = OneObjectForIndId(r, result.AllIndia.Indicators);
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Log.Debug($"Error {ex.Message}");
            }

            return result;
        }

        /// <summary>
        /// Return the indicator in the indicated regions type
        /// </summary>
        /// <param name="sm"></param>
        /// <returns></returns>
        public async Task<IndicatorsDto> GetIndicatorRegion(SearchIndicatorRegionsDto sm)
        {
            var result = new IndicatorsDto();
            var query = string.Empty;

            Log.Debug($"Building regions Id string {nameof(RegionMeasurementRepository)}.{nameof(GetRegionMeasurements)}");
            var listRegId = ListToString(sm.RegionsId);

            try
            {
                Log.Debug($"Building query string for {nameof(DictionaryRepository)}.{nameof(GetIndicatorRegion)}");
                switch (sm.RegionType)
                {
                    case RegionDto.India:
                        query = PgsqlFunction.GetIndiaMeasurements.Template(sm.Year, sm.YearEnd, sm.IndId);
                        break;
                    case RegionDto.Ac:
                        query = PgsqlFunction.GetAcMeasurements.Template(sm.Year, sm.YearEnd, sm.IndId, listRegId);
                        break;

                    case RegionDto.Pc:
                        query = PgsqlFunction.GetPcMeasurements.Template(sm.Year, sm.YearEnd, sm.IndId, listRegId);
                        break;

                    case RegionDto.District:
                        query = PgsqlFunction.GetDistrictMeasurements.Template(sm.Year, sm.YearEnd, sm.IndId, listRegId);
                        break;

                    case RegionDto.State:
                        query = PgsqlFunction.GetStateMeasurements.Template(sm.Year, sm.YearEnd, sm.IndId, listRegId);
                        break;
                    case RegionDto.Village:
                        query = PgsqlFunction.GetVillageMeasurements.Template(sm.IndId, listRegId);
                        break;
                }

                var aux = await GetAll<IndicatorsRegionsDto>(query).ConfigureAwait(false);
                var rec = aux.FirstOrDefault();

                if (rec != null)
                {
                    result.IndId = rec.IndId;
                    result.IndName = rec.IndName;
                    result.IndNameHi = rec.IndNameHi;
                    result.IndReadingStrategy = rec.IndReadingStrategy;
                    result.Divisions = new List<IndicatorsRegionsDto> { rec };

                    Log.Debug($"Executing FormatDivision for {nameof(DictionaryRepository)}.{nameof(FormatDivision)}");
                    result = FormatDivision(result, aux);

                    if (result.Divisions.Count > 0)
                    {
                        var prevalence = result.Divisions.Select(d => d.Prevalence);
                        var prevalenceEnd = result.Divisions.Select(d => d.PrevalenceEnd);
                        var mid = prevalence.Count();

                        result.Median = GetMedian(prevalence.Where(p => p != null).Select(p => p.Value));
                        result.MedianEnd = prevalenceEnd.Sum() / mid;

                        result.Max = prevalence.Max();
                        result.MaxEnd = prevalenceEnd.Max();

                        result.Min = prevalence.Min();
                        result.MinEnd = prevalenceEnd.Min();

                        var headcount = result.Divisions.Select(d => d.Headcount);
                        var headcountEnd = result.Divisions.Select(d => d.HeadcountEnd);
                        var midHeadcount = headcount.Where(h => h.HasValue).Count();

                        List<decimal> headcountNotNull = new List<decimal>();
                        foreach (var h in headcount)
                        {
                            if (h.HasValue)
                            {
                                headcountNotNull.Add(h.Value);
                            }
                        }

                        result.HeadcountMedian = (int)GetMedian(headcountNotNull);
                        result.HeadcountMedianEnd = headcountEnd.Sum() / midHeadcount;

                        result.HeadcountMax = headcountNotNull.Max();
                        result.HeadcountMaxEnd = headcountEnd.Max();

                        result.HeadcountMin = headcountNotNull.Min();
                        result.HeadcountMinEnd = headcountEnd.Min();
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Log.Debug($"Error {ex.Message}");
            }

            return result;
        }

        private decimal GetMedian(IEnumerable<decimal> values)
        {
            var orderderList = values.OrderBy(v => v);
            if (orderderList.Count() % 2 == 1)
            {
                return orderderList.ElementAt(orderderList.Count() / 2);
            }

            return (orderderList.ElementAt(orderderList.Count() / 2) + orderderList.ElementAt((orderderList.Count() / 2) - 1)) / 2;
        }

        private decimal GetMedian(IEnumerable<int> values)
        {
            var orderderList = values.OrderBy(v => v);
            if (orderderList.Count() % 2 == 1)
            {
                return orderderList.ElementAt(orderderList.Count() / 2);
            }

            return (orderderList.ElementAt(orderderList.Count() / 2) + orderderList.ElementAt((orderderList.Count() / 2) - 1)) / 2;
        }

        public async Task<IEnumerable<RegionMeasurement>> GetRegionMeasurements(SearchMetricDto sm)
        {
            Log.Debug($"Building query string for {nameof(RegionMeasurementRepository)}.{nameof(GetRegionMeasurements)}");
            var result = new List<RegionMeasurement>();
            var query = string.Empty;

            Log.Debug($"Building string from list {nameof(RegionMeasurementRepository)}.{nameof(GetRegionMeasurements)}");
            var listInd = ListToString(sm.Indicators);

            try
            {
                switch (sm.RegionType)
                {
                    case RegionDto.India:
                        query = PgsqlFunction.GetIndiaMeasurementInd.Template(sm.Year, sm.YearEnd, sm.RegCount, sm.RegIgnored, listInd);
                        break;

                    case RegionDto.Ac:
                        query = PgsqlFunction.GetAcMeasurementInd.Template(sm.Year, sm.YearEnd, sm.RegionId, sm.RegCount, sm.RegIgnored, listInd);
                        break;

                    case RegionDto.Pc:
                        query = PgsqlFunction.GetPcMeasurementInd.Template(sm.Year, sm.YearEnd, sm.RegionId, sm.RegCount, sm.RegIgnored, listInd);
                        break;

                    case RegionDto.District:
                        query = PgsqlFunction.GetDistrictMeasurementInd.Template(sm.Year, sm.YearEnd, sm.RegionId, sm.RegCount, sm.RegIgnored, listInd);
                        break;

                    case RegionDto.Village:
                        query = PgsqlFunction.GetVillageMeasurementInd.Template(sm.Year, sm.YearEnd, sm.RegionId, sm.RegCount, sm.RegIgnored, listInd);
                        break;

                    case RegionDto.State:
                        query = PgsqlFunction.GetStateMeasurementInd.Template(sm.Year, sm.YearEnd, sm.RegionId, sm.RegCount, sm.RegIgnored, listInd);
                        break;
                }

                var aux = await GetAll<RegionMeasurement>(query).ConfigureAwait(false);

                foreach (var r in aux)
                {
                    var grp = result.FirstOrDefault(o => o.IndId == r.IndId);
                    if (grp == null)
                    {
                        result.Add(r);
                    }
                    else
                    {
                        grp.YearEnd = r.Year;
                        grp.PrevalenceEnd = r.Prevalence;
                        grp.HeadcountEnd = r.Headcount;
                    }
                }

            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Log.Debug($"Error {ex.Message}");
            }

            return result;
        }

        /// <summary>
        /// Obtains the measurements from one given region, one State and All India
        /// </summary>
        /// <param name="sm">Filters</param>
        /// <returns></returns>
        public async Task<RegionMeasurementDto> GetMeasurements(SearchMetricDto sm)
        {
            Log.Debug($"Building query string for {nameof(RegionMeasurementRepository)}.{nameof(GetMeasurements)}");
            var result = new RegionMeasurementDto();
            var query = string.Empty;

            Log.Debug($"Building string from list {nameof(RegionMeasurementRepository)}.{nameof(GetMeasurements)}");
            var listInd = ListToString(sm.Indicators);

            try
            {
                switch (sm.RegionType)
                {
                    case RegionDto.Ac:
                        query = PgsqlFunction.GetIndAcIndiaState.Template(sm.Year, sm.YearEnd, sm.RegionId, sm.RegCount, sm.RegIgnored, listInd, sm.StateId);
                        break;

                    case RegionDto.Pc:
                        query = PgsqlFunction.GetIndPcIndiaState.Template(sm.Year, sm.YearEnd, sm.RegionId, sm.RegCount, sm.RegIgnored, listInd, sm.StateId);
                        break;

                    case RegionDto.District:
                        query = PgsqlFunction.GetIndDistrictIndiaState.Template(sm.Year, sm.YearEnd, sm.RegionId, sm.RegCount, sm.RegIgnored, listInd, sm.StateId);
                        break;

                    case RegionDto.Village:
                        query = PgsqlFunction.GetIndVillageIndiaState.Template(sm.Year, sm.YearEnd, sm.RegionId, sm.RegCount, sm.RegIgnored, listInd, sm.StateId);
                        break;
                }

                var aux = await GetAll<RegionMeasurement>(query).ConfigureAwait(false);

                foreach (var r in aux)
                {
                    if (r.Type == RegionDto.None)
                    {
                        result.Region = OneObjectForIndId(r, result.Region);
                    }
                    if (r.Type == RegionDto.State)
                    {
                        result.State = OneObjectForIndId(r, result.State);
                    }
                    if (r.Type == RegionDto.India)
                    {
                        result.AllIndia = OneObjectForIndId(r, result.AllIndia);
                    }
                }

            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Log.Debug($"Error {ex.Message}");
            }

            return result;
        }

        #endregion

        public async Task<IEnumerable<IndicatorDecileDto>> GetIndicatorDeciles(SearchMetricDto sm)
        {
            Log.Debug($"Building query string for {nameof(RegionMeasurementRepository)}.{nameof(GetRegionMeasurements)}");
            var result = new List<IndicatorDecileDto>();

            Log.Debug($"Building indicators string {nameof(RegionMeasurementRepository)}.{nameof(GetRegionMeasurements)}");
            var listInd = ListToString(sm.Indicators);

            try
            {
                string query = string.Empty;
                switch (sm.RegionType)
                {
                    case RegionDto.Ac:
                        query = PgsqlFunction.GetIndicatorDecilesAC.Template(sm.Year, listInd);
                        break;

                    case RegionDto.Pc:
                        query = PgsqlFunction.GetIndicatorDecilesPC.Template(sm.Year, listInd);
                        break;

                    case RegionDto.District:
                        query = PgsqlFunction.GetIndicatorDeciles.Template(sm.Year, listInd);
                        break;
                    case RegionDto.Village:
                        query = PgsqlFunction.GetIndicatorDecilesVillages.Template(sm.StateId, listInd);
                        break;
                }

                var aux = await GetAll<IndicatorDecileDto>(query).ConfigureAwait(false);

                if (aux != null & aux.Count > 0)
                {
                    foreach (var r in aux)
                    {
                        var grp = result.FirstOrDefault(o => o.IndId == r.IndId);
                        if (grp == null)
                        {
                            r.HeadcountHx = new List<string> { r.HeadcountColor };
                            r.PrevalenceHx = new List<string> { r.PrevalenceColor };
                            r.Deciles = new List<int> { (int)r.Decile };
                            r.HeadcountDeciles = r.HeadcountDecile != null ? new List<int> { (int)r.HeadcountDecile } : null;

                            if (r.PrevalenceDecileCutoffs != null)
                                r.PrevalenceCutoffs = new List<decimal> { (decimal)r.PrevalenceDecileCutoffs };
                            else
                                r.PrevalenceCutoffs = new List<decimal> { 0 };

                            if (r.HeadcountDecileCutoffs != null)
                                r.HeadcountCutoffs = new List<int> { (int)r.HeadcountDecileCutoffs };
                            else
                                r.HeadcountCutoffs = new List<int> { 0 };

                            r.Decile = null;
                            result.Add(r);
                        }
                        else
                        {
                            grp.HeadcountHx.Add(r.HeadcountColor);
                            grp.PrevalenceHx.Add(r.PrevalenceColor);
                            grp.Deciles.Add((int)r.Decile);
                            if (r.HeadcountDecile.HasValue) grp.HeadcountDeciles.Add((int)r.HeadcountDecile);
                            grp.PrevalenceCutoffs.Add(r.PrevalenceDecileCutoffs != null ? (decimal)r.PrevalenceDecileCutoffs : 0);
                            grp.HeadcountCutoffs.Add(r.HeadcountDecileCutoffs != null ? (int)r.HeadcountDecileCutoffs : 0);
                        }
                    }
                    OrderDecileResults(result);
                }

            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Log.Debug($"Error {ex.Message}");
            }

            return result;
        }

        public async Task<RegionMeasurementChangeDto> GetRegionMeasurementChange(SearchMetricDto sm)
        {
            var query = string.Empty;
            var result = new RegionMeasurementChangeDto
            {
                RegionsChange = new List<RegionMeasurementChange>(),
                AllIndia = new List<RegionMeasurementChange>()
            };

            Log.Debug($"Building string from list {nameof(RegionMeasurementRepository)}.{nameof(GetRegionMeasurementChange)}");
            var listInd = ListToString(sm.Indicators);
            var listReg = ListToString(sm.RegionsId);

            try
            {
                Log.Debug($"Building query string for {nameof(RegionMeasurementRepository)}.{nameof(GetRegionMeasurementChange)}");
                switch (sm.RegionType)
                {
                    case RegionDto.Ac:
                        query = PgsqlFunction.GetAcMeasurementCng.Template(sm.Year, sm.YearEnd, listReg, sm.RegCount, sm.RegIgnored, listInd);
                        break;

                    case RegionDto.Pc:
                        query = PgsqlFunction.GetPcMeasurementCng.Template(sm.Year, sm.YearEnd, listReg, sm.RegCount, sm.RegIgnored, listInd);
                        break;

                    case RegionDto.District:
                        query = PgsqlFunction.GetDistrictMeasurementCng.Template(sm.Year, sm.YearEnd, listReg, sm.RegCount, sm.RegIgnored, listInd);
                        break;

                    case RegionDto.Village:
                        query = PgsqlFunction.GetVillageMeasurementCng.Template(sm.Year, sm.YearEnd, listReg, sm.RegCount, sm.RegIgnored, listInd);
                        break;
                }

                var aux = await GetAll<RegionMeasurementChange>(query).ConfigureAwait(false);
                aux = aux.OrderBy(a => a.Year).ToList();
                var rec = aux.FirstOrDefault();

                if (rec != null)
                {
                    foreach (var r in aux)
                    {
                        if (r.India)
                        {
                            var ind = result.AllIndia.FirstOrDefault(o => o.IndId == r.IndId);
                            if (ind == null)
                            {
                                result.AllIndia.Add(r);
                            }
                            else
                            {
                                ind.PrevalenceEnd = r.Prevalence;
                                ind.PrevalenceChange = r.PrevalenceChange;
                                ind.YearEnd = r.Year;
                            }
                        }
                        else
                        {
                            var grp = result.RegionsChange.FirstOrDefault(o => o.RegionId == r.RegionId);
                            if (grp == null)
                            {
                                result.RegionsChange.Add(r);
                            }
                            else
                            {
                                grp.HeadcountEnd = r.Headcount;
                                grp.PrevalenceEnd = r.Prevalence;
                                grp.ChangeId = r.ChangeId;
                                grp.ChangeHex = r.ChangeHex;
                                grp.ChangeCutoffs = r.ChangeCutoffs;
                                grp.ChangeDescription = r.ChangeDescription;
                                grp.PrevalenceChange = r.PrevalenceChange;
                                grp.YearEnd = r.Year;
                                grp.DeepDiveCompareColor = r.DeepDiveCompareColor;
                            }
                        }
                    }
                }

            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Log.Debug($"Error {ex.Message}");
            }

            return result;
        }

        #region Private Methods
        /// <summary>
        /// Returns values for many years to unique object grouped by indicator
        /// </summary>
        /// <param name="resultMetric">Category description Object with it's indicators list</param>
        /// <param name="data">Database recovered data after the query. List of indicators that match the input filters</param>
        /// <returns>Category with it's indicators list</returns>
        private List<ListCategoryIndicatorsDto> OneObjectForIndId(ListCategoryIndicatorsDto r, List<ListCategoryIndicatorsDto> data)
        {
            var max = data.FirstOrDefault(o => o.IndId == r.IndId);
            if (max == null)
            {
                data.Add(r);
            }
            else
            {
                max.YearEnd = r.Year;
                max.PrevalenceEnd = r.Prevalence;
                max.CountEnd = r.Count;
                max.PrevalenceColor = r.PrevalenceColor;
            }

            return data;
        }

        /// <summary>
        /// Join to one object any years by Indicator
        /// </summary>
        /// <param name="resultMetric"></param>
        /// <param name="data"></param>
        /// <returns></returns>
        private IndicatorsDto FormatDivision(IndicatorsDto resultMetric, IList<IndicatorsRegionsDto> data)
        {
            foreach (var r in data)
            {
                var max = resultMetric.Divisions.FirstOrDefault(o => o.Id == r.Id);
                if (max == null)
                {
                    resultMetric.Divisions.Add(r);
                }
                else
                {
                    max.YearEnd = r.Year;
                    max.PrevalenceEnd = r.Prevalence;
                    max.CountEnd = r.Count;
                    max.HeadcountEnd = r.Headcount;
                }
            }

            return resultMetric;
        }

        /// <summary>
        /// Turns a list of integers into a separated coma string
        /// </summary>
        /// <param name="list"></param>
        /// <returns></returns>
        private string ListToString(List<int> list)
        {
            if (list != null && list.Count > 0)
            {
                var listInd = string.Join(',', list);
                return $"'{listInd}'";
            }
            return $"''";
        }

        private List<RegionMeasurement> OneObjectForIndId(RegionMeasurement r, List<RegionMeasurement> data)
        {
            var max = data.FirstOrDefault(o => o.IndId == r.IndId);
            if (max == null)
            {
                data.Add(r);
            }
            else
            {
                max.YearEnd = r.Year;
                max.PrevalenceEnd = r.Prevalence;
                max.HeadcountEnd = r.Headcount;
            }

            return data;
        }

        /// <summary>
        /// Order lists of deciles, prevalence values and headcount values
        /// </summary>
        /// <param name="deciles"></param>
        private void OrderDecileResults(List<IndicatorDecileDto> deciles)
        {
            var res = deciles.FirstOrDefault();
            var ordPrevCutoffs = new List<decimal>();
            var ordPrevHx = new List<string>();

            for (var i = 0; i < res.Deciles.Count; i++)
            {
                var index = res.Deciles.IndexOf(i);
                ordPrevCutoffs.Add(res.PrevalenceCutoffs[index]);
                ordPrevHx.Add(res.PrevalenceHx[index]);
            }

            res.Deciles.Sort((d1, d2) =>
            {
                return d1 - d2;
            });
            res.PrevalenceCutoffs = ordPrevCutoffs;
            res.PrevalenceHx = ordPrevHx;

            var ordHeadCutoffs = new List<int>();
            var ordHeadHx = new List<string>();

            for (var i = 0; i < res.HeadcountDeciles.Count; i++)
            {
                var index = res.HeadcountDeciles.IndexOf(i);
                ordHeadCutoffs.Add(res.HeadcountCutoffs[index]);
                ordHeadHx.Add(res.HeadcountHx[index]);
            }
            res.HeadcountDeciles.Sort((d1, d2) =>
            {
                return d1 - d2;
            });
            res.HeadcountCutoffs = ordHeadCutoffs;
            res.HeadcountHx = ordHeadHx;
        }
        #endregion
    }
}