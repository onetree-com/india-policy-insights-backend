using IPI.Core.Entities.DictionaryAggregate;
using IPI.SharedKernel;

namespace IPI.Core.Entities.MeasurementAggregate
{
    public abstract class Measurement : BaseEntity
    {
        public int IndicatorId { get; set; }
        public int Type { get; set; }
        public int Year { get; set; }
        public decimal Value { get; set; }
    }
}
