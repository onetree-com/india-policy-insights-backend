
using System.Collections.Generic;

namespace IPI.Dto
{
    public class IndicatorsDto
    {
        public int IndId { get; set; }
        public string IndName { get; set; }
        public string IndNameHi { get; set; }
        public int IndReadingStrategy { get; set; }
        public decimal? Median { get; set; }
        public decimal? MedianEnd { get; set; }
        public decimal? Min { get; set; }
        public decimal? MinEnd { get; set; }
        public decimal? Max { get; set; }
        public decimal? MaxEnd { get; set; }
        public decimal? HeadcountMedianEnd { get; set; }
        public decimal? HeadcountMedian { get; set; }
        public decimal? HeadcountMin { get; set; }
        public decimal? HeadcountMinEnd { get; set; }
        public decimal? HeadcountMax { get; set; }
        public decimal? HeadcountMaxEnd { get; set; }
        public List<IndicatorsRegionsDto> Divisions { get; set; }
        public string Description { get; set; }
        public string DescriptionHi { get; set; }
    }

    public class IndicatorsRegionsDto
    {
        public int IndId { get; set; }
        public string IndName { get; set; }
        public string IndNameHi { get; set; }
        public int IndReadingStrategy { get; set; }
        public int Id { get; set; }
        public string GeoId { get; set; }
        public string Name { get; set; }
        public string NameHi { get; set; }
        public string StateName { get; set; }
        public string StateNameHi { get; set; }
        public string StateAbbreviation { get; set; }
        public string StateAbbreviationHi { get; set; }
        public int Year { get; set; }
        public int YearEnd { get; set; }
        public decimal? Headcount { get; set; }
        public int? HeadcountRank { get; set; }
        public decimal? Prevalence { get; set; }
        public int? PrevalenceRank { get; set; }
        public decimal? HeadcountEnd { get; set; }
        public decimal? PrevalenceEnd { get; set; }
        public int? Count { get; set; }
        public int? CountEnd { get; set; }
        public string PrevalenceColor { get; set; }
        public string HeadcountColor { get; set; }
        public int PrevalenceDecile { get; set; }
        public int HeadcountDecile { get; set; }
        public string Description { get; set; }
        public string DescriptionHi { get; set; }
        public decimal? PrevalenceChange { get; set; }
        public int? PrevalenceChangeRank { get; set; }
    }

}
