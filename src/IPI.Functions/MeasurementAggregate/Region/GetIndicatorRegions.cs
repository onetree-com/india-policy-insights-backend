using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Newtonsoft.Json;
using IPI.Core.Interfaces;
using IPI.Dto;
using IPI.SharedKernel.Exceptions;
using Serilog;
using System.Net.Http;
using System.Linq;
using System.Collections.Generic;

namespace IPI.Functions.MeasurementAggregate.Region
{
    public class GetIndicatorRegions : BaseFunction
    {
        private readonly IRegionMeasurementRepository _repository;

        public GetIndicatorRegions(IRegionMeasurementRepository repository)
        {
            _repository = repository;
        }

        [FunctionName(nameof(GetIndicatorRegions))]
        public async Task<HttpResponseMessage> Run([HttpTrigger(AuthorizationLevel.Anonymous,
            nameof(HttpMethods.Get), Route = null)] HttpRequest request)
        {
            try
            {
                SearchIndicatorRegionsDto s = new SearchIndicatorRegionsDto()
                {
                    IndId = int.Parse(request.Query["indId"]),
                    RegionType = (RegionDto)int.Parse(request.Query["regionType"]),
                    Year = request.Query.ContainsKey("year") ? int.Parse(request.Query["year"]) : 0,
                    YearEnd = request.Query.ContainsKey("yearEnd") ? int.Parse(request.Query["yearEnd"]) : 0,
                    RegionsId = request.Query.ContainsKey("regionsId") && !string.IsNullOrEmpty(request.Query["regionsId"]) ? 
                    request.Query["regionsId"].ToString().Split(',').Select(r => int.Parse(r)).ToList() : new List<int>()
                };

                Log.Debug("Handling request for available region measurements");
                var data = await _repository.GetIndicatorRegion(s).ConfigureAwait(false);

                Log.Debug("Procedure ended successfully");
                return data != null ? Ok(data) : Error(System.Net.HttpStatusCode.NoContent, $"No region measurements where found");
            }
            catch (CustomException exception)
            {
                Log.Error(exception, exception.Message);
                return Error(System.Net.HttpStatusCode.BadRequest, exception.Message);
            }
            catch (Exception exception)
            {
                Log.Error(exception, exception.Message);
                return Error(System.Net.HttpStatusCode.BadRequest, "");
            }
        }
    }
}
