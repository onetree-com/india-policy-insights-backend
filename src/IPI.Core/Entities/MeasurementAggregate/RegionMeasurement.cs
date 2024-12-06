
using IPI.Dto;
using System.Collections.Generic;

namespace IPI.Core.Entities.MeasurementAggregate
{
    public class RegionMeasurement
    {
        public int RegionId { get; set; }
        public int Year { get; set; }
        public int YearEnd { get; set; }
        public int IndId { get; set; }
        public string IndName { get; set; }
        public string IndNameHi { get; set; }
        public int IndReadingStrategy { get; set; }
        public decimal Prevalence { get; set; }
        public int Headcount { get; set; }
        public decimal? PrevalenceEnd { get; set; }
        public int? HeadcountEnd { get; set; }
        public string PrevalenceColor { get; set; }
        public string ChangeColor { get; set; }
        public string HeadcountColor { get; set; }
        public int  Decile { get; set; }
        public RegionDto? Type { get; set; }
        public int? PrevalenceRank { get; set; }
        public int? HeadcountRank { get; set; }
        public string DeepDiveCompareColor { get; set; }
    }

    public class RegionMeasurementChange : RegionMeasurement
    {        
        public int ChangeId { get; set; }
        public decimal PrevalenceChange  { get; set; }
        public decimal ChangeCutoffs { get; set; }
        public string ChangeHex { get; set; }
        public string ChangeDescription { get; set; }
        public string ChangeDescriptionHi { get; set; }
        public bool India { get; set; }
        public string Name { get; set; }
        public string NameHi { get; set; }
        public string StateName { get; set; }
        public string StateNameHi { get; set; }
        public string StateAbbreviation { get; set; }
        public string StateAbbreviationHi { get; set; }
        public string GeoId { get; set; }
    }

    public class RegionMeasurementChangeDto
    {
        public List<RegionMeasurementChange> AllIndia { get; set; }
        public List<RegionMeasurementChange> RegionsChange { get; set; }
    }

    public class RegionMeasurementDto
    {
        public RegionMeasurementDto()
        {
            State = new List<RegionMeasurement>();
            AllIndia = new List<RegionMeasurement>();
            Region = new List<RegionMeasurement>();
        }

        public List<RegionMeasurement> State { get; set; }
        public List<RegionMeasurement> AllIndia { get; set; }
        public List<RegionMeasurement> Region { get; set; }
    }
}
