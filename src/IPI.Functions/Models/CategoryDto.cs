using System.Collections.Generic;

namespace IPI.Functions.Models
{
    public class CategoryDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public IEnumerable<CategoryDto> Subcategories { get; set; }
    }
}
