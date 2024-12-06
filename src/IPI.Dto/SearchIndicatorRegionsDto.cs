using System.Collections.Generic;

namespace IPI.Dto
{
    public class SearchIndicatorRegionsDto
    {
        public int IndId { get; set; }
        public List<int> RegionsId { get; set; }
        public int Year { get; set; }
        public int YearEnd { get; set; }
        public RegionDto RegionType { get; set; }
    }
}
