using System;

namespace IPI.Dto.UrlShortenerAggregate
{
    public class ShortenedUrlDto
    {
        public string Key { get; set; }
        public string Url { get; set; }
        public int Clicks { get; set; }
        public DateTime? IsArchived { get; set; }
    }
}
