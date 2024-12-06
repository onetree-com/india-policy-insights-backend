using System.Collections.Generic;

namespace IPI.Dto
{
    public class SearchDto
    {
        public int RegCount { get; set; }
        public int RegIgnored { get; set; }
        public dynamic Filter { get; set; }
    }
}
