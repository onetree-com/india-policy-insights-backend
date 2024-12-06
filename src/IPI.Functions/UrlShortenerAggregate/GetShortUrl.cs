using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Newtonsoft.Json;
using IPI.SharedKernel.Exceptions;
using Serilog;
using System.Net.Http;
using IPI.Core.Interfaces.UrlShortenerAggregate;
using IPI.Dto.UrlShortenerAggregate;

namespace IPI.Functions.UrlShortenerAggregate
{
    public class GetShortUrl : BaseFunction
    {
        private readonly IUrlShortenerRepository _repository;
        public GetShortUrl(IUrlShortenerRepository repository)
        {
            _repository = repository;
        }


        [FunctionName(nameof(GetShortUrl))]
        public async Task<HttpResponseMessage> Run([HttpTrigger(AuthorizationLevel.Anonymous,
            nameof(HttpMethods.Post), Route = null)] HttpRequest request)
        {
            try
            {
                Log.Debug("Mapping request body");
                var content = await new StreamReader(request.Body).ReadToEndAsync();
                var input = JsonConvert.DeserializeObject<ShortenUrlDto>(content);

                if (string.IsNullOrEmpty(input.Key))
                {
                    Log.Debug("Bad query.");
                    return Error(System.Net.HttpStatusCode.NoContent, $"No URL was found");
                }

                if (string.IsNullOrEmpty(input.FallbackUrl))
                    Log.Warning("No fallback url obtained from request.");

                var data  = await _repository.ClickUrlAsync(input.Key).ConfigureAwait(false);

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
