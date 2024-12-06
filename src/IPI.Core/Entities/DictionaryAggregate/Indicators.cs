using IPI.SharedKernel;

namespace IPI.Core.Entities.DictionaryAggregate
{
    public class Indicators : BaseEntity
    {
        public string Name { get; set; }
        public string NameHi { get; set; }
        public string Definition { get; set; }
        public int Category { get; set; }
        public int Subcategory { get; set; }
        public int Type { get; set; }
        public int ReadingStrategy { get; set;  }
    }
}
