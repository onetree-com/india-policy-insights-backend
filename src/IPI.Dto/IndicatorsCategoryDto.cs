using System.Collections.Generic;

namespace IPI.Dto
{
    public class ListCategoryIndicatorsDto
    {
        public int CatId { get; set; }
        public string CatName { get; set; }
        public string CatNameHi { get; set; }
        public int IndId { get; set; }
        public string IndName { get; set; }
        public string IndNameHi { get; set; }
        public int IndReadingStrategy { get; set; }
        public int Year { get; set; }
        public int YearEnd { get; set; }
        public decimal? Prevalence { get; set; }
        public int? PrevalenceRank { get; set; }
        public int? HeadcountRank { get; set; }
        public decimal? PrevalenceEnd { get; set; }
        public int? Count { get; set; }
        public int? CountEnd { get; set; }
        public string PrevalenceColor { get; set; }
        public string ChangeColor { get; set; }
        public string HeadcountColor { get; set; }
        public string Description { get; set; }
        public string DescriptionHi { get; set; }
        public int Decile { get; set; }
        public RegionDto Type { get; set; }
        public string DeepDiveCompareColor { get; set; }
    }

    public class CategoryIndicatorsDto
    {
        public int CatId { get; set; }
        public string CatName { get; set; }
        public string CatNameHi { get; set; }
        public CategoryIndicatorsDto State { get; set; }
        public CategoryIndicatorsDto AllIndia { get; set; }
        public List<ListCategoryIndicatorsDto> Indicators { get; set; }
    }
}
