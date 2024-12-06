using Microsoft.Azure.Functions.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using IPI.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Serilog;
using Serilog.Events;
using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;
using IPI.Infrastructure.Data;

[assembly: FunctionsStartup(typeof(IPI.Functions.Startup))]
namespace IPI.Functions
{
    public class Startup : FunctionsStartup
    {
        public Startup()
        {
            Log.Logger = new LoggerConfiguration()
                .WriteTo.Console(LogEventLevel.Debug)
                .MinimumLevel.Debug()
                .MinimumLevel.Override("Microsoft", LogEventLevel.Information)
                .Enrich.FromLogContext()
                .CreateLogger();

            JsonConvert.DefaultSettings = () => new JsonSerializerSettings()
            {
                ContractResolver = new CamelCasePropertyNamesContractResolver(),
                Formatting = Formatting.Indented,
                DateFormatString = "yyyy-MM-ddTHH:mmZ",
                NullValueHandling = NullValueHandling.Ignore
            };
        }

        public override void Configure(IFunctionsHostBuilder builder)
        {
            builder.Services.AddLogging(builder => builder.AddSerilog(dispose: true));

            var context = builder.GetContext();
            var sqlConnectionString = context.Configuration.GetConnectionString("PgsqlConnectionString");
            builder.Services.RegisterInfrastructureServices(sqlConnectionString);
        }
    }
}
