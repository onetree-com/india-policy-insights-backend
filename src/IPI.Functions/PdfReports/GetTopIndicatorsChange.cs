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

namespace IPI.Functions.PdfReports
{
    public class GetTopIndicatorsChange : BaseFunction
    {
        private readonly IPdfReportsRepository _repository;

        public GetTopIndicatorsChange(IPdfReportsRepository repository)
        {
            _repository = repository;
        }

        [FunctionName(nameof(GetTopIndicatorsChange))]
        public async Task<HttpResponseMessage> Run([HttpTrigger(AuthorizationLevel.Anonymous,
            nameof(HttpMethods.Post), Route = null)] HttpRequest request)
        {
            try
            {
                Log.Debug("Mapping request body");
                string content = await new StreamReader(request.Body).ReadToEndAsync();
                GetTopIndicatorsChangeRequestDto s = JsonConvert.DeserializeObject<GetTopIndicatorsChangeRequestDto>(content);

                Log.Debug("Handling request for top indicators change");
                var data = await _repository.GetTopIndicatorsChange(s).ConfigureAwait(false);

                Log.Debug("Procedure ended successfully");
                return data != null ? Ok(data) : Error(System.Net.HttpStatusCode.NoContent, $"No data found");
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
