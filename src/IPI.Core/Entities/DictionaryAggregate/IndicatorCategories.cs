using System.Collections.Generic;

namespace IPI.Core.Entities.DictionaryAggregate
{
    public class ListIndicatorCategories
    {
        public int CatId { get; set; }
        public string CatName { get; set; }
        public string CatNameHi { get; set; }
        public int IndId { get; set; }
        public string IndName { get; set; }
        public string IndNameHi { get; set; }
        public string IndDescription { get; set; }
        public string IndDescriptionHi { get; set; }
        public int IndSourceId { get; set; }
        public string IndDefinition { get; set; }
        public int IndReadingStrategy { get; set; }
        public int IndExternalId { get; set; }
    }

    public class IndicatorCategories
    {
        public int CatId { get; set; }
        public string CatName { get; set; }
        public string CatNameHi { get; set; }
        public List<ListIndicatorCategories> Indicators { get; set; }
    }
}
