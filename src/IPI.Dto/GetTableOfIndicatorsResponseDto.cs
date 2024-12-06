
using System.Collections.Generic;

namespace IPI.Dto
{
    public class GetTableOfIndicatorsResponseDto
    {
        public int CatId { get; set; }
        public int IndId { get; set; }
        public string CatName { get; set; }
        public string CatNameHi { get; set; }
        public string Name { get; set; }
        public string NameHi { get; set; }
        public string GoiAbv { get; set; }
        public string GoiAbvHi { get; set; }
        public decimal IndiaPrevalence { get; set; }
        public decimal StatePrevalence { get; set; }
        public decimal RegionPrevalence { get; set; }
        public decimal Change { get; set; }
        public int PrevalenceChangeCategory { get; set; }
        public int PrevDecile { get; set; }
    }

    public class IndicatorsForTableWithCategory
    {
        public int CatId { get; set; }
        public string CatName { get; set; }
        public string CatNameHi { get; set; }
        public List<GetTableOfIndicatorsResponseDto> Indicators { get; set; }
    }
}
