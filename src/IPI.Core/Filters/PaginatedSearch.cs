using System;

namespace IPI.Core.Filters {
    public class PaginatedSearch {
        public int PageNumber { get; set; }
        public int ItemsPerPage { get; set; }
        public Enum SortParameter { get; set; }
        public bool OrderDesc { get; set; }
    }
}