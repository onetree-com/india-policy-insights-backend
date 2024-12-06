using IPI.Core.SharedKernel;
using System;
using System.Linq;

namespace IPI.Infrastructure.Data
{
    public class PgsqlFunction : ValueObject
    {
        public Guid Id { get; private set; }
        public string Name { get; private set; }

        public PgsqlFunction(string name)
        {
            Name = name;
            Id = Guid.NewGuid();
        }

        public override string ToString()
        {
            return Name;
        }

        /// <summary> Build the query string which refers to a postgresql function call</summary>
        /// <remarks>
        /// Be aware of the parameters the function may require, otherwise it could throw an exception.
        /// </remarks>
        /// <param name="parameters">the parameters of the postgresql function</param>
        /// <returns>Returns the template for a particular postgresql function including its parameters</returns>
        public string Template(params object[] parameters)
        {
            // exclude null values
            var values = parameters.OfType<object>();
            var arguments = string.Join(",", values);
            return $"SELECT * FROM {Name}({arguments})";
        }

        #region geographic unit functions
        public static PgsqlFunction GetDistrictsVillages { get { return getDistrictsVillages; } set { getDistrictsVillages = value; } }
        public static PgsqlFunction GetDistrictFilter { get { return getDistrictFilter; } set { getDistrictFilter = value; } }
        public static PgsqlFunction GetAcUnits { get { return getAcUnits; } set { getAcUnits = value; } }
        public static PgsqlFunction GetPcUnits { get { return getPcUnits; } set { getPcUnits = value; } }
        public static PgsqlFunction GetDctUnits { get { return getDctUnits; } set { getDctUnits = value; } }
        public static PgsqlFunction GetVgeUnits { get { return getVgeUnits; } set { getVgeUnits = value; } }
        public static PgsqlFunction GetAcHch { get { return getAcHch; } set { getAcHch = value; } }
        public static PgsqlFunction GetPcHch { get { return getPcHch; } set { getPcHch = value; } }
        public static PgsqlFunction GetDctHch { get { return getDctHch; } set { getDctHch = value; } }
        public static PgsqlFunction GetVgeHch { get { return getVgeHch; } set { getVgeHch = value; } }

        private static PgsqlFunction getDistrictsVillages = new PgsqlFunction("get_districtsvillages");
        private static PgsqlFunction getDistrictFilter = new PgsqlFunction("get_district_filter");
        private static PgsqlFunction getAcUnits = new PgsqlFunction("get_acUnits");
        private static PgsqlFunction getPcUnits = new PgsqlFunction("get_pcUnits");
        private static PgsqlFunction getDctUnits = new PgsqlFunction("get_districtUnits");
        private static PgsqlFunction getVgeUnits = new PgsqlFunction("get_villageUnits");
        private static PgsqlFunction getAcHch = new PgsqlFunction("get_acHch");
        private static PgsqlFunction getPcHch = new PgsqlFunction("get_pcHch");
        private static PgsqlFunction getDctHch = new PgsqlFunction("get_districtHch");
        private static PgsqlFunction getVgeHch = new PgsqlFunction("get_villageHch");
        #endregion

