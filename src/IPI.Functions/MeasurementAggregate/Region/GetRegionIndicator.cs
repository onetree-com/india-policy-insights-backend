using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Newtonsoft.Json;
using IPI.Core.Interfaces;
using IPI.SharedKernel.Exceptions;
using Serilog;
using System.Net.Http;
using IPI.Dto;
using System.Linq;

namespace IPI.Functions.DictionaryAggregate
{
    public class GetRegionIndicator : BaseFunction
    {
        private readonly IRegionMeasurementRepository _repository;

        public GetRegionIndicator(IRegionMeasurementRepository repository)
        {
            _repository = repository;
        }

        [FunctionName(nameof(GetRegionIndicator))]
        public async Task<HttpResponseMessage> Run([HttpTrigger(AuthorizationLevel.Anonymous,
            nameof(HttpMethods.Post), Route = null)] HttpRequest request)
        {
            try
            {
                Log.Debug("Mapping request body");
                string content = await new StreamReader(request.Body).ReadToEndAsync();
                SearchMetricDto s = JsonConvert.DeserializeObject<SearchMetricDto>(content);

                if(!s.Indicators.Any()) 
                    return Error(System.Net.HttpStatusCode.NoContent, $"No region measurements where found");

                Log.Debug("Handling request for available region measurements");
                var data = await _repository.GetIndicatorsByCategory(s).ConfigureAwait(false);

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