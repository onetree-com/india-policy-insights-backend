using System;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using IPI.Dto;
using IPI.Core.Interfaces;
using IPI.SharedKernel.Exceptions;
using Microsoft.AspNetCore.Http;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Newtonsoft.Json;
using Serilog;

namespace IPI.Functions.DictionaryAggregate
{
    public class GetIndicatorCategories : BaseFunction
    {
        private readonly IDictionaryRepository _repository;

        public GetIndicatorCategories(IDictionaryRepository repository)
        {
            _repository = repository;
        }

        [FunctionName(nameof(GetIndicatorCategories))]
        public async Task<HttpResponseMessage> Run([HttpTrigger(AuthorizationLevel.Anonymous,
            nameof(HttpMethods.Post), Route = null)] HttpRequest request)
        {
            try
            {
                string content = await new StreamReader(request.Body).ReadToEndAsync();
                SearchDto s = JsonConvert.DeserializeObject<SearchDto>(content);

                s.Filter ??= 0;
                Log.Debug("Handling request for available indicators");
                var indicators = await _repository.GetIndicatorCategories(s.RegCount, s.RegIgnored, (int)s.Filter).ConfigureAwait(false);

                Log.Debug("Procedure ended successfully");
                return indicators.Any() ? Ok(indicators) : Error(System.Net.HttpStatusCode.NoContent, $"No indicators where found");
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
