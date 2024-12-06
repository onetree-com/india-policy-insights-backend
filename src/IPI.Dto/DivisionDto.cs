
namespace IPI.Dto
{
    public class DivisionDto 
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string NameHi { get; set; }
        public DivisionDto Parent { get; set; }
    }
}
