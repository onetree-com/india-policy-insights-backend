using IPI.Core.SharedKernel;
using System.Linq;

namespace IPI.Core.Entities.DictionaryAggregate
{
    public class IndicatorType : ValueObject
    {
        public int Id { get; set; }
        public string Name { get; set; }

        public IndicatorType(int id, string name)
        {
            Id = id;
            Name = name;
        }

        public override string ToString() => Name;

        public static IndicatorType GetById(int id) => GetAll<IndicatorType>().FirstOrDefault(item => item.Id == id);

        #region public attributes
        public IndicatorType Prevalence
        {
            get { return prevalence; }
            set { prevalence = value; }
        }
        public IndicatorType Headcount
        {
            get { return headcount; }
            set { headcount = value; }
        }
        public IndicatorType HNP
        {
            get { return hNP; }
            set { hNP = value; }
        }
        #endregion

        #region private attributes
        /// <summary>
        /// Prevalence Indicator Type (porcentual measurement)
        /// </summary>
        private IndicatorType prevalence = new IndicatorType(1, nameof(Prevalence));

        /// <summary>
        /// Headcount Indicator Type (discrete measurement)
        /// </summary>
        private IndicatorType headcount = new IndicatorType(2, nameof(Headcount));

        /// <summary>
        /// Health Nutrition Population Indicator Type
        /// </summary>
        private IndicatorType hNP = new IndicatorType(3, nameof(HNP));
        #endregion
    }
}
