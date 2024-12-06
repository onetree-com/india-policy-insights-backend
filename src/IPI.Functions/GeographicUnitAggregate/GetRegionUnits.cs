using System;
using System.IO;
using System.Threading.Tasks;
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

namespace IPI.Functions.GeographicUnitAggregate
{
    public class GetRegionUnits : BaseFunction
    {
        private readonly IRegionUnitsRepository _repository;

        public GetRegionUnits(IRegionUnitsRepository repository)
        {
            _repository = repository;
        }

        [FunctionName(nameof(GetRegionUnits))]
        public async Task<HttpResponseMessage> Run([HttpTrigger(AuthorizationLevel.Anonymous,
            nameof(HttpMethods.Post), Route = null)] HttpRequest request)
        {
            try
            {
                Log.Debug("Mapping request body");
                string content = await new StreamReader(request.Body).ReadToEndAsync();
                SearchUnitDto s = JsonConvert.DeserializeObject<SearchUnitDto>(content);

                Log.Debug("Handling request for available region units");
                var data = await _repository.GetRegionUnits(s).ConfigureAwait(false);

                Log.Debug("Procedure ended successfully");
                return data.Any() ? Ok(data) : Error(System.Net.HttpStatusCode.NoContent, $"No region units where found");
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
