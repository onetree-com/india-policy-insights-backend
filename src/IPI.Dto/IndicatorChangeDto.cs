
namespace IPI.Dto
{
    public class IndicatorChangeDto
    {
        public int IndicatorId { get; set; }
        public int PrevalenceChangeId { get; set; }
        public decimal PrevalenceChangeCutoffs { get; set; }
        public string ChangeHex { get; set; }
        public string ChangeDescription { get; set; }
        public string IndicatorName { get; set; }
        public string IndicatorNameHi { get; set; }
        public string DeepDiveCompareColor { get; set; }
    }
}