        #region measurement functions
        public static PgsqlFunction GetConfigElement { get { return getConfigElement; } set { getConfigElement = value; } }
        public static PgsqlFunction GetIndAcIndiaState { get { return getIndAcIndiaState; } set { getIndAcIndiaState = value; } }
        public static PgsqlFunction GetIndPcIndiaState { get { return getIndPcIndiaState; } set { getIndPcIndiaState = value; } }
        public static PgsqlFunction GetIndDistrictIndiaState { get { return getIndDistrictIndiaState; } set { getIndDistrictIndiaState = value; } }
        public static PgsqlFunction GetIndVillageIndiaState { get { return getIndVillageIndiaState; } set { getIndVillageIndiaState = value; } }
        public static PgsqlFunction GetIndiaMeasurements { get { return getIndiaMeasurements; } set { getIndiaMeasurements = value; } }
        public static PgsqlFunction GetDistrictMeasurements { get { return getDistrictMeasurements; } set { getDistrictMeasurements = value; } }
        public static PgsqlFunction GetVillageMeasurements { get { return getVillageMeasurements; } set { getVillageMeasurements = value; } }
        public static PgsqlFunction GetStateMeasurements { get { return getStateMeasurements; } set { getStateMeasurements = value; } }
        public static PgsqlFunction GetPcMeasurements { get { return getPcMeasurements; } set { getPcMeasurements = value; } }
        public static PgsqlFunction GetAcMeasurements { get { return getAcMeasurements; } set { getAcMeasurements = value; } }
        public static PgsqlFunction GetPcIndicators { get { return getPcIndicators; } set { getPcIndicators = value; } }
        public static PgsqlFunction GetStateIndicators { get { return getStateIndicators; } set { getStateIndicators = value; } }
        public static PgsqlFunction GetAcIndicators { get { return getAcIndicators; } set { getAcIndicators = value; } }
        public static PgsqlFunction GetDistrictIndicators { get { return getDistrictIndicators; } set { getDistrictIndicators = value; } }
        public static PgsqlFunction GetVillageIndicators { get { return getVillageIndicators; } set { getVillageIndicators = value; } }
        public static PgsqlFunction GetIndiaIndicators { get { return getIndiaIndicators; } set { getIndiaIndicators = value; } }
        public static PgsqlFunction GetPcCatIndicators { get { return getPcCatIndicators; } set { getPcCatIndicators = value; } }
        public static PgsqlFunction GetAcCatIndicators { get { return getAcCatIndicators; } set { getAcCatIndicators = value; } }
        public static PgsqlFunction GetDistrictCatIndicators { get { return getDistrictCatIndicators; } set { getDistrictCatIndicators = value; } }
        public static PgsqlFunction GetVillageCatIndicators { get { return getVillageCatIndicators; } set { getVillageCatIndicators = value; } }
        public static PgsqlFunction GetStateCatIndicators { get { return getStateCatIndicators; } set { getStateCatIndicators = value; } }
        public static PgsqlFunction GetAcDemographics { get { return getAcDemographics; } set { getAcDemographics = value; } }
        public static PgsqlFunction GetVillageDemographics { get { return getVillageDemographics; } set { getVillageDemographics = value; } }
        public static PgsqlFunction GetDistrictDemographics { get { return getDistrictDemographics; } set { getDistrictDemographics = value; } }
        public static PgsqlFunction GetPcDemographics { get { return getPcDemographics; } set { getPcDemographics = value; } }
        public static PgsqlFunction GetCensus { get { return getCensus; } set { getCensus = value; } }
        public static PgsqlFunction GetIndicatorChange { get { return getIndicatorChange; } set { getIndicatorChange = value; } }
        public static PgsqlFunction GetIndicatorChangeAc { get { return getIndicatorChangeAc; } set { getIndicatorChangeAc = value; } }
        public static PgsqlFunction GetIndicatorChangePc { get { return getIndicatorChangePc; } set { getIndicatorChangePc = value; } }
        public static PgsqlFunction GetStateMeasurementInd { get { return getStateMeasurementInd; } set { getStateMeasurementInd = value; } }
        public static PgsqlFunction GetIndiaMeasurementInd { get { return getIndiaMeasurementInd; } set { getIndiaMeasurementInd = value; } }
        public static PgsqlFunction GetPcMeasurementInd { get { return getPcMeasurementInd; } set { getPcMeasurementInd = value; } }
        public static PgsqlFunction GetAcMeasurementInd { get { return getAcMeasurementInd; } set { getAcMeasurementInd = value; } }
        public static PgsqlFunction GetDistrictMeasurementInd { get { return getDistrictMeasurementInd; } set { getDistrictMeasurementInd = value; } }
        public static PgsqlFunction GetVillageMeasurementInd { get { return getVillageMeasurementInd; } set { getVillageMeasurementInd = value; } }
        public static PgsqlFunction GetVillageMeasurementCng { get { return getVillageMeasurementCng; } set { getVillageMeasurementCng = value; } }
        public static PgsqlFunction GetDistrictMeasurementCng { get { return getDistrictMeasurementCng; } set { getDistrictMeasurementCng = value; } }
        public static PgsqlFunction GetPcMeasurementCng { get { return getPcMeasurementCng; } set { getPcMeasurementCng = value; } }
        public static PgsqlFunction GetAcMeasurementCng { get { return getAcMeasurementCng; } set { getAcMeasurementCng = value; } }
        public static PgsqlFunction GetIndiaMeasurementCng { get { return getIndiaMeasurementCng; } set { getIndiaMeasurementCng = value; } }
        public static PgsqlFunction GetIndicatorIndia { get { return getIndicatorIndia; } set { getIndicatorIndia = value; } }
        public static PgsqlFunction GetIndicatorDeciles { get { return getIndicatorDeciles; } set { getIndicatorDeciles = value; } }
        public static PgsqlFunction GetIndicatorDecilesAC { get { return getIndicatorDecilesAC; } set { getIndicatorDecilesAC = value; } }
        public static PgsqlFunction GetIndicatorDecilesPC { get { return getIndicatorDecilesPC; } set { getIndicatorDecilesPC = value; } }
        public static PgsqlFunction GetIndicatorDecilesVillages { get { return getIndicatorDecilesVillages; } set { getIndicatorDecilesVillages = value; } }
        public static PgsqlFunction GetDistrictIndicatorsBetterThanAllIndia { get { return getDistrictIndicatorsBetterThanAllIndia; } set { getDistrictIndicatorsBetterThanAllIndia = value; } }
        public static PgsqlFunction GetDistrictIndicatorsBetterThanState{ get { return getDistrictIndicatorsBetterThanState; } set { getDistrictIndicatorsBetterThanState= value; } }
        public static PgsqlFunction GetPcIndicatorsBetterThanAllIndia { get { return getPcIndicatorsBetterThanAllIndia; } set { getPcIndicatorsBetterThanAllIndia = value; } }
        public static PgsqlFunction GetPcIndicatorsBetterThanState { get { return getPcIndicatorsBetterThanState; } set { getPcIndicatorsBetterThanState = value; } }
        public static PgsqlFunction GetAcIndicatorsBetterThanAllIndia { get { return getAcIndicatorsBetterThanAllIndia; } set { getAcIndicatorsBetterThanAllIndia = value; } }
        public static PgsqlFunction GetAcIndicatorsBetterThanState { get { return getAcIndicatorsBetterThanState; } set { getAcIndicatorsBetterThanState = value; } }
        public static PgsqlFunction GetVillageIndicatorsBetterThanAllIndia{ get { return getVillageIndicatorsBetterThanAllIndia; } set { getVillageIndicatorsBetterThanAllIndia = value; } }
        public static PgsqlFunction GetVillageIndicatorsBetterThanDistrict { get { return getVillageIndicatorsBetterThanDistrict; } set { getVillageIndicatorsBetterThanDistrict = value; } }
        public static PgsqlFunction GetDistrictImprovementRanking { get { return getDistrictImprovementRanking; } set { getDistrictImprovementRanking = value; } }
        public static PgsqlFunction GetPcImprovementRanking { get { return getPcImprovementRanking; } set { getPcImprovementRanking = value; } }
        public static PgsqlFunction GetAcImprovementRanking { get { return getAcImprovementRanking; } set { getAcImprovementRanking = value; } }
        public static PgsqlFunction GetDistrictIndicatorsAmountPerChange { get { return getDistrictIndicatorsAmountPerChange; } set { getDistrictIndicatorsAmountPerChange = value; } }
        public static PgsqlFunction GetPcIndicatorsAmountPerChange { get { return getPcIndicatorsAmountPerChange; } set { getPcIndicatorsAmountPerChange = value; } }
        public static PgsqlFunction GetAcIndicatorsAmountPerChange { get { return getAcIndicatorsAmountPerChange; } set { getAcIndicatorsAmountPerChange = value; } }
        public static PgsqlFunction GetDistrictTopIndicatorsChange { get { return getDistrictTopIndicatorsChange; } set { getDistrictTopIndicatorsChange = value; } }
        public static PgsqlFunction GetPcTopIndicatorsChange { get { return getPcTopIndicatorsChange; } set { getPcTopIndicatorsChange = value; } }
        public static PgsqlFunction GetAcTopIndicatorsChange { get { return getAcTopIndicatorsChange; } set { getAcTopIndicatorsChange = value; } }
        public static PgsqlFunction GetDistrictTableOfIndicators { get { return getDistrictTableOfIndicators; } set { getDistrictTableOfIndicators = value; } }
        public static PgsqlFunction GetPcTableOfIndicators { get { return getPcTableOfIndicators; } set { getPcTableOfIndicators = value; } }
        public static PgsqlFunction GetAcTableOfIndicators { get { return getAcTableOfIndicators; } set { getAcTableOfIndicators = value; } }
        public static PgsqlFunction GetVillageTableOfIndicators { get { return getVillageTableOfIndicators; } set { getVillageTableOfIndicators = value; } }
        public static PgsqlFunction GetVillageIndicatorsPerDecile { get { return getVillageIndicatorsPerDecile; } set { getVillageIndicatorsPerDecile = value; } }

