using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace IPI.Core.Entities.UrlShortenerAggregate
{
    [Table("\"Urls\"")]
    public class ShortenedUrl
    {
        [Key]
        public string Key { get; set; }
        public string Url { get; set; }
        public int Clicks { get; set; }
        public bool Archived { get; set; }
        public DateTime? ArchivedDate { get; set; }
    }
}
