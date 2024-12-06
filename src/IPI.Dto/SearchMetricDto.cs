
using System.Collections.Generic;

namespace IPI.Dto
{
    public class SearchMetricDto
    {
        public int RegCount { get; set; }
        public int RegIgnored { get; set; }
        public int StateId { get; set; }
        public RegionDto RegionType { get; set; }
        public int RegionId { get; set; }
        public List<int> RegionsId { get; set; }
        public int Filter { get; set; }
        public int CategoryId { get; set; }
        public int Year { get; set; }
        public int YearEnd { get; set; }
        public List<int> Indicators { get; set; }
    }
}