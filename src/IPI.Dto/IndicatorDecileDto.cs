
using System.Collections.Generic;

namespace IPI.Dto
{
    public class IndicatorDecileDto
    {
        public int IndId { get; set; }
        public string IndName { get; set; }
        public string IndNameHi { get; set; }
        public int Year { get; set; }
        public int? Decile { get; set; }
        public int? HeadcountDecile { get; set; }
        public decimal? PrevalenceDecileCutoffs { get; set; }
        public int? HeadcountDecileCutoffs { get; set; }
        public string PrevalenceColor { get; set; }
        public string HeadcountColor { get; set; }
        public string Description { get; set; }
        public string DescriptionHi { get; set; }
        public List<string> PrevalenceHx { get; set; }
        public List<string> HeadcountHx { get; set; }
        public List<int> Deciles { get; set; }
        public List<int> HeadcountDeciles { get; set; }
        public List<decimal> PrevalenceCutoffs { get; set; }
        public List<int> HeadcountCutoffs { get; set; }
    }
}
