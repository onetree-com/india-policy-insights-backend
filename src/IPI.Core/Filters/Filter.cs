

using IPI.Core.Enums;

namespace IPI.Core.Filters {
    public class Filter {
        public FilterType FilterType { get; set; }
        public string Field { get; set; }
        public object Value { get; set; }

        public Filter () { }

        public Filter (FilterType type, string field, object value) {
            FilterType = type;
            Field = field;
            Value = value;
        }
    }
}