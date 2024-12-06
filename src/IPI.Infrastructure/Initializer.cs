using IPI.Core.Interfaces;
using IPI.Core.Interfaces.UrlShortenerAggregate;
using IPI.Infrastructure.Providers;
using IPI.Infrastructure.Repositories;
using IPI.Infrastructure.Repositories.UrlShortenerAggregate;
using Microsoft.Extensions.DependencyInjection;

namespace IPI.Infrastructure
{
    public static class Initializer
    {
        public static void RegisterInfrastructureServices(this IServiceCollection services, string sqlConnectionString)
        {
            services.AddSingleton<ISqlConnectionProvider>(provider => new PgsqlConnectionProvider(sqlConnectionString));

            services.AddScoped<IDictionaryRepository, DictionaryRepository>();
            services.AddScoped<IRegionMeasurementRepository, RegionMeasurementRepository>();
            services.AddScoped<IPdfReportsRepository, PdfReportsRepository>();
            services.AddScoped<IRegionUnitsRepository, RegionUnitsRepository>();
            services.AddScoped<IRegionDemographics, RegionDemographics>();
            services.AddScoped<IIndicatorChangeRepository, IndicatorChangeRepository>();
            services.AddScoped<IUrlShortenerRepository, UrlShortenerRepository>();
        }
    }
}