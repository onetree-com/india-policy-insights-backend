using IPI.Core.Entities.UrlShortenerAggregate;
using IPI.Dto.UrlShortenerAggregate;
using System.Threading.Tasks;

namespace IPI.Core.Interfaces.UrlShortenerAggregate
{
    public interface IUrlShortenerRepository : IRepository
    {
        Task<RawUrlDto> AddUrlAsync(RawUrlDto input);
        Task<ShortenedUrlDto> ArchiveUrlAsync(string key);
        Task<ShortenedUrlDto> ClickUrlAsync(string key);
        Task<ShortenedUrlDto> GetUrlAsync(string key);
    }
}
