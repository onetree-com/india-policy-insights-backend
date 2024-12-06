
namespace IPI.Core.Entities.GeographicUnitAggregate
{
    public class Division
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string NameHi { get; set; }
        public int ParentId { get; set; }
        public string ParentName { get; set; }
        public string ParentNameHi { get; set; }
        public int StateId { get; set; }
        public string StateName { get; set; }
        public string StateNameHi { get; set; }
    }
}
