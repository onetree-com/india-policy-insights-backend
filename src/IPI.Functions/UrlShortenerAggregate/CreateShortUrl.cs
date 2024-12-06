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
using System.Net;

namespace IPI.Functions.UrlShortenerAggregate
{
    public class CreateShortUrl : BaseFunction
    {
        private readonly IUrlShortenerRepository _repository;
        public CreateShortUrl(IUrlShortenerRepository repository)
        {
            _repository = repository;
        }


        [FunctionName(nameof(CreateShortUrl))]
        public async Task<HttpResponseMessage> Run([HttpTrigger(AuthorizationLevel.Anonymous,
            nameof(HttpMethods.Post), Route = null)] HttpRequest request)
        {
            try
            {
                Log.Debug("Mapping request body");
                var content = await new StreamReader(request.Body).ReadToEndAsync();
                var input = JsonConvert.DeserializeObject<RawUrlDto>(content);

                if (string.IsNullOrEmpty(input.Url))
                {
                    Log.Debug("Bad query.");
                    return Error(HttpStatusCode.BadRequest, $"Can't shorten an empty URL");
                }

                var Url = await _repository.AddUrlAsync(input).ConfigureAwait(false);

                Log.Debug("Procedure ended successfully");
                return Ok(Url);
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
