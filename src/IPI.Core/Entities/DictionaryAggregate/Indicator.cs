using IPI.SharedKernel;

namespace IPI.Core.Entities.DictionaryAggregate
{
    public class Indicator: BaseEntity
    {
        public string Name { get; set; }
        public int Direction { get; set; }
        public int CategoryId { get; set; }
    }
}
