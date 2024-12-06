using IPI.Core.SharedKernel;
using System.Linq;

namespace IPI.Core.Entities.DictionaryAggregate
{
    public class IndicatorReadingStrategy : ValueObject
    {
        public int Id { get; set; }
        public string Name { get; set; }

        public IndicatorReadingStrategy(int id, string name)
        {
            Id = id;
            Name = name;
        }

        public override string ToString() => Name;

        public static IndicatorReadingStrategy GetById(int id) => GetAll<IndicatorReadingStrategy>().FirstOrDefault(item => item.Id == id);

        #region public attributes
        public IndicatorReadingStrategy LowerTheBetter
        {
            get { return lowerTheBetter; }
            set { lowerTheBetter = value; }
        }
        public IndicatorReadingStrategy HigherTheBetter
        {
            get { return higherTheBetter; }
            set { higherTheBetter = value; }
        }
        public IndicatorReadingStrategy Neutral
        {
            get { return neutral; }
            set { neutral = value; }
        }
        #endregion

        #region private attributes
        private IndicatorReadingStrategy lowerTheBetter = new IndicatorReadingStrategy(0, nameof(LowerTheBetter));
        private IndicatorReadingStrategy higherTheBetter = new IndicatorReadingStrategy(1, nameof(HigherTheBetter));
        private IndicatorReadingStrategy neutral = new IndicatorReadingStrategy(2, nameof(Neutral));
        #endregion
    }
}
