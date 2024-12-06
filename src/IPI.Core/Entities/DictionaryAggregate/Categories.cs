using IPI.SharedKernel;

namespace IPI.Core.Entities.DictionaryAggregate
{
    public class Categories : BaseEntity
    {
        public string Name { get; set; }
        public int? ParentId { get; set; }
    }
}