        private static PgsqlFunction getConfigElement = new PgsqlFunction("get_ConfigElement");
        private static PgsqlFunction getCensus = new PgsqlFunction("get_census");
        private static PgsqlFunction getIndAcIndiaState = new PgsqlFunction("get_indAc_IndiaState");
        private static PgsqlFunction getIndPcIndiaState = new PgsqlFunction("get_indPc_IndiaState");
        private static PgsqlFunction getIndDistrictIndiaState = new PgsqlFunction("get_indDistrict_IndiaState");
        private static PgsqlFunction getIndVillageIndiaState = new PgsqlFunction("get_indVillage_IndiaState");
        private static PgsqlFunction getIndiaMeasurements = new PgsqlFunction("get_india_measurements");
        private static PgsqlFunction getDistrictMeasurements = new PgsqlFunction("get_district_metrics");
        private static PgsqlFunction getVillageMeasurements = new PgsqlFunction("get_village_metrics");
        private static PgsqlFunction getPcMeasurements = new PgsqlFunction("get_pc_measurements");
        private static PgsqlFunction getStateMeasurements = new PgsqlFunction("get_state_measurements");
        private static PgsqlFunction getAcMeasurements = new PgsqlFunction("get_ac_measurements");
        private static PgsqlFunction getPcIndicators = new PgsqlFunction("get_pcIndicators");
        private static PgsqlFunction getAcIndicators = new PgsqlFunction("get_acIndicators");
        private static PgsqlFunction getStateIndicators = new PgsqlFunction("get_stateIndicators");
        private static PgsqlFunction getDistrictIndicators = new PgsqlFunction("get_districtIndicators");
        private static PgsqlFunction getVillageIndicators = new PgsqlFunction("get_villageIndicators");
        private static PgsqlFunction getIndiaIndicators = new PgsqlFunction("get_indiaindicators");
        private static PgsqlFunction getPcCatIndicators = new PgsqlFunction("get_pcCatIndicators");
        private static PgsqlFunction getAcCatIndicators = new PgsqlFunction("get_acCatIndicators");
        private static PgsqlFunction getDistrictCatIndicators = new PgsqlFunction("get_districtCatIndicators");
        private static PgsqlFunction getVillageCatIndicators = new PgsqlFunction("get_villageCatIndicators");
        private static PgsqlFunction getStateCatIndicators = new PgsqlFunction("get_stateCatIndicators");
        private static PgsqlFunction getPcDemographics = new PgsqlFunction("get_pcDemographics");
        private static PgsqlFunction getAcDemographics = new PgsqlFunction("get_acDemographics");
        private static PgsqlFunction getDistrictDemographics = new PgsqlFunction("get_districtDemographics");
        private static PgsqlFunction getVillageDemographics = new PgsqlFunction("get_villageDemographics");
        private static PgsqlFunction getIndicatorChange = new PgsqlFunction("get_indicatorChange");
        private static PgsqlFunction getIndicatorChangeAc = new PgsqlFunction("get_indicatorChangeac");
        private static PgsqlFunction getIndicatorChangePc = new PgsqlFunction("get_indicatorChangepc");
        private static PgsqlFunction getIndiaMeasurementInd = new PgsqlFunction("get_indiameasurements_ind");
        private static PgsqlFunction getStateMeasurementInd = new PgsqlFunction("get_statemeasurements_ind");
        private static PgsqlFunction getPcMeasurementInd = new PgsqlFunction("get_pcmeasurements_ind");
        private static PgsqlFunction getAcMeasurementInd = new PgsqlFunction("get_acmeasurements_ind");
        private static PgsqlFunction getDistrictMeasurementInd = new PgsqlFunction("get_districtmeasurements_ind");
        private static PgsqlFunction getVillageMeasurementInd = new PgsqlFunction("get_villagemeasurements_ind");
        private static PgsqlFunction getVillageMeasurementCng = new PgsqlFunction("get_villagemeasurements_cng");
        private static PgsqlFunction getDistrictMeasurementCng = new PgsqlFunction("get_districts_cng");
        private static PgsqlFunction getAcMeasurementCng = new PgsqlFunction("get_acmeasurements_cng");
        private static PgsqlFunction getPcMeasurementCng = new PgsqlFunction("get_pcmeasurements_cng");
        private static PgsqlFunction getIndiaMeasurementCng = new PgsqlFunction("get_indiameasurements_cng");
        private static PgsqlFunction getIndicatorIndia = new PgsqlFunction("get_indicatorIndia");
        private static PgsqlFunction getIndicatorDeciles = new PgsqlFunction("get_indicatorDeciles");
        private static PgsqlFunction getIndicatorDecilesAC = new PgsqlFunction("get_indicatorDecilesAC");
        private static PgsqlFunction getIndicatorDecilesPC = new PgsqlFunction("get_indicatorDecilesPC");
        private static PgsqlFunction getIndicatorDecilesVillages = new PgsqlFunction("get_indicatordecilesvillages");
        private static PgsqlFunction getDistrictIndicatorsBetterThanAllIndia = new PgsqlFunction("get_district_indicators_better_than_all_india");
        private static PgsqlFunction getDistrictIndicatorsBetterThanState= new PgsqlFunction("get_district_indicators_better_than_state");
        private static PgsqlFunction getPcIndicatorsBetterThanAllIndia = new PgsqlFunction("get_pc_indicators_better_than_all_india");
        private static PgsqlFunction getPcIndicatorsBetterThanState = new PgsqlFunction("get_pc_indicators_better_than_state");
        private static PgsqlFunction getAcIndicatorsBetterThanAllIndia = new PgsqlFunction("get_ac_indicators_better_than_all_india");
        private static PgsqlFunction getAcIndicatorsBetterThanState = new PgsqlFunction("get_ac_indicators_better_than_state");
        private static PgsqlFunction getVillageIndicatorsBetterThanAllIndia = new PgsqlFunction("get_village_indicators_better_than_all_india");
        private static PgsqlFunction getVillageIndicatorsBetterThanDistrict = new PgsqlFunction("get_village_indicators_better_than_district");
        private static PgsqlFunction getDistrictImprovementRanking = new PgsqlFunction("get_district_improvement_ranking");
        private static PgsqlFunction getPcImprovementRanking = new PgsqlFunction("get_pc_improvement_ranking");
        private static PgsqlFunction getAcImprovementRanking = new PgsqlFunction("get_ac_improvement_ranking");
        private static PgsqlFunction getDistrictIndicatorsAmountPerChange = new PgsqlFunction("get_district_indicators_amount_per_change");
        private static PgsqlFunction getPcIndicatorsAmountPerChange = new PgsqlFunction("get_pc_indicators_amount_per_change");
        private static PgsqlFunction getAcIndicatorsAmountPerChange = new PgsqlFunction("get_ac_indicators_amount_per_change");
        private static PgsqlFunction getDistrictTopIndicatorsChange = new PgsqlFunction("get_district_top_indicators_change");
        private static PgsqlFunction getPcTopIndicatorsChange = new PgsqlFunction("get_pc_top_indicators_change");
        private static PgsqlFunction getAcTopIndicatorsChange = new PgsqlFunction("get_ac_top_indicators_change");
        private static PgsqlFunction getDistrictTableOfIndicators = new PgsqlFunction("get_district_table_of_indicators");
        private static PgsqlFunction getPcTableOfIndicators = new PgsqlFunction("get_pc_table_of_indicators");
        private static PgsqlFunction getAcTableOfIndicators = new PgsqlFunction("get_ac_table_of_indicators");
        private static PgsqlFunction getVillageTableOfIndicators = new PgsqlFunction("get_village_table_of_indicators");
        private static PgsqlFunction getVillageIndicatorsPerDecile = new PgsqlFunction("get_village_indicators_per_decile");
        #endregion

        #region dictionary functions
        public static PgsqlFunction GetIndicators { get { return getIndicators; } set { getIndicators = value; } }
        public static PgsqlFunction GetCategories { get { return getCategories; } set { getCategories = value; } }
        public static PgsqlFunction GetIndicatorCategories { get { return getIndicatorCategories; } set { getIndicatorCategories = value; } }

        private static PgsqlFunction getIndicators = new PgsqlFunction("get_indicators");
        private static PgsqlFunction getCategories = new PgsqlFunction("get_categories");
        private static PgsqlFunction getIndicatorCategories = new PgsqlFunction("get_indicatorCategories");
        #endregion

        #region Others
        public static PgsqlFunction InsUrl { get { return insUrl; } set { insUrl = value; } }
        public static PgsqlFunction GetUrls { get { return getUrls; } set { getUrls = value; } }
        public static PgsqlFunction UpdUrl { get { return updUrl; } set { updUrl = value; } }

        private static PgsqlFunction getUrls = new PgsqlFunction("get_urls");
        private static PgsqlFunction insUrl = new PgsqlFunction("ins_url");
        private static PgsqlFunction updUrl = new PgsqlFunction("upd_url");
        #endregion
    }
}
