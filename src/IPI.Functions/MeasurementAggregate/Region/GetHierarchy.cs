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
using IPI.Functions.DictionaryAggregate;
using IPI.SharedKernel.Exceptions;
using Serilog;
using System.Net.Http;
using System.Linq;

namespace IPI.Functions.MeasurementAggregate.Region
{
    public class GetHierarchy : BaseFunction
    {
        private readonly IRegionUnitsRepository _repository;

        public GetHierarchy(IRegionUnitsRepository repository)
        {
            _repository = repository;
        }

        [FunctionName(nameof(GetHierarchy))]
        public async Task<HttpResponseMessage> Run([HttpTrigger(AuthorizationLevel.Anonymous,
            nameof(HttpMethods.Post), Route = null)] HttpRequest request)
        {
            try
            {
                Log.Debug("Mapping request body");
                string content = await new StreamReader(request.Body).ReadToEndAsync();
                SearchUnitDto s = JsonConvert.DeserializeObject<SearchUnitDto>(content);

                if (s.RegionId == 0 || s.RegionType == RegionDto.None)
                    return Error(System.Net.HttpStatusCode.NoContent, $"No region measurements where found");

                Log.Debug("Handling request for available region measurements");
                var data = await _repository.GetRegionHierarchy(s).ConfigureAwait(false);

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
