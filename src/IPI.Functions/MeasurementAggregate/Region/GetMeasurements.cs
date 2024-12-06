using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using IPI.Core.Interfaces;
using IPI.Dto;
using IPI.SharedKernel.Exceptions;
using Serilog;
using System.Net.Http;

namespace IPI.Functions.MeasurementAggregate.Region
{
    public class GetMeasurements : BaseFunction
    {
        private readonly IRegionMeasurementRepository _repository;

        public GetMeasurements(IRegionMeasurementRepository repository)
        {
            _repository = repository;
        }

        [FunctionName(nameof(GetMeasurements))]
        public async Task<HttpResponseMessage> Run([HttpTrigger(AuthorizationLevel.Anonymous,
            nameof(HttpMethods.Post), Route = null)] HttpRequest request)
        {
            try
            {
                Log.Debug("Mapping request body");
                string content = await new StreamReader(request.Body).ReadToEndAsync();
                SearchMetricDto s = JsonConvert.DeserializeObject<SearchMetricDto>(content);

                if (s.Indicators == null || s.Indicators.Count == 0 || s.RegionType == RegionDto.None)
                {
                    Log.Debug("Bad query.");
                    return Error(System.Net.HttpStatusCode.NoContent, $"No region measurements where found");
                }

                Log.Debug("Handling request for available region measurements");
                var data = await _repository.GetMeasurements(s).ConfigureAwait(false);

                Log.Debug("Procedure ended successfully");
                return Ok(data);
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
