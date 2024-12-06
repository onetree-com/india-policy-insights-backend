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
using IPI.Functions.DictionaryAggregate;
using IPI.SharedKernel.Exceptions;
using Serilog;
using System.Net.Http;
using System.Linq;
using System.Collections.Generic;

namespace IPI.Functions.MeasurementAggregate.Region
{
    public class GetRegionIndicators : BaseFunction
    {
        private readonly IRegionMeasurementRepository _repository;

        public GetRegionIndicators(IRegionMeasurementRepository repository)
        {
            _repository = repository;
        }

        [FunctionName(nameof(GetRegionIndicators))]
        public async Task<HttpResponseMessage> Run([HttpTrigger(AuthorizationLevel.Anonymous,
            nameof(HttpMethods.Post), Route = null)] HttpRequest request)
        {
            try
            {
                Log.Debug("Mapping request body");
                string content = await new StreamReader(request.Body).ReadToEndAsync();
                SearchMetricDto s = JsonConvert.DeserializeObject<SearchMetricDto>(content);

                s.YearEnd = 0;
                s.Indicators = new List<int>();

                Log.Debug("Handling request for available region measurements");
                var data = await _repository.GetRegionMeasurement(s).ConfigureAwait(false);

                Log.Debug("Procedure ended successfully");
                return data.Any() ? Ok(data) : Error(System.Net.HttpStatusCode.NoContent, $"No region measurements where found");
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
