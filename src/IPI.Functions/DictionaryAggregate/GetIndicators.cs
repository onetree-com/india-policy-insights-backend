using System;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using IPI.Core.Interfaces;
using IPI.SharedKernel.Exceptions;
using Microsoft.AspNetCore.Http;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Serilog;

namespace IPI.Functions.DictionaryAggregate
{
    public class GetIndicators : BaseFunction
    {
        private readonly IDictionaryRepository _repository;

        public GetIndicators(IDictionaryRepository repository)
        {
            _repository = repository;
        }

        [FunctionName(nameof(GetIndicators))]
        public async Task<HttpResponseMessage> Run([HttpTrigger(AuthorizationLevel.Anonymous, nameof(HttpMethods.Get), Route = "dictionary/indicators")] HttpRequest request)
        {
            try
            {
                Log.Debug("Handling request for available indicators");
                var indicators = await _repository.GetIndicators().ConfigureAwait(false);

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

