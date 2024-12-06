using IPI.Core.Entities.GeographicUnitAggregate;
using IPI.Core.Entities.UrlShortenerAggregate;
using IPI.Core.Interfaces;
using IPI.Core.Interfaces.UrlShortenerAggregate;
using IPI.Dto;
using IPI.Dto.UrlShortenerAggregate;
using IPI.Infrastructure.Data;
using IPI.SharedKernel.Exceptions;
using Serilog;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Threading.Tasks;

namespace IPI.Infrastructure.Repositories.UrlShortenerAggregate
{
    public class UrlShortenerRepository : Repository, IUrlShortenerRepository
    {
        public UrlShortenerRepository(ISqlConnectionProvider sqlConnectionProvider) : base(sqlConnectionProvider)
        {
        }

        /// <summary>
        /// Creates a new shortened url if it's key doesn't exist or return it if it already exists
        /// </summary>
        /// <param name="input"></param>
        /// <returns></returns>
        public async Task<RawUrlDto> AddUrlAsync(RawUrlDto input)
        {
            const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

            var random = new Random();
            var key = new string(Enumerable.Repeat(chars, 8)
                    .Select(s => s[random.Next(s.Length)]).ToArray());

            var query = PgsqlFunction.InsUrl.Template($"'{input.Url}'", $"'{key}'");

            var data = await Get<ShortenedUrl>(query);

            return new RawUrlDto { Url = data.Key };
        }

        public async Task<ShortenedUrlDto> ArchiveUrlAsync(string key)
        {
            var query = PgsqlFunction.GetUrls.Template($"'{key}'", false);

            var entity = await Get<ShortenedUrl>(query).ConfigureAwait(false);
            if (entity is null)
                throw new CustomException($"{nameof(ShortenedUrl)} couldn't be found");

            entity.ArchivedDate = DateTime.Today.Date;
            entity.Archived = true;

            var updated = await Update(entity).ConfigureAwait(false);
            if (updated is false)
                throw new CustomException($"{nameof(ShortenedUrl)} couldn't be updated");

            return Mapping.Mapper.Map<ShortenedUrlDto>(entity);
        }

        public async Task<ShortenedUrlDto> ClickUrlAsync(string key)
        {
            var query = PgsqlFunction.GetUrls.Template($"'{key}'", false);

            var entity = await Get<ShortenedUrl>(query).ConfigureAwait(false);
            if (entity is null)
                throw new CustomException($"{nameof(ShortenedUrl)} couldn't be found");

            entity.Clicks++;

            query = PgsqlFunction.UpdUrl.Template($"'{key}'", false, entity.Clicks);
            var updated = await Get<ShortenedUrl>(query);

            if (updated is null)
                throw new CustomException($"{nameof(ShortenedUrl)} couldn't be updated");

            return Mapping.Mapper.Map<ShortenedUrlDto>(entity);
        }

        public async Task<ShortenedUrlDto> GetUrlAsync(string key)
        {
            var query = PgsqlFunction.GetUrls.Template($"'{key}'", false);

            var entity = await Get<ShortenedUrl>(query).ConfigureAwait(false);
            if (entity is null)
                throw new CustomException($"{nameof(ShortenedUrl)} couldn't be found");

            return Mapping.Mapper.Map<ShortenedUrlDto>(entity);
        }
    }
}
