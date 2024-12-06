--
-- PostgreSQL database dump
--

-- Dumped from database version 14.12
-- Dumped by pg_dump version 16.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: azure_pg_admin
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO azure_pg_admin;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: azure_pg_admin
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: indicatorreadingstrategy; Type: TYPE; Schema: public; Owner: dbuser
--

CREATE TYPE public.indicatorreadingstrategy AS ENUM (
    'HigherTheBetter',
    'LowerTheBetter',
    'Neutral'
);


ALTER TYPE public.indicatorreadingstrategy OWNER TO dbuser;

--
-- Name: get_ac_improvement_ranking(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_ac_improvement_ranking(yearsh integer, yearend integer, acid integer) RETURNS TABLE("Ranking" bigint, "SharedBy" bigint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        WITH Prevalence2016 AS (
    SELECT "AcId", "IndicatorId", "Prevalence"
    FROM "IndicatorAc"
    WHERE "Year" = yearsh
),
AcRanking AS (
SELECT acu."Id" AS "AcId",
       COUNT(indac."AcId") FILTER (WHERE
           indac."Prevalence" > CASE
               WHEN ind."Direction" = 1 THEN p2016."Prevalence"
               WHEN ind."Direction" = 2 THEN -p2016."Prevalence"
               ELSE NULL
           END
       ) AS "ImprovedIndicatorsCount"
FROM "AcUnits" acu
LEFT JOIN "IndicatorAc" indac ON indac."AcId" = acu."Id" AND indac."Year" = yearend
LEFT JOIN "Indicator" ind ON ind."Id" = indac."IndicatorId"
LEFT JOIN Prevalence2016 p2016 ON p2016."IndicatorId" = indac."IndicatorId" AND p2016."AcId" = acu."Id"
GROUP BY acu."Id"
)
, RankedAcs AS (
            SELECT "AcId", "ImprovedIndicatorsCount",
                RANK() OVER (ORDER BY "ImprovedIndicatorsCount" DESC) AS "Rank"
            FROM AcRanking
        )
        , RankedAcsCount AS (
            SELECT "AcId", "ImprovedIndicatorsCount", "Rank",
                COUNT(*) OVER (PARTITION BY "Rank") AS "AcsWithSameRank"
            FROM RankedAcs
        )
        SELECT "Rank", "AcsWithSameRank"
        FROM RankedAcsCount
        WHERE "AcId" = acid;
	END;
$$;


ALTER FUNCTION public.get_ac_improvement_ranking(yearsh integer, yearend integer, acid integer) OWNER TO dbuser;

--
-- Name: get_ac_indicators_amount_per_change(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_ac_indicators_amount_per_change(yearsh integer, yearend integer, acid integer) RETURNS TABLE("PrevalenceChangeCategory" integer, "IndicatorCount" bigint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        WITH DataWithDifference AS (
            SELECT "IndicatorId", "AcId",
                MAX(CASE WHEN "Year" = yearend THEN "Prevalence" END) -
                MAX(CASE WHEN "Year" = yearsh THEN "Prevalence" END) AS "Difference"
            FROM "IndicatorAc"
            WHERE "AcId" = acid
            AND "Year" IN (yearsh, yearend)
            GROUP BY "IndicatorId", "AcId"
        )
        , DataWithCutoffs AS (
            SELECT dd.*,
                ic."PrevalenceChangeId",
                ic."PrevalenceChangeCutoffs"
            FROM DataWithDifference dd
            JOIN "IndicatorChangeAc" ic
            ON dd."IndicatorId" = ic."IndicatorId"
        )
        , DataWithDirection AS (
            SELECT "IndicatorId", "AcId", "Difference", "PrevalenceChangeId", "PrevalenceChangeCutoffs", i."Direction"
            FROM DataWithCutoffs
            JOIN "Indicator" i
            ON "IndicatorId" = i."Id"
        )
        , RankedData AS (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY "IndicatorId" ORDER BY "PrevalenceChangeId") AS rn
            FROM DataWithDirection
            WHERE ("Direction" = 1 AND "PrevalenceChangeId" <> 0 AND "Difference" > "PrevalenceChangeCutoffs")
            OR ("Direction" = 2 AND "PrevalenceChangeId" <> 0 AND "Difference" < "PrevalenceChangeCutoffs")
        )
        , ReducedRankedData AS (
            SELECT * FROM RankedData
            WHERE rn = 1
        )
        , PrevalenceChangeCounts AS (
            SELECT "PrevalenceChangeId", COUNT(*) AS "RowCount"
            FROM ReducedRankedData
            GROUP BY "PrevalenceChangeId"
        )
        SELECT gs."PrevalenceChangeId" AS "PrevalenceChangeCategory", COALESCE(pcc."RowCount", 0) AS "IndicatorCount"
        FROM generate_series(1, 4) AS gs("PrevalenceChangeId")
        LEFT JOIN PrevalenceChangeCounts pcc
        ON gs."PrevalenceChangeId" = pcc."PrevalenceChangeId"
        ORDER BY gs."PrevalenceChangeId";
	END;
$$;


ALTER FUNCTION public.get_ac_indicators_amount_per_change(yearsh integer, yearend integer, acid integer) OWNER TO dbuser;

--
-- Name: get_ac_indicators_better_than_all_india(integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_ac_indicators_better_than_all_india(yearsh integer, acid integer) RETURNS TABLE("BetterThanAverage" bigint, "TotalIndicators" bigint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        SELECT 
            COUNT(distinct indac."IndicatorId") AS "BetterThanAverage",
            (SELECT COUNT(*) FROM public."Indicator" WHERE "Description" IS NOT NULL) AS "TotalIndicators"
        FROM public."IndicatorAc" indac
        WHERE "Year" = yearsh AND "AcId" = acid
        AND CASE 
            WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indac."IndicatorId") = 1 THEN
                "Prevalence"  >= (SELECT "Prevalence" FROM public."IndicatorIndia" WHERE "IndicatorId" = indac."IndicatorId" AND "Year" = yearsh)
            WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indac."IndicatorId") = 2 THEN
                "Prevalence"  <= (SELECT "Prevalence" FROM public."IndicatorIndia" WHERE "IndicatorId" = indac."IndicatorId" AND "Year" = yearsh)
            ELSE
                NULL
        END;
	END;
$$;


ALTER FUNCTION public.get_ac_indicators_better_than_all_india(yearsh integer, acid integer) OWNER TO dbuser;

--
-- Name: get_ac_indicators_better_than_state(integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_ac_indicators_better_than_state(yearsh integer, acid integer) RETURNS TABLE("BetterThanAverage" bigint, "TotalIndicators" bigint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        SELECT 
            COUNT(distinct indac."IndicatorId") AS "BetterThanAverage",
            (SELECT COUNT(*) FROM public."Indicator" WHERE "Description" IS NOT NULL) AS "TotalIndicators"
        FROM public."IndicatorAc" indac
        WHERE "Year" = yearsh AND "AcId" = acid

        AND CASE 
                WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indac."IndicatorId") = 1 THEN
                    "Prevalence"  >=  (
                        SELECT "Prevalence" FROM public."IndicatorState"
                        WHERE "StateId" = (
                            SELECT "StateId" FROM "AcUnits" du
                            WHERE du."Id" = acid
                            LIMIT 1
                        ) AND "IndicatorId" = indac."IndicatorId" AND "Year" = yearsh
                        LIMIT 1
                    )
                WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indac."IndicatorId") = 2 THEN
                    "Prevalence"  <= (
                        SELECT "Prevalence" FROM public."IndicatorState"
                        WHERE "StateId" = (
                            SELECT "StateId" FROM "AcUnits" du
                            WHERE du."Id" = acid
                            LIMIT 1
                        ) AND "IndicatorId" = indac."IndicatorId" AND "Year" = yearsh
                        LIMIT 1
                    )
                ELSE
                    NULL
            END;

	END;
$$;


ALTER FUNCTION public.get_ac_indicators_better_than_state(yearsh integer, acid integer) OWNER TO dbuser;

--
-- Name: get_ac_measurements(integer, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_ac_measurements(yearsh integer, yearend integer, indicatorid integer, listregid character varying) RETURNS TABLE("IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingStrategy" integer, "Description" text, "DescriptionHi" text, "Id" integer, "GeoId" character varying, "Name" text, "NameHi" text, "StateName" text, "StateNameHi" text, "StateAbbreviation" character varying, "StateAbbreviationHi" character varying, "Year" integer, "Prevalence" numeric, "Headcount" numeric, "PrevalenceRank" integer, "HeadcountRank" integer, "PrevalenceColor" character varying, "HeadcountColor" character varying, "PrevalenceDecile" integer)
    LANGUAGE plpgsql
    AS $$

	BEGIN 
        RETURN	QUERY
		SELECT 
                "Indicator"."Id" AS "IndId",
                "Indicator"."Name" AS "IndName",
                "Indicator"."Name_hi" AS "IndNameHi,",
                "Indicator"."Direction" AS "IndReadingStrategy",
                "Indicator"."Description" AS "Description",
                "Indicator"."Description_hi" AS "DescriptionHi,",
                "AcUnits"."Id" AS "Id",
                "AcUnits"."GeoId" AS "GeoId",
                "AcUnits"."Name" AS "Name",
                "AcUnits"."Name_hi" AS "NameHi,",
                "StateUnits"."Name" AS "StateName",
                "StateUnits"."Name_hi" AS "StateNameHi",
                "StateUnits"."Abbreviation" AS "StateAbbreviation",
                "StateUnits"."Abbreviation_hi" AS "StateAbbreviationHi",
				"IndicatorAc"."Year" AS "Year",
				"IndicatorAc"."Prevalence" AS "Prevalence",
				"IndicatorAc"."Headcount" AS "Headcount",
                "IndicatorAc"."AcPrevalenceRank" AS "PrevalenceRank",
				"IndicatorAc"."AcHeadcountRank" AS "HeadcountRank",
				"IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
				"IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
				"IndicatorDeciles"."PrevalenceDecile" AS "PrevalenceDecile"
        FROM "IndicatorAc" 
        inner join "AcUnits" ON "AcUnits"."Id" = "IndicatorAc"."AcId"
        inner join "StateUnits" ON "StateUnits"."Id" = "AcUnits"."StateId"
        inner join "Indicator" ON "Indicator"."Id" = "IndicatorAc"."IndicatorId"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "Indicator"."Id"
        WHERE "Indicator"."Id" = indicatorid
			AND
			("IndicatorAc"."Year" = yearSh OR "IndicatorAc"."Year" = yearEnd)
            AND 
            "IndicatorDeciles"."PrevalenceDecile" = "IndicatorAc"."PrevalenceDecile"
            AND
            "IndicatorDeciles"."Year" = "IndicatorAc"."Year"
            AND
            (listregId = '' OR "AcUnits"."Id" = ANY(STRING_TO_ARRAY(listregId,',')::INTEGER[]) )
		ORDER BY "IndicatorAc"."Year" ASC;
	END;
$$;


ALTER FUNCTION public.get_ac_measurements(yearsh integer, yearend integer, indicatorid integer, listregid character varying) OWNER TO dbuser;

--
-- Name: get_ac_table_of_indicators(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_ac_table_of_indicators(yearsh integer, yearend integer, acid integer) RETURNS TABLE("CatId" integer, "CatName" text, "CatNameHi" text, "Name" text, "NameHi" text, "GoiAbv" text, "GoiAbvHi" text, "IndiaPrevalence" numeric, "StatePrevalence" numeric, "RegionPrevalence" numeric, "Change" numeric, "PrevalenceChangeCategory" integer, "IndId" integer)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        WITH DataWithDifference AS(
            SELECT i."CategoryId", c."Name" AS "CatName", c."Name_hi" AS "CatNameHi", i."Name", i."Name_hi" AS "NameHi", i."GOI_ABV", i."GOI_ABV_hi", "IndicatorId",
                    (SELECT "Prevalence"
                    FROM public."IndicatorIndia"
                    WHERE "IndicatorId" = indac."IndicatorId" AND "Year" = yearend) AS "India2021",
                    (
                        SELECT "Prevalence" FROM public."IndicatorState"
                        WHERE "StateId" = (
                            SELECT "StateId" FROM "AcUnits"
                            WHERE "Id" = acid
                            LIMIT 1
                        ) AND "IndicatorId" = indac."IndicatorId" AND "Year" = yearend
                        LIMIT 1
                    ) AS "State2021",
                    MAX(CASE WHEN "Year" = yearend THEN "Prevalence" END) AS "Prevalence2021",
                    MAX(CASE WHEN "Year" = yearend THEN "Prevalence" END) -
                    MAX(CASE WHEN "Year" = yearsh THEN "Prevalence" END) AS "Difference",
                    i."Direction"
            FROM "IndicatorAc" indac
            JOIN "Indicator" i ON "IndicatorId" = i."Id"
            JOIN "Category" c ON c."Id" = i."CategoryId"
            WHERE "AcId" = acid
            AND "Year" IN (yearsh, yearend)
            GROUP BY i."CategoryId", c."Name", c."Name_hi", i."Name", i."Name_hi", i."GOI_ABV", i."GOI_ABV_hi", "IndicatorId", "AcId", i."Direction"
        )
        , DataWithCutoffs AS (
            SELECT dd.*,
                ic."PrevalenceChangeId",
                ic."PrevalenceChangeCutoffs"
            FROM DataWithDifference dd
            JOIN "IndicatorChange" ic
            ON dd."IndicatorId" = ic."IndicatorId"
        )
        , RankedData AS (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY "IndicatorId" ORDER BY "PrevalenceChangeId") AS rn
            FROM DataWithCutoffs
            WHERE ("Direction" = 1 AND "PrevalenceChangeId" <> 0 AND "Difference" > "PrevalenceChangeCutoffs")
            OR ("Direction" = 2 AND "PrevalenceChangeId" <> 0 AND "Difference" < "PrevalenceChangeCutoffs")
        )
        , ReducedRankedData AS (
            SELECT * FROM RankedData
            WHERE rn = 1
        )
        SELECT rrd."CategoryId",
                rrd."CatName",
                rrd."CatNameHi",
                rrd."Name",
                rrd."NameHi",
                rrd."GOI_ABV",
                rrd."GOI_ABV_hi",
                round(rrd."India2021",1) AS "IndiaPrevalence",
                round(rrd."State2021",1) AS "StatePrevalence",
                round(rrd."Prevalence2021",1) AS "RegionPrevalence",
                round("Difference",1) AS "Change",
                "PrevalenceChangeId" AS "PrevalenceChangeCategory",
                rrd."IndicatorId"
        FROM ReducedRankedData rrd;
	END;
$$;


ALTER FUNCTION public.get_ac_table_of_indicators(yearsh integer, yearend integer, acid integer) OWNER TO dbuser;

--
-- Name: get_ac_top_indicators_change(integer, integer, integer, integer, boolean); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_ac_top_indicators_change(yearsh integer, yearend integer, acid integer, count integer, improvement boolean) RETURNS TABLE("Indicator" text, "IndicatorHi" text)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        SELECT i."Name", i."Name_hi"
        FROM (
            SELECT "IndicatorId","PrevalenceChangeCategory",
                (CASE
                    WHEN (SELECT "Direction" FROM "Indicator" WHERE "Id" = "IndicatorId") = 1 THEN
                       "PrevalenceChange"
                    WHEN (SELECT "Direction" FROM "Indicator" WHERE "Id" = "IndicatorId") = 2 THEN
                        -1 *  "PrevalenceChange"
                    ELSE
                        NULL
                END) AS "Difference"
            FROM "IndicatorAc"
            WHERE "AcId" = acid
            AND "Year" IN (yearsh, yearend)
        ) AS subquery
        JOIN "Indicator" i ON subquery."IndicatorId" = i."Id"
        WHERE subquery."Difference" IS NOT NULL and subquery."PrevalenceChangeCategory" is not null
        ORDER BY 
            CASE WHEN improvement THEN subquery."PrevalenceChangeCategory" ELSE NULL END ASC,
            CASE WHEN NOT improvement THEN subquery."PrevalenceChangeCategory" ELSE NULL END DESC,
            CASE WHEN improvement THEN subquery."Difference" ELSE NULL END DESC,
            CASE WHEN NOT improvement THEN subquery."Difference" ELSE NULL END ASC
        LIMIT count;
	END;
$$;


ALTER FUNCTION public.get_ac_top_indicators_change(yearsh integer, yearend integer, acid integer, count integer, improvement boolean) OWNER TO dbuser;

--
-- Name: get_accatindicators(integer, integer, integer, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_accatindicators(yearsh integer, yearend integer, xid integer, indicatorid character varying, categoryid integer, stateid integer) RETURNS TABLE("CatId" integer, "CatName" text, "CatNameHi" text, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingStrategy" integer, "Description" text, "DescriptionHi" text, "Year" integer, "Prevalence" numeric, "Headcount" integer, "PrevalenceRank" integer, "HeadcountRank" integer, "PrevalenceColor" character varying, "HeadcountColor" character varying, "Decile" integer, "ChangeColor" character varying, "Type" integer, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$

	BEGIN 
        RETURN	QUERY
		(SELECT 
                "Category"."Id" AS "CatId",
                "Category"."Name" AS "CatName",
                "Category"."Name_hi" AS "CatNameHi",
                "Indicator"."Id" AS "IndId",
                "Indicator"."Name" AS "IndName",
                "Indicator"."Name_hi" AS "IndNameHi",
                "Indicator"."Direction" AS "IndReadingStrategy",
                "Indicator"."Description",
                "Indicator"."Description_hi" AS "DescriptionHi",
				"IndicatorAc"."Year" AS "Year",
				"IndicatorAc"."Prevalence" AS "Prevalence",
				"IndicatorAc"."Headcount" AS "Headcount",
				"IndicatorAc"."AcPrevalenceRank" AS "PrevalenceRank",
				"IndicatorAc"."AcHeadcountRank" AS "HeadcountRank",
				"IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
				"IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
				"IndicatorDeciles"."PrevalenceDecile" AS "Decile",
                "IndicatorChangeAc"."ChangeHex"  AS "ChangeColor",
                0 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "Indicator" 
        INNER JOIN "Category" ON "Category"."Id" = "Indicator"."CategoryId"
		INNER JOIN "IndicatorAc" ON "IndicatorAc"."IndicatorId" = "Indicator"."Id"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "IndicatorAc"."IndicatorId"
        INNER JOIN "IndicatorChangeAc" ON "IndicatorChangeAc"."PrevalenceChangeId" = "IndicatorAc"."PrevalenceChangeCategory" and "IndicatorChangeAc"."IndicatorId" = "IndicatorAc"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE "Indicator"."CategoryId" = categoryId
			AND
			("Indicator"."Id" = ANY(STRING_TO_ARRAY(indicatorId,',')::INTEGER[]))
			AND
			("IndicatorAc"."Year" = yearSh OR "IndicatorAc"."Year" = yearEnd)
			AND
			"IndicatorAc"."AcId" = xId
            AND 
            "IndicatorDeciles"."PrevalenceDecile" = "IndicatorAc"."PrevalenceDecile"
            AND
            "IndicatorDeciles"."Year" = "IndicatorAc"."Year")

        UNION

        (SELECT 
                "Category"."Id" AS "CatId",
                "Category"."Name" AS "CatName",
                "Category"."Name_hi" AS "CatNameHi",
                "Indicator"."Id" AS "IndId",
                "Indicator"."Name" AS "IndName",
                "Indicator"."Name_hi" AS "IndNameHi",
                "Indicator"."Direction" AS "IndReadingStrategy", 
                "Indicator"."Description",
                "Indicator"."Description_hi" AS "DescriptionHi",
				"IndicatorIndia"."Year" AS "Year",
				"IndicatorIndia"."Prevalence" AS "Prevalence",
				"IndicatorIndia"."Headcount" AS "Headcount",
				NULL AS "PrevalenceRank",
				NULL AS "HeadcountRank",
				NULL AS "PrevalenceColor",
				NULL AS "HeadcountColor",
				NULL AS "Decile",
                NULL AS "ChangeColor",
                6 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "Indicator"
        INNER JOIN "Category" ON "Category"."Id" = "Indicator"."CategoryId"
		INNER JOIN "IndicatorIndia" ON "IndicatorIndia"."IndicatorId" = "Indicator"."Id"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE "Indicator"."CategoryId" = categoryId
			AND
			("Indicator"."Id" = ANY(STRING_TO_ARRAY(indicatorId,',')::INTEGER[]))
			AND
			("IndicatorIndia"."Year" = yearSh OR "IndicatorIndia"."Year" = yearEnd)
			)
        
        UNION

        (SELECT 
            "Category"."Id" AS "CatId",
            "Category"."Name" AS "CatName",
            "Category"."Name_hi" AS "CatNameHi",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "Indicator"."Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "IndicatorState"."Year" AS "Year",
            "IndicatorState"."Prevalence" AS "Prevalence",
            "IndicatorState"."Headcount" AS "Headcount",
            NULL AS "PrevalenceRank",
            NULL AS "HeadcountRank",
            NULL AS "PrevalenceColor",
            NULL AS "HeadcountColor",
            NULL AS "Decile",
            NULL AS "ChangeColor",
            1 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "Indicator" 
        INNER JOIN "Category" ON "Category"."Id" = "Indicator"."CategoryId"
		INNER JOIN "IndicatorState" ON "IndicatorState"."IndicatorId" = "Indicator"."Id"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE "Indicator"."CategoryId" = categoryId
			AND
			("Indicator"."Id" = ANY(STRING_TO_ARRAY(indicatorId,',')::INTEGER[]))
			AND
			("IndicatorState"."Year" = yearSh OR "IndicatorState"."Year" = yearEnd)
			AND
			"IndicatorState"."StateId" = stateId)
		ORDER BY "Year";
	END;
$$;


ALTER FUNCTION public.get_accatindicators(yearsh integer, yearend integer, xid integer, indicatorid character varying, categoryid integer, stateid integer) OWNER TO dbuser;

--
-- Name: get_achch(integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_achch(xid integer, lang character varying DEFAULT 'en'::character varying) RETURNS TABLE("Id" integer, "Name" text, "NameHi" text, "ParentId" integer, "ParentName" text, "ParentNameHi" text, "StateId" integer, "StateName" text, "StateNameHi" text)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "AcUnits"."Id" AS "Id",
            "AcUnits"."Name" AS "Name",
            "AcUnits"."Name_hi" AS "NameHi",
            "StateUnits"."Id" AS "ParentId",
            "StateUnits"."Name" AS "ParentName",
            "StateUnits"."Name_hi" AS "ParentNameHi",
			"StateUnits"."Id" AS "StateId",
            "StateUnits"."Name" AS "StateName",
            "StateUnits"."Name_hi" AS "StateNameHi"
        FROM "AcUnits" 
		INNER JOIN "StateUnits" ON "StateUnits"."Id" = "AcUnits"."StateId"
        WHERE "AcUnits"."Id" = xid;
	END;
$$;


ALTER FUNCTION public.get_achch(xid integer, lang character varying) OWNER TO dbuser;

--
-- Name: get_acindicators(integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_acindicators(yearsh integer, xid integer, cntregist integer, cntignored integer) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "Headcount" integer, "PrevalenceRank" integer, "HeadcountRank" integer, "HeadcountColor" character varying, "PrevalenceColor" character varying, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingstrategy" integer, "Description" text, "DescriptionHi" text, "Decile" integer)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorAc"."AcId" AS "RegionId",
            "IndicatorAc"."Year",
            "IndicatorAc"."Prevalence",
            "IndicatorAc"."Headcount",
            "IndicatorAc"."AcPrevalenceRank" AS "PrevalenceRank",
            "IndicatorAc"."AcHeadcountRank" AS "HeadcountRank",
            "IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
            "IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "Indicator"."Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "IndicatorDeciles"."PrevalenceDecile" AS "Decile"
        FROM "IndicatorAc" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorAc"."IndicatorId"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "Indicator"."Id"
        WHERE ("IndicatorAc"."Year" = yearSh OR yearSh = 0)
               AND
               ("IndicatorAc"."AcId" = xId)
        ORDER BY "IndicatorAc"."Year" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_acindicators(yearsh integer, xid integer, cntregist integer, cntignored integer) OWNER TO dbuser;

--
-- Name: get_acmeasurements_cng(integer, integer, character varying, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_acmeasurements_cng(yearsh integer, yearend integer, lstreg character varying, cntregist integer, cntignored integer, lstind character varying) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "PrevalenceChange" numeric, "ChangeId" integer, "Decile" integer, "IndId" integer, "IndName" text, "IndNameHi" text, "ChangeHex" character varying, "ChangeCutoffs" numeric, "ChangeDescription" text, "ChangeDescriptionHi" text, "India" boolean, "DeepDiveCompareColor" character varying, "Name" text, "NameHi" text, "StateName" text, "StateNameHi" text, "StateAbbreviation" character varying, "StateAbbreviationHi" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		(SELECT 
            "IndicatorAc"."AcId" AS "RegionId",
            "IndicatorAc"."Year" AS "Year",
            "IndicatorAc"."Prevalence" AS "Prevalence",
            "IndicatorAc"."PrevalenceChange" AS "PrevalenceChange",
            "IndicatorAc"."PrevalenceChangeCategory" AS "ChangeId",
            "IndicatorAc"."PrevalenceDecile"  AS "Decile",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "IndicatorChange"."ChangeHex",
            "IndicatorChange"."PrevalenceChangeCutoffs" AS "ChangeCutoffs",
            "PrevalenceChange"."Name" AS "ChangeDescription",
            "PrevalenceChange"."Name_hi" AS "ChangeDescriptionHi",
             FALSE AS "India",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor",
            "AcUnits"."Name",
            "AcUnits"."Name_hi" AS "NameHi",            
            "StateUnits"."Name" AS "StateName",
            "StateUnits"."Name_hi" AS "StateNameHi",
            "StateUnits"."Abbreviation" AS "StateAbbreviation",
            "StateUnits"."Abbreviation_hi" AS "StateAbbreviationHi"
        FROM "IndicatorAc" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorAc"."IndicatorId"
        INNER JOIN "IndicatorChange" ON "IndicatorChange"."IndicatorId" = "IndicatorAc"."IndicatorId"
        INNER JOIN "PrevalenceChange" ON "PrevalenceChange"."Id" = "IndicatorChange"."PrevalenceChangeId"
        INNER JOIN "AcUnits" on "AcUnits"."Id"="IndicatorAc"."AcId"
        INNER JOIN "StateUnits" ON "StateUnits"."Id" = "AcUnits"."StateId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorAc"."Year" = yearsh OR yearend = "IndicatorAc"."Year")
            AND
            ("IndicatorAc"."AcId" = ANY(STRING_TO_ARRAY(lstreg,',')::INTEGER[]))
            AND
            ("IndicatorAc"."IndicatorId" = ANY(STRING_TO_ARRAY(lstind,',')::INTEGER[]))
            AND
            "IndicatorChange"."PrevalenceChangeId" = "IndicatorAc"."PrevalenceChangeCategory"

        ORDER BY "IndicatorAc"."Year" LIMIT cntregist OFFSET cntignored)

        UNION

        (SELECT 
            0 AS "RegionId",
            "IndicatorIndia"."Year" AS "Year",
            "IndicatorIndia"."Prevalence" AS "Prevalence",
            "IndicatorIndia"."PrevalenceChange" AS "PrevalenceChange",
            0 AS "ChangeId",
            0 AS "Decile",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            NULL AS "ChangeHex",
            NULL AS "ChangeCutoffs",
            NULL AS "ChangeDescription",
            NULL AS "ChangeDescriptionHi",
            TRUE AS "India",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor",
            NULL AS "Name",
            NULL AS "NameHi",            
            NULL AS "StateName",
            NULL AS "StateNameHi",
            NULL AS "StateAbbreviation",
            NULL AS "StateAbbreviationHi"
        FROM "IndicatorIndia" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorIndia"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorIndia"."Year" = yearsh OR "IndicatorIndia"."Year" = yearend)
            AND
            ("IndicatorIndia"."IndicatorId" = ANY(STRING_TO_ARRAY(lstind,',')::INTEGER[]))

        ORDER BY "IndicatorIndia"."Year");
	END;
$$;


ALTER FUNCTION public.get_acmeasurements_cng(yearsh integer, yearend integer, lstreg character varying, cntregist integer, cntignored integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_acmeasurements_ind(integer, integer, integer, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_acmeasurements_ind(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "Headcount" integer, "PrevalenceChange" numeric, "PrevalenceRank" integer, "HeadcountRank" integer, "IndId" integer, "IndName" text, "IndNameHi" text, "Description" text, "DescriptionHi" text, "IndReadingstrategy" integer, "PrevalenceColor" character varying, "HeadcountColor" character varying, "Decile" integer, "PrevalenceCutoff" numeric, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorAc"."AcId" AS "RegionId",
            "IndicatorAc"."Year" AS "Year",
            "IndicatorAc"."Prevalence" AS "Prevalence",
            "IndicatorAc"."Headcount" AS "Headcount",
            "IndicatorAc"."PrevalenceChange" AS "PrevalenceChange",
            "IndicatorAc"."AcPrevalenceRank" AS "PrevalenceRank",
            "IndicatorAc"."AcHeadcountRank" AS "HeadcountRank",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
            "IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
            "IndicatorDeciles"."PrevalenceDecile" AS "Decile", 
            "IndicatorDeciles"."PrevalenceDecileCutoffs" AS "PrevalenceCutoff",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorAc" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorAc"."IndicatorId"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "IndicatorAc"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorAc"."Year" = yearSh OR yearEnd = "IndicatorAc"."Year")
            AND
            ("IndicatorAc"."AcId" = xId)
            AND
            ("IndicatorAc"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
            AND 
            "IndicatorDeciles"."PrevalenceDecile" = "IndicatorAc"."PrevalenceDecile"
            AND
            "IndicatorDeciles"."Year" = "IndicatorAc"."Year"
        ORDER BY "IndicatorAc"."Year" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_acmeasurements_ind(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_acunits(integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_acunits(acid integer, parid integer, cntregist integer, cntignored integer) RETURNS TABLE("Id" integer, "GeoId" character varying, "Name" text, "NameHi" text, "Abbreviation" character varying, "AbbreviationHi" character varying, "SubId" integer, "SubGeoId" character varying, "SubName" text, "SubNameHi" text, "SubParentId" integer)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT
            "StateUnits"."Id" AS "Id",
            "StateUnits"."GeoId" AS "GeoId",
            "StateUnits"."Name" AS "Name",
            "StateUnits"."Name_hi" AS "NameHi",
            "StateUnits"."Abbreviation" AS "Abbreviation", 
            "StateUnits"."Abbreviation_hi" AS "AbbreviationHi", 
            "AcUnits"."Id" AS "SubId",
            "AcUnits"."GeoId" AS "SubGeoId",
            "AcUnits"."Name" AS "SubName",
            "AcUnits"."Name_hi" AS "SubNameHi",
            "AcUnits"."StateId" AS "SubParentId"
        FROM "AcUnits" 
        INNER JOIN "StateUnits" ON "StateUnits"."Id" = "AcUnits"."StateId"
        WHERE ("AcUnits"."Id" = acId OR acId = 0)
               AND
               ("StateUnits"."Id" = parId OR parId = 0)
        ORDER BY "StateUnits"."Id" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_acunits(acid integer, parid integer, cntregist integer, cntignored integer) OWNER TO dbuser;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: Categories; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."Categories" (
    "Name" character varying NOT NULL,
    id smallint NOT NULL,
    "ParentId" smallint
);


ALTER TABLE public."Categories" OWNER TO dbuser;

--
-- Name: get_categories(integer, integer, text); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_categories(cntregist integer, cntignored integer, schname text) RETURNS SETOF public."Categories"
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT * FROM public."Categories" WHERE "Name" LIKE '%' || schName || '%' ORDER BY Id LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_categories(cntregist integer, cntignored integer, schname text) OWNER TO dbuser;

--
-- Name: get_census(); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_census() RETURNS TABLE("Region" character varying, "Population" integer, "Density" integer, "SexRatio" integer, "Urban" numeric)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY 
		SELECT 
            "Census"."Division" AS "Region",
            "Census"."TotalPopulation" AS "Population",
            "Census"."Density",
            "Census"."SexRatio",
            "Census"."Urban"
        FROM "Census";
	END;
$$;


ALTER FUNCTION public.get_census() OWNER TO dbuser;

--
-- Name: GlobalConfig; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."GlobalConfig" (
    "Name" character varying(200) NOT NULL,
    "Value" character varying(200) NOT NULL
);


ALTER TABLE public."GlobalConfig" OWNER TO dbuser;

--
-- Name: get_configelement(character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_configelement(keyname character varying) RETURNS SETOF public."GlobalConfig"
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT *
        FROM "GlobalConfig" 
        WHERE "GlobalConfig"."Name" = keyName;
	END;
$$;


ALTER FUNCTION public.get_configelement(keyname character varying) OWNER TO dbuser;

--
-- Name: get_district_filter(character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_district_filter(xfilter character varying, cntregist integer, cntignored integer) RETURNS TABLE("Id" integer, "GeoId" character varying, "Name" text, "NameHi" text, "ParentId" integer, "SubId" integer, "SubGeoId" character varying, "SubName" text, "SubNameHi" text, "SubParentId" smallint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT
            "DistrictUnits"."Id" AS "Id",
            "DistrictUnits"."GeoId" AS "GeoId",
            "DistrictUnits"."Name" AS "Name",
            "DistrictUnits"."Name_hi" AS "NameHi", 
            "DistrictUnits"."StateId" as "ParentId",
            "VillageUnits"."Id" AS "SubId",
            "VillageUnits"."GeoId" AS "SubGeoId",
            "VillageUnits"."Name" AS "SubName",
            "VillageUnits"."Name_hi" AS "SubNameHi",
            "VillageUnits"."DistrictId" AS "SubParentId"
        FROM "DistrictUnits" 
        INNER JOIN "VillageUnits" ON "VillageUnits"."DistrictId" = "DistrictUnits"."Id"
        WHERE
            (lower("DistrictUnits"."Name") LIKE '%'|| lower(xfilter) ||'%')
        ORDER BY "DistrictUnits"."Id","VillageUnits"."Id"
        LIMIT cntregist OFFSET cntignored;
	END;
$$;


ALTER FUNCTION public.get_district_filter(xfilter character varying, cntregist integer, cntignored integer) OWNER TO dbuser;

--
-- Name: get_district_improvement_ranking(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_district_improvement_ranking(yearsh integer, yearend integer, disid integer) RETURNS TABLE("Ranking" bigint, "SharedBy" bigint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        WITH DistrictRanking AS (
            SELECT du."Id" AS "DistrictId",
                (
                    SELECT COUNT(*)
                    FROM "IndicatorDistrict" indd
                    WHERE indd."Year" = yearend
                        AND indd."DistrictId" = du."Id"
                        AND indd."Prevalence" >
                            CASE 
                                WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indd."IndicatorId") = 1 THEN
                                    (
                                        SELECT indd2."Prevalence"
                                        FROM "IndicatorDistrict" indd2
                                        WHERE indd2."Year" = yearsh
                                            AND indd2."IndicatorId" = indd."IndicatorId"
                                            AND indd2."DistrictId" = du."Id"
                                        LIMIT 1
                                    )
                                WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indd."IndicatorId") = 2 THEN
                                    -1 * (
                                        SELECT indd2."Prevalence"
                                        FROM "IndicatorDistrict" indd2
                                        WHERE indd2."Year" = yearsh
                                            AND indd2."IndicatorId" = indd."IndicatorId"
                                            AND indd2."DistrictId" = du."Id"
                                        LIMIT 1
                                    )
                                ELSE
                                    NULL
                            END
                ) AS "ImprovedIndicatorsCount"
            FROM "DistrictUnits" du
        )
        , RankedDistricts AS (
            SELECT "DistrictId", "ImprovedIndicatorsCount",
                RANK() OVER (ORDER BY "ImprovedIndicatorsCount" DESC) AS "Rank"
            FROM DistrictRanking
        )
        , RankedDistrictsCount AS (
            SELECT "DistrictId", "ImprovedIndicatorsCount", "Rank",
                COUNT(*) OVER (PARTITION BY "Rank") AS "DistrictsWithSameRank"
            FROM RankedDistricts
        )
        SELECT "Rank", "DistrictsWithSameRank"
        FROM RankedDistrictsCount
        WHERE "DistrictId" = disid;
	END;
$$;


ALTER FUNCTION public.get_district_improvement_ranking(yearsh integer, yearend integer, disid integer) OWNER TO dbuser;

--
-- Name: get_district_indicators_amount_per_change(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_district_indicators_amount_per_change(yearsh integer, yearend integer, disid integer) RETURNS TABLE("PrevalenceChangeCategory" integer, "IndicatorCount" bigint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        WITH DataWithDifference AS (
            SELECT "IndicatorId", "DistrictId",
                MAX(CASE WHEN "Year" = yearend THEN "Prevalence" END) -
                MAX(CASE WHEN "Year" = yearsh THEN "Prevalence" END) AS "Difference"
            FROM "IndicatorDistrict"
            WHERE "DistrictId" = disid
            AND "Year" IN (yearsh, yearend)
            GROUP BY "IndicatorId", "DistrictId"
        )
        , DataWithCutoffs AS (
            SELECT dd.*,
                ic."PrevalenceChangeId",
                ic."PrevalenceChangeCutoffs"
            FROM DataWithDifference dd
            JOIN "IndicatorChange" ic
            ON dd."IndicatorId" = ic."IndicatorId"
        )
        , DataWithDirection AS (
            SELECT "IndicatorId", "DistrictId", "Difference", "PrevalenceChangeId", "PrevalenceChangeCutoffs", i."Direction"
            FROM DataWithCutoffs
            JOIN "Indicator" i
            ON "IndicatorId" = i."Id"
        )
        , RankedData AS (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY "IndicatorId" ORDER BY "PrevalenceChangeId") AS rn
            FROM DataWithDirection
            WHERE ("Direction" = 1 AND "PrevalenceChangeId" <> 0 AND "Difference" > "PrevalenceChangeCutoffs")
            OR ("Direction" = 2 AND "PrevalenceChangeId" <> 0 AND "Difference" < "PrevalenceChangeCutoffs")
        )
        , ReducedRankedData AS (
            SELECT * FROM RankedData
            WHERE rn = 1
        )
        , PrevalenceChangeCounts AS (
            SELECT "PrevalenceChangeId", COUNT(*) AS "RowCount"
            FROM ReducedRankedData
            GROUP BY "PrevalenceChangeId"
        )
        SELECT gs."PrevalenceChangeId" AS "PrevalenceChangeCategory", COALESCE(pcc."RowCount", 0) AS "IndicatorCount"
        FROM generate_series(1, 4) AS gs("PrevalenceChangeId")
        LEFT JOIN PrevalenceChangeCounts pcc
        ON gs."PrevalenceChangeId" = pcc."PrevalenceChangeId"
        ORDER BY gs."PrevalenceChangeId";
	END;
$$;


ALTER FUNCTION public.get_district_indicators_amount_per_change(yearsh integer, yearend integer, disid integer) OWNER TO dbuser;

--
-- Name: get_district_indicators_better_than_all_india(integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_district_indicators_better_than_all_india(yearsh integer, disid integer) RETURNS TABLE("BetterThanAverage" bigint, "TotalIndicators" bigint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        SELECT 
            COUNT(*) AS "BetterThanAverage",
            (SELECT COUNT(*) FROM public."Indicator" WHERE "Description" IS NOT NULL) AS "TotalIndicators"
        FROM public."IndicatorDistrict" indd
        WHERE "Year" = yearsh AND "DistrictId" = disid
        AND CASE 
            WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indd."IndicatorId") = 1 THEN
                "Prevalence"  >= (SELECT "Prevalence" FROM public."IndicatorIndia" WHERE "IndicatorId" = indd."IndicatorId" AND "Year" = yearsh)
            WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indd."IndicatorId") = 2 THEN
                "Prevalence"  <= (SELECT "Prevalence" FROM public."IndicatorIndia" WHERE "IndicatorId" = indd."IndicatorId" AND "Year" = yearsh)
            ELSE
                NULL
        END;
	END;
$$;


ALTER FUNCTION public.get_district_indicators_better_than_all_india(yearsh integer, disid integer) OWNER TO dbuser;

--
-- Name: get_district_indicators_better_than_state(integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_district_indicators_better_than_state(yearsh integer, disid integer) RETURNS TABLE("BetterThanAverage" bigint, "TotalIndicators" bigint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        SELECT 
            COUNT(*) AS "BetterThanAverage",
            (SELECT COUNT(*) FROM public."Indicator" WHERE "Description" IS NOT NULL) AS "TotalIndicators"
        FROM public."IndicatorDistrict" indd
        WHERE "Year" = yearsh AND "DistrictId" = disid
        AND CASE 
                WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indd."IndicatorId") = 1 THEN
                    "Prevalence"  >=  (
                        SELECT "Prevalence" FROM public."IndicatorState"
                        WHERE "StateId" = (
                            SELECT "StateId" FROM "DistrictUnits" du
                            WHERE du."Id" = disid
                            LIMIT 1
                        ) AND "IndicatorId" = indd."IndicatorId" AND "Year" = yearsh
                        LIMIT 1
                    )
                WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indd."IndicatorId") = 2 THEN
                    "Prevalence"  <= (
                        SELECT "Prevalence" FROM public."IndicatorState"
                        WHERE "StateId" = (
                            SELECT "StateId" FROM "DistrictUnits" du
                            WHERE du."Id" = disid
                            LIMIT 1
                        ) AND "IndicatorId" = indd."IndicatorId" AND "Year" = yearsh
                        LIMIT 1
                    )
                ELSE
                    NULL
            END;
	END;
$$;


ALTER FUNCTION public.get_district_indicators_better_than_state(yearsh integer, disid integer) OWNER TO dbuser;

--
-- Name: get_district_metrics(integer, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_district_metrics(yearsh integer, yearend integer, indicatorid integer, listregid character varying) RETURNS TABLE("IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingStrategy" integer, "Description" text, "DescriptionHi" text, "Id" integer, "GeoId" character varying, "Name" text, "NameHi" text, "StateName" text, "StateNameHi" text, "StateAbbreviation" character varying, "StateAbbreviationHi" character varying, "Year" integer, "Prevalence" numeric, "Headcount" numeric, "HeadcountRank" integer, "PrevalenceRank" integer, "PrevalenceChange" numeric, "PrevalenceChangeRank" integer, "PrevalenceColor" character varying, "HeadcountColor" character varying, "PrevalenceDecile" integer, "HeadcountDecile" integer)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "Indicator"."Description" AS "Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "DistrictUnits"."Id" AS "Id",
            "DistrictUnits"."GeoId" AS "GeoId",
            "DistrictUnits"."Name" AS "Name",
            "DistrictUnits"."Name_hi" AS "NameHi",
            "StateUnits"."Name" AS "StateName",
            "StateUnits"."Name_hi" AS "StateNameHi",
            "StateUnits"."Abbreviation" AS "StateAbbreviation",
            "StateUnits"."Abbreviation_hi" AS "StateAbbreviationHi",
            "IndicatorDistrict"."Year" AS "Year",
            "IndicatorDistrict"."Prevalence" AS "Prevalence",
            "IndicatorDistrict"."Headcount" AS "Headcount",
            "IndicatorDistrict"."HeadcountRank",
            "IndicatorDistrict"."PrevalenceRank",
            "IndicatorDistrict"."PrevalenceChange",
            "IndicatorDistrict"."PrevalenceChangeRank",
            prevDecile."PrevalenceDecileHex" AS "PrevalenceColor",
            headDecile."HeadcountDecileHex" AS "HeadcountColor",
            prevDecile."PrevalenceDecile" ,
            headDecile."HeadcountDecile"
        FROM "IndicatorDistrict" 
        left join "DistrictUnits" ON "DistrictUnits"."Id" = "IndicatorDistrict"."DistrictId"
        inner join "StateUnits" ON "StateUnits"."Id" = "DistrictUnits"."StateId"
        inner join "Indicator" ON "Indicator"."Id" = "IndicatorDistrict"."IndicatorId"
        INNER JOIN "IndicatorDeciles" prevDecile ON prevDecile."IndicatorId" = "Indicator"."Id" AND prevDecile."PrevalenceDecile" = "IndicatorDistrict" ."PrevalenceDecile"
            and prevDecile."Year" = "IndicatorDistrict" ."Year" 
        INNER JOIN "IndicatorDeciles" headDecile ON headDecile."IndicatorId" = "Indicator"."Id" AND headDecile."HeadcountDecile" = "IndicatorDistrict" ."HeadcountDecile"
            AND headDecile."Year" = "IndicatorDistrict" ."Year"
        WHERE "Indicator"."Id" = indicatorid
        AND
        ("IndicatorDistrict"."Year" = yearSh OR "IndicatorDistrict"."Year" = yearEnd)
        AND
        ("DistrictUnits"."Id" = ANY(STRING_TO_ARRAY(listregId,',')::INTEGER[]) OR listregId = '')
        ORDER BY "IndicatorDistrict"."Year" ASC;
	END;
$$;


ALTER FUNCTION public.get_district_metrics(yearsh integer, yearend integer, indicatorid integer, listregid character varying) OWNER TO dbuser;

--
-- Name: get_district_table_of_indicators(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_district_table_of_indicators(yearsh integer, yearend integer, disid integer) RETURNS TABLE("CatId" integer, "CatName" text, "CatNameHi" text, "Name" text, "NameHi" text, "GoiAbv" text, "GoiAbvHi" text, "IndiaPrevalence" numeric, "StatePrevalence" numeric, "RegionPrevalence" numeric, "Change" numeric, "PrevalenceChangeCategory" integer, "IndId" integer)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        WITH DataWithDifference AS(
            SELECT i."CategoryId", c."Name" AS "CatName", c."Name_hi" AS "CatNameHi", i."Name", i."Name_hi" AS "NameHi", i."GOI_ABV", i."GOI_ABV_hi", "IndicatorId",
                    (SELECT "Prevalence"
                    FROM public."IndicatorIndia"
                    WHERE "IndicatorId" = indd."IndicatorId" AND "Year" = yearend) AS "India2021",
                    (
                        SELECT "Prevalence" FROM public."IndicatorState"
                        WHERE "StateId" = (
                            SELECT "StateId" FROM "DistrictUnits"
                            WHERE "Id" = disid
                            LIMIT 1
                        ) AND "IndicatorId" = indd."IndicatorId" AND "Year" = yearend
                        LIMIT 1
                    ) AS "State2021",
                    MAX(CASE WHEN "Year" = yearend THEN "Prevalence" END) AS "Prevalence2021",
                    MAX(CASE WHEN "Year" = yearend THEN "Prevalence" END) -
                    MAX(CASE WHEN "Year" = yearsh THEN "Prevalence" END) AS "Difference",
                    i."Direction"
            FROM "IndicatorDistrict" indd
            JOIN "Indicator" i ON "IndicatorId" = i."Id"
            JOIN "Category" c ON c."Id" = i."CategoryId"
            WHERE "DistrictId" = disid
            AND "Year" IN (yearsh, yearend)
            GROUP BY i."CategoryId", c."Name", c."Name_hi", i."Name", i."Name_hi", i."GOI_ABV", i."GOI_ABV_hi", "IndicatorId", "DistrictId", i."Direction"
        )
        , DataWithCutoffs AS (
            SELECT dd.*,
                ic."PrevalenceChangeId",
                ic."PrevalenceChangeCutoffs"
            FROM DataWithDifference dd
            JOIN "IndicatorChange" ic
            ON dd."IndicatorId" = ic."IndicatorId"
        )
        , RankedData AS (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY "IndicatorId" ORDER BY "PrevalenceChangeId") AS rn
            FROM DataWithCutoffs
            WHERE ("Direction" = 1 AND "PrevalenceChangeId" <> 0 AND "Difference" > "PrevalenceChangeCutoffs")
            OR ("Direction" = 2 AND "PrevalenceChangeId" <> 0 AND "Difference" < "PrevalenceChangeCutoffs")
        )
        , ReducedRankedData AS (
            SELECT * FROM RankedData
            WHERE rn = 1
        )
        SELECT rrd."CategoryId",
                rrd."CatName",
                rrd."CatNameHi",
                rrd."Name",
                rrd."NameHi",
                rrd."GOI_ABV",
                rrd."GOI_ABV_hi",
                round(rrd."India2021",1) AS "IndiaPrevalence",
                round(rrd."State2021",1) AS "StatePrevalence",
                round(rrd."Prevalence2021",1) AS "RegionPrevalence",
                round("Difference",1) AS "Change",
                "PrevalenceChangeId" AS "PrevalenceChangeCategory",
                rrd."IndicatorId"
        FROM ReducedRankedData rrd;
	END;
$$;


ALTER FUNCTION public.get_district_table_of_indicators(yearsh integer, yearend integer, disid integer) OWNER TO dbuser;

--
-- Name: get_district_top_indicators_change(integer, integer, integer, integer, boolean); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_district_top_indicators_change(yearsh integer, yearend integer, disid integer, count integer, improvement boolean) RETURNS TABLE("Indicator" text, "IndicatorHi" text)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        SELECT i."Name", i."Name_hi"
        FROM (
            SELECT "IndicatorId","PrevalenceChangeCategory",
                (CASE
                    WHEN (SELECT "Direction" FROM "Indicator" WHERE "Id" = "IndicatorId") = 1 THEN
                       "PrevalenceChange"
                    WHEN (SELECT "Direction" FROM "Indicator" WHERE "Id" = "IndicatorId") = 2 THEN
                        -1 *  "PrevalenceChange"
                    ELSE
                        NULL
                END) AS "Difference"
            FROM "IndicatorDistrict"
            WHERE "DistrictId" = disid
            AND "Year" = yearend
        ) AS subquery
        JOIN "Indicator" i ON subquery."IndicatorId" = i."Id"
        WHERE subquery."Difference" IS NOT NULL and subquery."PrevalenceChangeCategory" is not null
        ORDER BY 
            CASE WHEN improvement THEN subquery."PrevalenceChangeCategory" ELSE NULL END ASC,
            CASE WHEN NOT improvement THEN subquery."PrevalenceChangeCategory" ELSE NULL END DESC,
            CASE WHEN improvement THEN subquery."Difference" ELSE NULL END DESC,
            CASE WHEN NOT improvement THEN subquery."Difference" ELSE NULL END ASC
        LIMIT count;
	END;
$$;


ALTER FUNCTION public.get_district_top_indicators_change(yearsh integer, yearend integer, disid integer, count integer, improvement boolean) OWNER TO dbuser;

--
-- Name: get_districtcatindicators(integer, integer, integer, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_districtcatindicators(yearsh integer, yearend integer, xid integer, indicatorid character varying, categoryid integer, stateid integer) RETURNS TABLE("CatId" integer, "CatName" text, "CatNameHi" text, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingStrategy" integer, "Description" text, "DescriptionHi" text, "Year" integer, "Prevalence" numeric, "Headcount" integer, "PrevalenceRank" integer, "HeadcountRank" integer, "PrevalenceColor" character varying, "HeadcountColor" character varying, "Decile" integer, "ChangeColor" character varying, "Type" integer, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$

	BEGIN 
        RETURN	QUERY
		(SELECT 
                "Category"."Id" AS "CatId",
                "Category"."Name" AS "CatName",
                "Category"."Name_hi" AS "CatNameHi",
                "Indicator"."Id" AS "IndId",
                "Indicator"."Name" AS "IndName",
                "Indicator"."Name_hi" AS "IndNameHi",
                "Indicator"."Direction" AS "IndReadingStrategy",
                "Indicator"."Description",
                "Indicator"."Description_hi" AS "DescriptionHi",
				"IndicatorDistrict"."Year" AS "Year",
				"IndicatorDistrict"."Prevalence",
				"IndicatorDistrict"."Headcount",
				"IndicatorDistrict"."PrevalenceRank",
				"IndicatorDistrict"."HeadcountRank",
				"IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
				"IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
				"IndicatorDeciles"."PrevalenceDecile" AS "Decile",
                "IndicatorChange"."ChangeHex" AS "ChangeColor",
                0 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "Indicator" 
        INNER JOIN "Category" ON "Category"."Id" = "Indicator"."CategoryId"
		INNER JOIN "IndicatorDistrict" ON "IndicatorDistrict"."IndicatorId" = "Indicator"."Id"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "IndicatorDistrict"."IndicatorId"
        LEFT JOIN "IndicatorChange" ON "IndicatorChange"."PrevalenceChangeId" = "IndicatorDistrict"."PrevalenceChangeCategory" and "IndicatorChange"."IndicatorId" = "IndicatorDistrict"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE "Indicator"."CategoryId" = categoryId
			AND
			("Indicator"."Id" = ANY(STRING_TO_ARRAY(indicatorId,',')::INTEGER[]))
			AND
			("IndicatorDistrict"."Year" = yearSh OR "IndicatorDistrict"."Year" = yearEnd)
			AND
			"IndicatorDistrict"."DistrictId" = xId
            AND 
            "IndicatorDeciles"."PrevalenceDecile" = "IndicatorDistrict"."PrevalenceDecile"
            AND
            "IndicatorDeciles"."Year" = "IndicatorDistrict"."Year")

        UNION

        (SELECT 
                "Category"."Id" AS "CatId",
                "Category"."Name" AS "CatName",
                "Category"."Name_hi" AS "CatNameHi",
                "Indicator"."Id" AS "IndId",
                "Indicator"."Name" AS "IndName",
                "Indicator"."Name_hi" AS "IndNameHi",
                "Indicator"."Direction" AS "IndReadingStrategy", 
                "Indicator"."Description", 
                "Indicator"."Description_hi" AS "DescriptionHi",
				"IndicatorIndia"."Year" AS "Year",
				"IndicatorIndia"."Prevalence",
				"IndicatorIndia"."Headcount",
				NULL AS "PrevalenceRank",
				NULL AS "HeadcountRank",
				NULL AS "PrevalenceColor",
				NULL AS "HeadcountColor",
				NULL AS "Decile",
                NULL AS "ChangeColor",
                6 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "Indicator"
        INNER JOIN "Category" ON "Category"."Id" = "Indicator"."CategoryId"
		INNER JOIN "IndicatorIndia" ON "IndicatorIndia"."IndicatorId" = "Indicator"."Id"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE "Indicator"."CategoryId" = categoryId
			AND
			("Indicator"."Id" = ANY(STRING_TO_ARRAY(indicatorId,',')::INTEGER[]))
			AND
			("IndicatorIndia"."Year" = yearSh OR "IndicatorIndia"."Year" = yearEnd))
        
        UNION

        (SELECT 
            "Category"."Id" AS "CatId",
            "Category"."Name" AS "CatName",
            "Category"."Name_hi" AS "CatNameHi",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "Indicator"."Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "IndicatorState"."Year" AS "Year",
            "IndicatorState"."Prevalence",
            "IndicatorState"."Headcount",
            NULL AS "PrevalenceRank",
            NULL AS "HeadcountRank",
            NULL AS "PrevalenceColor",
            NULL AS "HeadcountColor",
            NULL AS "Decile",
            NULL AS "ChangeColor",
            1 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "Indicator" 
        INNER JOIN "Category" ON "Category"."Id" = "Indicator"."CategoryId"
		INNER JOIN "IndicatorState" ON "IndicatorState"."IndicatorId" = "Indicator"."Id"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE "Indicator"."CategoryId" = categoryId
			AND
			("Indicator"."Id" = ANY(STRING_TO_ARRAY(indicatorId,',')::INTEGER[]))
			AND
			("IndicatorState"."Year" = yearSh OR "IndicatorState"."Year" = yearEnd)
			AND
			"IndicatorState"."StateId" = stateId)
			ORDER BY "Year";
	END;
$$;


ALTER FUNCTION public.get_districtcatindicators(yearsh integer, yearend integer, xid integer, indicatorid character varying, categoryid integer, stateid integer) OWNER TO dbuser;

--
-- Name: get_districthch(integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_districthch(xid integer) RETURNS TABLE("Id" integer, "Name" text, "NameHi" text, "ParentId" integer, "ParentName" text, "ParentNameHi" text, "StateId" integer, "StateName" text, "StateNameHi" text)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "DistrictUnits"."Id" AS "Id",
            "DistrictUnits"."Name" AS "Name",
            "DistrictUnits"."Name_hi" AS "NameHi",
			"StateUnits"."Id" AS "ParentId",
            "StateUnits"."Name" AS "ParentName",
            "StateUnits"."Name_hi" AS "ParentNameHi",
			"StateUnits"."Id" AS "StateId",
            "StateUnits"."Name" AS "StateName",
            "StateUnits"."Name_hi" AS "StateNameHi"
        FROM "DistrictUnits" 
		INNER JOIN "StateUnits" ON "StateUnits"."Id" = "DistrictUnits"."StateId"
        WHERE "DistrictUnits"."Id" = xid;
	END;
$$;


ALTER FUNCTION public.get_districthch(xid integer) OWNER TO dbuser;

--
-- Name: get_districtindicators(integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_districtindicators(yearsh integer, xid integer, cntregist integer, cntignored integer) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "Headcount" integer, "PrevalenceRank" integer, "HeadcountRank" integer, "HeadcountColor" character varying, "PrevalenceColor" character varying, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingstrategy" integer, "Description" text, "DescriptionHi" text, "Decile" integer)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorDistrict"."DistrictId" AS "RegionId",
            "IndicatorDistrict"."Year",
            "IndicatorDistrict"."Prevalence",
            "IndicatorDistrict"."Headcount",
            "IndicatorDistrict"."PrevalenceRank",
            "IndicatorDistrict"."HeadcountRank",
            "IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
            "IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "Indicator"."Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "IndicatorDeciles"."PrevalenceDecile" AS "Decile"
        FROM "IndicatorDistrict" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorDistrict"."IndicatorId"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "Indicator"."Id"
        WHERE ("IndicatorDistrict"."Year" = yearSh OR yearSh = 0)
               AND
               ("IndicatorDistrict"."DistrictId" = xId)
               
        ORDER BY "IndicatorDistrict"."Year" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_districtindicators(yearsh integer, xid integer, cntregist integer, cntignored integer) OWNER TO dbuser;

--
-- Name: get_districtmeasurements_ind(integer, integer, integer, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_districtmeasurements_ind(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "Headcount" integer, "PrevalenceRank" integer, "HeadcountRank" integer, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingstrategy" integer, "Description" text, "DescriptionHi" text, "PrevalenceColor" character varying, "HeadcountColor" character varying, "Decile" integer, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorDistrict"."DistrictId" AS "RegionId",
            "IndicatorDistrict"."Year" AS "Year",
            "IndicatorDistrict"."Prevalence",
            "IndicatorDistrict"."Headcount",
            "IndicatorDistrict"."PrevalenceRank",
            "IndicatorDistrict"."HeadcountRank",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "Indicator"."Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
            "IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
            "IndicatorDeciles"."PrevalenceDecile" AS "Decile",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorDistrict" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorDistrict"."IndicatorId"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "IndicatorDistrict"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorDistrict"."Year" = yearSh OR yearEnd = "IndicatorDistrict"."Year")
            AND
            ("IndicatorDistrict"."DistrictId" = xId)
            AND
            ("IndicatorDistrict"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
            AND 
            "IndicatorDeciles"."PrevalenceDecile" = "IndicatorDistrict"."PrevalenceDecile"
            AND
            "IndicatorDeciles"."Year" = "IndicatorDistrict"."Year"
        ORDER BY "IndicatorDistrict"."Year" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_districtmeasurements_ind(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_districts_cng(integer, integer, character varying, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_districts_cng(yearsh integer, yearend integer, lstreg character varying, cntregist integer, cntignored integer, lstind character varying) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "PrevalenceChange" numeric, "ChangeId" integer, "Decile" integer, "IndId" integer, "IndName" text, "IndNameHi" text, "ChangeHex" character varying, "ChangeCutoffs" numeric, "ChangeDescription" text, "ChangeDescriptionHi" text, "India" boolean, "DeepDiveCompareColor" character varying, "GeoId" character varying, "Name" text, "NameHi" text, "StateName" text, "StateNameHi" text, "StateAbbreviation" character varying, "StateAbbreviationHi" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		(SELECT 
            "IndicatorDistrict"."DistrictId" AS "RegionId",
            "IndicatorDistrict"."Year" AS "Year",
            "IndicatorDistrict"."Prevalence" AS "Prevalence",
            "IndicatorDistrict"."PrevalenceChange" AS "PrevalenceChange",
            "IndicatorDistrict"."PrevalenceChangeCategory" AS "ChangeId",
            "IndicatorDistrict"."PrevalenceDecile"  AS "Decile",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "IndicatorChange"."ChangeHex",
            "IndicatorChange"."PrevalenceChangeCutoffs" AS "ChangeCutoffs",
            "PrevalenceChange"."Name" AS "ChangeDescription",
            "PrevalenceChange"."Name_hi" AS "ChangeDescriptionHi",
             FALSE AS "India",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor",
            "DistrictUnits"."GeoId" AS "GeoId",
            "DistrictUnits"."Name" AS "Name",
            "DistrictUnits"."Name_hi" AS "NameHi",
            "StateUnits"."Name" AS "StateName",
            "StateUnits"."Name_hi" AS "StateNameHi",
            "StateUnits"."Abbreviation" AS "StateAbbreviation",            
            "StateUnits"."Abbreviation_hi" AS "StateAbbreviationHi"
        FROM "IndicatorDistrict" 
        inner join "DistrictUnits" ON "DistrictUnits"."Id" = "IndicatorDistrict"."DistrictId"
        inner join "StateUnits" ON "StateUnits"."Id" = "DistrictUnits"."StateId"
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorDistrict"."IndicatorId"
        INNER JOIN "IndicatorChange" ON "IndicatorChange"."IndicatorId" = "IndicatorDistrict"."IndicatorId"
        INNER JOIN "PrevalenceChange" ON "PrevalenceChange"."Id" = "IndicatorChange"."PrevalenceChangeId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorDistrict"."Year" = yearSh OR yearEnd = "IndicatorDistrict"."Year")
            AND
            ("IndicatorDistrict"."DistrictId" = ANY(STRING_TO_ARRAY(lstReg,',')::INTEGER[]))
            AND
            ("IndicatorDistrict"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
            AND
            "IndicatorChange"."PrevalenceChangeId" = "IndicatorDistrict"."PrevalenceChangeCategory"

        ORDER BY "IndicatorDistrict"."Year" LIMIT cntRegist OFFSET cntIgnored)

        UNION

        (SELECT 
            0 AS "RegionId",
            "IndicatorIndia"."Year" AS "Year",
            "IndicatorIndia"."Prevalence" AS "Prevalence",
            "IndicatorIndia"."PrevalenceChange" AS "PrevalenceChange",
            0 AS "ChangeId",
            0 AS "Decile",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            NULL AS "ChangeHex",
            NULL AS "ChangeCutoffs",
            NULL AS "ChangeDescription",
            NULL AS "ChangeDescriptionHi",
            TRUE AS "India",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor",
            NULL AS "GeoId",
            NULL AS "Name",
            NULL AS "NameHi",
            NULL AS "StateName",
            NULL AS "StateNameHi",
            NULL AS "StateAbbreviation",            
            NULL AS "StateAbbreviationHi"
        FROM "IndicatorIndia" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorIndia"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorIndia"."Year" = yearsh OR "IndicatorIndia"."Year" = yearend)
            AND
            ("IndicatorIndia"."IndicatorId" = ANY(STRING_TO_ARRAY(lstind,',')::INTEGER[]))

        ORDER BY "IndicatorIndia"."Year");
	END;
$$;


ALTER FUNCTION public.get_districts_cng(yearsh integer, yearend integer, lstreg character varying, cntregist integer, cntignored integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_districtsvillages(character varying, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_districtsvillages(xfilter character varying, cntregist integer) RETURNS TABLE("Id" integer, "GeoId" character varying, "Name" text, "ParentId" integer, "SubId" integer, "SubGeoId" character varying, "SubName" text, "SubParentId" smallint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
        SELECT
            "DistrictUnits"."Id" AS "Id",
            "DistrictUnits"."GeoId" AS "GeoId",
            "DistrictUnits"."Name" AS "Name", 
            "DistrictUnits"."StateId" as "ParentId",
            "VillageUnits"."Id" AS "SubId",
            "VillageUnits"."GeoId" AS "SubGeoId",
            "VillageUnits"."Name" AS "SubName",
            "VillageUnits"."DistrictId" AS "SubParentId"
        FROM "VillageUnits" 
        INNER JOIN "DistrictUnits" ON "DistrictUnits"."Id" = "VillageUnits"."DistrictId"
        WHERE
            (lower("VillageUnits"."Name") LIKE '%'|| lower(xfilter) ||'%')
         LIMIT cntregist;
	END;
$$;


ALTER FUNCTION public.get_districtsvillages(xfilter character varying, cntregist integer) OWNER TO dbuser;

--
-- Name: get_districtunits(integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_districtunits(disid integer, parid integer, cntregist integer, cntignored integer) RETURNS TABLE("Id" integer, "GeoId" character varying, "Name" text, "NameHi" text, "Abbreviation" character varying, "AbbreviationHi" character varying, "SubId" integer, "SubGeoId" character varying, "SubName" text, "SubNameHi" text, "SubParentId" integer, "Aspirational" boolean)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT
            "StateUnits"."Id" AS "Id",
            "StateUnits"."GeoId" AS "GeoId",
            "StateUnits"."Name" AS "Name", 
            "StateUnits"."Name_hi" AS "NameHi", 
            "StateUnits"."Abbreviation" AS "Abbreviation",
            "StateUnits"."Abbreviation_hi" AS "AbbreviationHi",
            "DistrictUnits"."Id" AS "SubId",
            "DistrictUnits"."GeoId" AS "SubGeoId",
            "DistrictUnits"."Name" AS "SubName",
            "DistrictUnits"."Name_hi" AS "SubNameHi",
            "DistrictUnits"."StateId" AS "SubParentId",
			"DistrictUnits"."Aspirational" AS "Aspirational"
        FROM "DistrictUnits" 
        INNER JOIN "StateUnits" ON "StateUnits"."Id" = "DistrictUnits"."StateId"
        WHERE ("DistrictUnits"."Id" = disId OR disId = 0)
               AND
               ("StateUnits"."Id" = parId OR parId = 0)
        ORDER BY "StateUnits"."Id" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_districtunits(disid integer, parid integer, cntregist integer, cntignored integer) OWNER TO dbuser;

--
-- Name: get_indac_indiastate(integer, integer, integer, integer, integer, character varying, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_indac_indiastate(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying, stid integer) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "Headcount" numeric, "PrevalenceRank" integer, "HeadcountRank" integer, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingstrategy" integer, "PrevalenceColor" character varying, "HeadcountColor" character varying, "Decile" integer, "ChangeColor" character varying, "Type" integer, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		(SELECT 
            "IndicatorAc"."AcId" AS "RegionId",
            "IndicatorAc"."Year" AS "Year",
            "IndicatorAc"."Prevalence" AS "Prevalence",
            "IndicatorAc"."Headcount" AS "Headcount",
            "IndicatorAc"."AcPrevalenceRank" AS "PrevalenceRank",
			"IndicatorAc"."AcHeadcountRank" AS "HeadcountRank",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
            "IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
            "IndicatorDeciles"."PrevalenceDecile" AS "Decile",
            "IndicatorChangeAc"."ChangeHex"  AS "ChangeColor",
            0 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorAc" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorAc"."IndicatorId"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "IndicatorAc"."IndicatorId"
        LEFT JOIN "IndicatorChangeAc" ON "IndicatorChangeAc"."PrevalenceChangeId" = "IndicatorAc"."PrevalenceChangeCategory" and "IndicatorChangeAc"."IndicatorId" = "IndicatorAc"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorAc"."Year" = yearSh OR yearEnd = "IndicatorAc"."Year")
            AND
            ("IndicatorAc"."AcId" = xId)
            AND
            ("IndicatorAc"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
            AND 
            "IndicatorDeciles"."PrevalenceDecile" = "IndicatorAc"."PrevalenceDecile"
            AND
            "IndicatorDeciles"."Year" = "IndicatorAc"."Year")

        UNION

        (SELECT 
            0 AS "RegionId",
            "IndicatorIndia"."Year" AS "Year",
            "IndicatorIndia"."Prevalence" AS "Prevalence",
            "IndicatorIndia"."Headcount" AS "Headcount",
            NULL AS "PrevalenceRank",
			NULL AS "HeadcountRank",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            NULL AS "PrevalenceColor",
            NULL AS "HeadcountColor",
            NULL AS "Decile",
            NULL  AS "ChangeColor",
            6 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorIndia" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorIndia"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorIndia"."Year" = yearSh OR yearEnd = "IndicatorIndia"."Year")
            AND
            ("IndicatorIndia"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[])))

        UNION

        (SELECT 
            "IndicatorState"."StateId" AS "RegionId",
            "IndicatorState"."Year" AS "Year",
            "IndicatorState"."Prevalence" AS "Prevalence",
            "IndicatorState"."Headcount" AS "Headcount",
            NULL AS "PrevalenceRank",
			NULL AS "HeadcountRank",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            NULL AS "PrevalenceColor",
            NULL AS "HeadcountColor",
            NULL AS "Decile",
            NULL  AS "ChangeColor",
            1 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorState" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorState"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorState"."Year" = yearSh OR yearEnd = "IndicatorState"."Year")
            AND
            ("IndicatorState"."StateId" = stId)
            AND
            ("IndicatorState"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[])))

        ORDER BY "Year" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_indac_indiastate(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying, stid integer) OWNER TO dbuser;

--
-- Name: get_inddistrict_indiastate(integer, integer, integer, integer, integer, character varying, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_inddistrict_indiastate(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying, stid integer) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "Headcount" numeric, "PrevalenceRank" integer, "HeadcountRank" integer, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingstrategy" integer, "PrevalenceColor" character varying, "HeadcountColor" character varying, "Decile" integer, "ChangeColor" character varying, "Type" integer, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		(SELECT 
            "IndicatorDistrict"."DistrictId" AS "RegionId",
            "IndicatorDistrict"."Year" AS "Year",
            "IndicatorDistrict"."Prevalence" AS "Prevalence",
            "IndicatorDistrict"."Headcount" AS "Headcount",
            "IndicatorDistrict"."PrevalenceRank" AS "PrevalenceRank",
			"IndicatorDistrict"."HeadcountRank" AS "HeadcountRank",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
            "IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
            "IndicatorDeciles"."PrevalenceDecile" AS "Decile",
            CASE WHEN "IndicatorDistrict"."PrevalenceChangeCategory" IS NULL THEN NULL ELSE "IndicatorChange"."ChangeHex" END AS "ChangeColor",
            0 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorDistrict" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorDistrict"."IndicatorId"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "IndicatorDistrict"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        LEFT JOIN "IndicatorChange" ON "IndicatorChange"."IndicatorId" = "IndicatorDistrict"."IndicatorId"
            AND ("IndicatorChange"."PrevalenceChangeId" = "IndicatorDistrict"."PrevalenceChangeCategory" OR "IndicatorDistrict"."PrevalenceChangeCategory" IS NULL)
        WHERE ("IndicatorDistrict"."Year" = yearSh OR yearEnd = "IndicatorDistrict"."Year")
            AND
            ("IndicatorDistrict"."DistrictId" = xId)
            AND
            ("IndicatorDistrict"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
            AND 
            "IndicatorDeciles"."PrevalenceDecile" = "IndicatorDistrict"."PrevalenceDecile"
            AND
            "IndicatorDeciles"."Year" = "IndicatorDistrict"."Year")

        UNION

        (SELECT 
            0 AS "RegionId",
            "IndicatorIndia"."Year" AS "Year",
            "IndicatorIndia"."Prevalence" AS "Prevalence",
            "IndicatorIndia"."Headcount" AS "Headcount",
            NULL AS "PrevalenceRank",
			NULL AS "HeadcountRank",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            NULL AS "PrevalenceColor",
            NULL AS "HeadcountColor",
            NULL AS "Decile",
            NULL  AS "ChangeColor",
            6 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorIndia" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorIndia"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorIndia"."Year" = yearSh OR yearEnd = "IndicatorIndia"."Year")
            AND
            ("IndicatorIndia"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[])))

        UNION

        (SELECT 
            "IndicatorState"."StateId" AS "RegionId",
            "IndicatorState"."Year" AS "Year",
            "IndicatorState"."Prevalence" AS "Prevalence",
            "IndicatorState"."Headcount" AS "Headcount",
            NULL AS "PrevalenceRank",
			NULL AS "HeadcountRank",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            NULL AS "PrevalenceColor",
            NULL AS "HeadcountColor",
            NULL AS "Decile",
            NULL  AS "ChangeColor",
            1 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorState" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorState"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorState"."Year" = yearSh OR yearEnd = "IndicatorState"."Year")
            AND
            ("IndicatorState"."StateId" = stId)
            AND
            ("IndicatorState"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[])))

        ORDER BY "Year" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_inddistrict_indiastate(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying, stid integer) OWNER TO dbuser;

--
-- Name: get_india_measurements(integer, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_india_measurements(yearsh integer, yearend integer, indicatorid integer, lang character varying DEFAULT 'en'::character varying) RETURNS TABLE("IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingStrategy" integer, "Description" text, "DescriptionHi" text, "Year" integer, "Prevalence" numeric, "Headcount" numeric)
    LANGUAGE plpgsql
    AS $$

	BEGIN 
        RETURN	QUERY
		SELECT 
                "Indicator"."Id" AS "IndId",
                "Indicator"."Name" AS "IndName",
                "Indicator"."Name_hi" AS "IndNameHI",
                "Indicator"."Direction" AS "IndReadingStrategy",
                "Indicator"."Description" AS "Description",
                "Indicator"."Description_hi" AS "DescriptionHI",
				"IndicatorIndia"."Year" AS "Year",
				"IndicatorIndia"."Prevalence" AS "Prevalence",
				"IndicatorIndia"."Headcount" AS "Headcount"
        FROM "IndicatorIndia"
        inner join "Indicator" ON "Indicator"."Id" = "IndicatorIndia"."IndicatorId"
        WHERE "Indicator"."Id" = indicatorid
			AND
			("IndicatorIndia"."Year" = yearSh OR "IndicatorIndia"."Year" = yearEnd)
		ORDER BY "IndicatorIndia"."Year" ASC;
	END;
$$;


ALTER FUNCTION public.get_india_measurements(yearsh integer, yearend integer, indicatorid integer, lang character varying) OWNER TO dbuser;

--
-- Name: get_indiaindicators(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_indiaindicators(yearsh integer, cntregist integer, cntignored integer) RETURNS TABLE("Year" integer, "Prevalence" numeric, "Headcount" integer, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingstrategy" integer)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorIndia"."Year",
            "IndicatorIndia"."Prevalence",
            "IndicatorIndia"."Headcount",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy"
        FROM "IndicatorIndia" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorIndia"."IndicatorId"
        WHERE ("IndicatorIndia"."Year" = yearSh OR yearSh = 0)
        ORDER BY "IndicatorIndia"."Year" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_indiaindicators(yearsh integer, cntregist integer, cntignored integer) OWNER TO dbuser;

--
-- Name: get_indiameasurements_cng(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_indiameasurements_cng(yearsh integer, yearend integer, lstind character varying) RETURNS TABLE("Year" integer, "Prevalence" numeric, "PrevalenceChange" numeric, "Headcount" integer, "IndId" integer, "IndName" text, "IndNameHi" text, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorIndia"."Year" AS "Year",
            "IndicatorIndia"."Prevalence" AS "Prevalence",
            "IndicatorIndia"."PrevalenceChange" AS "PrevalenceChange",
            "IndicatorIndia"."Headcount" AS "Headcount",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorIndia" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorIndia"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorIndia"."Year" = yearSh OR yearEnd = "IndicatorIndia"."Year")
            AND
            ("IndicatorIndia"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))

        ORDER BY "IndicatorIndia"."Year";
	END;
$$;


ALTER FUNCTION public.get_indiameasurements_cng(yearsh integer, yearend integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_indiameasurements_ind(integer, integer, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_indiameasurements_ind(yearsh integer, yearend integer, cntregist integer, cntignored integer, lstind character varying) RETURNS TABLE("Year" integer, "Prevalence" numeric, "Headcount" integer, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingstrategy" integer, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorIndia"."Year" AS "Year",
            "IndicatorIndia"."Prevalence" AS "Prevalence",
            "IndicatorIndia"."Headcount" AS "Headcount",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorIndia" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorIndia"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorIndia"."Year" = yearSh OR yearEnd = "IndicatorIndia"."Year")
            AND
            ("IndicatorIndia"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
            
        ORDER BY "IndicatorIndia"."Year" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_indiameasurements_ind(yearsh integer, yearend integer, cntregist integer, cntignored integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_indicatorDecilesAC(integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public."get_indicatorDecilesAC"(yearsh integer, lstind character varying) RETURNS TABLE("IndId" integer, "IndName" text, "Description" text, "Year" integer, "Decile" integer, "PrevalenceColor" character varying, "PrevalenceDecileCutoffs" numeric)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorDecilesAc"."IndicatorId" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Description",
            "IndicatorDecilesAc"."Year",
            "IndicatorDecilesAc"."PrevalenceDecile" AS "Decile",
            "IndicatorDecilesAc"."PrevalenceDecileHex" AS "PrevalenceColor",
            "IndicatorDecilesAc"."PrevalenceDecileCutoffs"            
        FROM "IndicatorDecilesAc" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorDecilesAc"."IndicatorId"
        WHERE ("IndicatorDecilesAc"."Year" = yearSh)
            AND
            ("IndicatorDecilesAc"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
        ORDER BY "IndicatorDecilesAc"."Id";
	END;
$$;


ALTER FUNCTION public."get_indicatorDecilesAC"(yearsh integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_indicatorcategories(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_indicatorcategories(cntregist integer, cntignored integer, categoryid integer) RETURNS TABLE("CatId" integer, "CatName" text, "CatNameHi" text, "IndId" integer, "IndName" text, "IndNameHi" text, "IndDescription" text, "IndDescriptionHi" text, "IndReadingStrategy" integer)
    LANGUAGE plpgsql
    AS $$

	BEGIN 
        RETURN	QUERY
		SELECT 
                "Category"."Id" AS "CatId",
                "Category"."Name" AS "CatName",
                "Category"."Name_hi" AS "CatNameHi",
                "Indicator"."Id" AS "IndId",
                "Indicator"."Name" AS "IndName",
                "Indicator"."Name_hi" AS "IndNameHi",
                "Indicator"."Description" AS "IndDescription",
                "Indicator"."Description_hi" AS "IndDescriptionHi",
                "Indicator"."Direction" AS "IndReadingStrategy"
        FROM "Category" 
        INNER JOIN "Indicator" ON "Indicator"."CategoryId" = "Category"."Id"        
        WHERE "Category"."Id" = categoryId OR categoryId = 0
        ORDER BY "Category"."Id" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_indicatorcategories(cntregist integer, cntignored integer, categoryid integer) OWNER TO dbuser;

--
-- Name: get_indicatorchange(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_indicatorchange(cntregist integer, cntignored integer, lstind character varying) RETURNS TABLE("IndicatorId" integer, "PrevalenceChangeId" integer, "PrevalenceChangeCutoffs" numeric, "ChangeHex" character varying, "ChangeDescription" text, "ChangeDescriptionHi" text, "IndicatorName" text, "IndicatorNameHi" text, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorChange"."IndicatorId",
            "IndicatorChange"."PrevalenceChangeId",
            "IndicatorChange"."PrevalenceChangeCutoffs",
            "IndicatorChange"."ChangeHex",
            "PrevalenceChange"."Name" AS "ChangeDescription",
            "PrevalenceChange"."Name_hi" AS "ChangeDescriptionHi",
            "Indicator"."Name" AS "IndicatorName",
            "Indicator"."Name_hi" AS "IndicatorNameHi",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorChange" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorChange"."IndicatorId"
        LEFT JOIN "PrevalenceChange" ON "PrevalenceChange"."Id" = "IndicatorChange"."PrevalenceChangeId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE 
            ("IndicatorChange"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
        ORDER BY "IndicatorChange"."IndicatorId" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_indicatorchange(cntregist integer, cntignored integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_indicatorchangeac(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_indicatorchangeac(cntregist integer, cntignored integer, lstind character varying) RETURNS TABLE("IndicatorId" integer, "PrevalenceChangeId" integer, "PrevalenceChangeCutoffs" numeric, "ChangeHex" character varying, "ChangeDescription" text, "ChangeDescriptionHi" text, "IndicatorName" text, "IndicatorNameHi" text, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorChangeAc"."IndicatorId",
            "IndicatorChangeAc"."PrevalenceChangeId",
            "IndicatorChangeAc"."PrevalenceChangeCutoffs",
            "IndicatorChangeAc"."ChangeHex",
            "PrevalenceChange"."Name" AS "ChangeDescription",
            "PrevalenceChange"."Name_hi" AS "ChangeDescriptionHi",
            "Indicator"."Name" AS "IndicatorName",
            "Indicator"."Name_hi" AS "IndicatorNameHi",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorChangeAc" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorChangeAc"."IndicatorId"
        LEFT JOIN "PrevalenceChange" ON "PrevalenceChange"."Id" = "IndicatorChangeAc"."PrevalenceChangeId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE 
            ("IndicatorChangeAc"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
        ORDER BY "IndicatorChangeAc"."IndicatorId" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_indicatorchangeac(cntregist integer, cntignored integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_indicatorchangepc(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_indicatorchangepc(cntregist integer, cntignored integer, lstind character varying) RETURNS TABLE("IndicatorId" integer, "PrevalenceChangeId" integer, "PrevalenceChangeCutoffs" numeric, "ChangeHex" character varying, "ChangeDescription" text, "ChangeDescriptionHi" text, "IndicatorName" text, "IndicatorNameHi" text, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorChangePc"."IndicatorId",
            "IndicatorChangePc"."PrevalenceChangeId",
            "IndicatorChangePc"."PrevalenceChangeCutoffs",
            "IndicatorChangePc"."ChangeHex",
            "PrevalenceChange"."Name" AS "ChangeDescription",
            "PrevalenceChange"."Name_hi" AS "ChangeDescriptionHi",
            "Indicator"."Name" AS "IndicatorName",
            "Indicator"."Name_hi" AS "IndicatorNameHi",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorChangePc" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorChangePc"."IndicatorId"
        LEFT JOIN "PrevalenceChange" ON "PrevalenceChange"."Id" = "IndicatorChangePc"."PrevalenceChangeId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE 
            ("IndicatorChangePc"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
        ORDER BY "IndicatorChangePc"."IndicatorId" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_indicatorchangepc(cntregist integer, cntignored integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_indicatordeciles(integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_indicatordeciles(yearsh integer, lstind character varying) RETURNS TABLE("IndId" integer, "IndName" text, "IndNameHi" text, "Description" text, "DescriptionHi" text, "Year" integer, "Decile" integer, "HeadcountDecile" integer, "PrevalenceColor" character varying, "HeadcountColor" character varying, "HeadcountDecileCutoffs" integer, "PrevalenceDecileCutoffs" numeric)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorDeciles"."IndicatorId" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "IndicatorDeciles"."Year",
            "IndicatorDeciles"."PrevalenceDecile" AS "Decile",
            "IndicatorDeciles"."HeadcountDecile" AS "HeadcountDecile",
            "IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
            "IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
            "IndicatorDeciles"."HeadcountDecileCutoffs",
            "IndicatorDeciles"."PrevalenceDecileCutoffs"
        FROM "IndicatorDeciles" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorDeciles"."IndicatorId"
        WHERE ("IndicatorDeciles"."Year" = yearSh)
            AND
            ("IndicatorDeciles"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
        ORDER BY "IndicatorDeciles"."Id";
	END;
$$;


ALTER FUNCTION public.get_indicatordeciles(yearsh integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_indicatordecilesPC(integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public."get_indicatordecilesPC"(yearsh integer, lstind character varying) RETURNS TABLE("IndId" integer, "IndName" text, "Description" text, "Year" integer, "Decile" integer, "PrevalenceColor" character varying, "HeadcountColor" character varying, "HeadcountDecileCutoffs" integer, "PrevalenceDecileCutoffs" numeric)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorDecilesPc"."IndicatorId" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Description",
            "IndicatorDecilesPc"."Year",
            "IndicatorDecilesPc"."PrevalenceDecile" AS "Decile",
            "IndicatorDecilesPc"."HeadcountDecile",
            "IndicatorDecilesPc"."PrevalenceDecileHex" AS "PrevalenceColor",
            "IndicatorDecilesPc"."HeadcountDecileHex" AS "HeadcountColor",
            "IndicatorDecilesPc"."HeadcountDecileCutoffs",
            "IndicatorDecilesPc"."PrevalenceDecileCutoffs"
        FROM "IndicatorDecilesPc" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorDecilesPc"."IndicatorId"
        WHERE ("IndicatorDecilesPc"."Year" = yearSh)
            AND
            ("IndicatorDecilesPc"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
        ORDER BY "IndicatorDecilesPc"."Id";
	END;
$$;


ALTER FUNCTION public."get_indicatordecilesPC"(yearsh integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_indicatordecilesac(integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_indicatordecilesac(yearsh integer, lstind character varying) RETURNS TABLE("IndId" integer, "IndName" text, "Description" text, "DescriptionHi" text, "Year" integer, "Decile" integer, "PrevalenceColor" character varying, "PrevalenceDecileCutoffs" numeric)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorDecilesAc"."IndicatorId" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "IndicatorDecilesAc"."Year",
            "IndicatorDecilesAc"."PrevalenceDecile" AS "Decile",
            "IndicatorDecilesAc"."PrevalenceDecileHex" AS "PrevalenceColor",
            "IndicatorDecilesAc"."PrevalenceDecileCutoffs"            
        FROM "IndicatorDecilesAc" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorDecilesAc"."IndicatorId"
        WHERE ("IndicatorDecilesAc"."Year" = yearSh)
            AND
            ("IndicatorDecilesAc"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
        ORDER BY "IndicatorDecilesAc"."Id";
	END;
$$;


ALTER FUNCTION public.get_indicatordecilesac(yearsh integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_indicatordecilespc(integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_indicatordecilespc(yearsh integer, lstind character varying) RETURNS TABLE("IndId" integer, "IndName" text, "IndNameHi" text, "Description" text, "DescriptionHi" text, "Year" integer, "Decile" integer, "PrevalenceColor" character varying, "HeadcountColor" character varying, "HeadcountDecileCutoffs" integer, "PrevalenceDecileCutoffs" numeric)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorDecilesPc"."IndicatorId" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Description",            
            "Indicator"."Description_hi" AS "DescriptionHi",
            "IndicatorDecilesPc"."Year",
            "IndicatorDecilesPc"."PrevalenceDecile" AS "Decile",
            "IndicatorDecilesPc"."PrevalenceDecileHex" AS "PrevalenceColor",
            "IndicatorDecilesPc"."HeadcountDecileHex" AS "HeadcountColor",
            "IndicatorDecilesPc"."HeadcountDecileCutoffs",
            "IndicatorDecilesPc"."PrevalenceDecileCutoffs"
        FROM "IndicatorDecilesPc" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorDecilesPc"."IndicatorId"
        WHERE ("IndicatorDecilesPc"."Year" = yearSh)
            AND
            ("IndicatorDecilesPc"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
        ORDER BY "IndicatorDecilesPc"."Id";
	END;
$$;


ALTER FUNCTION public.get_indicatordecilespc(yearsh integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_indicatordecilesvillages(integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_indicatordecilesvillages(stateid integer, lstind character varying) RETURNS TABLE("IndId" integer, "IndName" text, "IndNameHi" text, "Description" text, "DescriptionHi" text, "Decile" integer, "PrevalenceColor" character varying, "PrevalenceDecileCutoffs" numeric)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorDecilesVillages"."IndicatorId" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "IndicatorDecilesVillages"."PrevalenceDecile" AS "Decile",
            "IndicatorDecilesVillages"."PrevalenceDecileHex" AS "PrevalenceColor",
            "IndicatorDecilesVillages"."PrevalenceDecileCutoffs"
        FROM "IndicatorDecilesVillages" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorDecilesVillages"."IndicatorId"
        WHERE ("IndicatorDecilesVillages"."StateId" = stateid)
            AND
            ("IndicatorDecilesVillages"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
        ORDER BY "IndicatorDecilesVillages"."Id";
	END;
$$;


ALTER FUNCTION public.get_indicatordecilesvillages(stateid integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_indicatorindia(character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_indicatorindia(lstind character varying, yearx integer, yearend integer) RETURNS TABLE("RegionId" integer, "IndicatorId" integer, "IndicatorName" text, "IndicatorDirection" integer, "Prevalence" numeric, "Headcount" integer, "Year" integer)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            0 AS "RegionId",
            "IndicatorIndia"."IndicatorId",
            "Indicator"."Name" AS "IndicatorName",
            "Indicator"."Direction" AS "IndicatorDirection",
            "IndicatorIndia"."Prevalence",
            "IndicatorIndia"."Headcount",
            "IndicatorIndia"."Year"
        FROM "IndicatorIndia"
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorIndia"."IndicatorId"
        WHERE (("IndicatorIndia"."Year" = yearx OR yearx = 0) OR (yearx > 0 AND "IndicatorIndia"."Year" = yearEnd))
               AND
               ("IndicatorIndia"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
		ORDER BY "IndicatorIndia"."Year" ASC;

	END;
$$;


ALTER FUNCTION public.get_indicatorindia(lstind character varying, yearx integer, yearend integer) OWNER TO dbuser;

--
-- Name: get_indicators(integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_indicators(typeid integer DEFAULT NULL::integer, categoryid integer DEFAULT NULL::integer) RETURNS TABLE(id integer, "Name" character varying, "Definition" text, "ReadingStrategy" smallint, "Type" smallint, "Subcategory" smallint, "Category" smallint)
    LANGUAGE plpgsql
    AS $$
	BEGIN
		RETURN	QUERY
        SELECT	I.id,
                I."Name",
                I."Definition",
                I."ReadingStrategy",
                TI."Type",
                CASE 
                    WHEN CAT."ParentId" IS NULL THEN NULL
                    ELSE CAT.id
                END AS "Subcategory",
                CASE 
                    WHEN CAT."ParentId" IS NULL THEN CAT.id
                    ELSE CAT."ParentId"
                END AS "Category"
        FROM "Indicators" AS I
        INNER JOIN "TypedIndicators" AS TI
            ON	(TI."IndicatorId" = I.id)
        INNER JOIN "IndicatorCategories" AS IC
            ON	(IC."IndicatorId" = I.id)
        INNER JOIN "Categories" AS CAT
            ON	(CAT.id = IC."CategoryId");
	END;
$$;


ALTER FUNCTION public.get_indicators(typeid integer, categoryid integer) OWNER TO dbuser;

--
-- Name: get_indpc_indiastate(integer, integer, integer, integer, integer, character varying, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_indpc_indiastate(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying, stid integer) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "Headcount" numeric, "PrevalenceRank" integer, "HeadcountRank" integer, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingstrategy" integer, "PrevalenceColor" character varying, "HeadcountColor" character varying, "Decile" integer, "ChangeColor" character varying, "Type" integer, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		(SELECT 
            "IndicatorPc"."PcId" AS "RegionId",
            "IndicatorPc"."Year" AS "Year",
            "IndicatorPc"."Prevalence" AS "Prevalence",
            "IndicatorPc"."Headcount" AS "Headcount",
            "IndicatorPc"."PrevalenceRank" AS "PrevalenceRank",
			"IndicatorPc"."HeadcountRank" AS "HeadcountRank",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
            "IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
            "IndicatorDeciles"."PrevalenceDecile" AS "Decile",
            "IndicatorChangePc"."ChangeHex"  AS "ChangeColor",
            0 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorPc" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorPc"."IndicatorId"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "IndicatorPc"."IndicatorId"
        LEFT JOIN "IndicatorChangePc" ON "IndicatorChangePc"."PrevalenceChangeId" = "IndicatorPc"."PrevalenceChangeCategory" and "IndicatorChangePc"."IndicatorId" = "IndicatorPc"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorPc"."Year" = yearSh OR yearEnd = "IndicatorPc"."Year")
            AND
            ("IndicatorPc"."PcId" = xId)
            AND
            ("IndicatorPc"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
            AND 
            "IndicatorDeciles"."PrevalenceDecile" = "IndicatorPc"."PrevalenceDecile"
            AND
            "IndicatorDeciles"."Year" = "IndicatorPc"."Year")

        UNION

        (SELECT 
            0 AS "RegionId",
            "IndicatorIndia"."Year" AS "Year",
            "IndicatorIndia"."Prevalence" AS "Prevalence",
            "IndicatorIndia"."Headcount" AS "Headcount",
            NULL AS "PrevalenceRank",
			NULL AS "HeadcountRank",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            NULL AS "PrevalenceColor",
            NULL AS "HeadcountColor",
            NULL AS "Decile",
            NULL  AS "ChangeColor",
            6 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorIndia" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorIndia"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorIndia"."Year" = yearSh OR yearEnd = "IndicatorIndia"."Year")
            AND
            ("IndicatorIndia"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[])))

        UNION

        (SELECT 
            "IndicatorState"."StateId" AS "RegionId",
            "IndicatorState"."Year" AS "Year",
            "IndicatorState"."Prevalence" AS "Prevalence",
            "IndicatorState"."Headcount" AS "Headcount",
            NULL AS "PrevalenceRank",
			NULL AS "HeadcountRank",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            NULL AS "PrevalenceColor",
            NULL AS "HeadcountColor",
            NULL AS "Decile",
            NULL  AS "ChangeColor",
            1 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorState" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorState"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorState"."Year" = yearSh OR yearEnd = "IndicatorState"."Year")
            AND
            ("IndicatorState"."StateId" = stId)
            AND
            ("IndicatorState"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[])))

        ORDER BY "Year" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_indpc_indiastate(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying, stid integer) OWNER TO dbuser;

--
-- Name: get_indvillage_indiastate(integer, integer, integer, integer, integer, character varying, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_indvillage_indiastate(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying, disid integer) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "Headcount" numeric, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingstrategy" integer, "PrevalenceColor" character varying, "HeadcountColor" text, "Decile" integer, "Type" integer, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		(SELECT 
            "IndicatorVillage"."VillageId" AS "RegionId",
            "IndicatorVillage"."Year" AS "Year",
            "IndicatorVillage"."Prevalence" AS "Prevalence",
            0 AS "Headcount",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "IndicatorDecilesVillages"."PrevalenceDecileHex" AS "PrevalenceColor",
            NULL AS "HeadcountColor",
            "IndicatorDecilesVillages"."PrevalenceDecile" AS "Decile",
            0 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorVillage" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorVillage"."IndicatorId"
        INNER JOIN "IndicatorDecilesVillages" ON "IndicatorDecilesVillages"."IndicatorId" = "IndicatorVillage"."IndicatorId"
        INNER JOIN "DistrictUnits" ON "DistrictUnits"."Id" = disid
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE 
            ("IndicatorVillage"."VillageId" = xId)
            AND
            ("IndicatorVillage"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
            AND 
            "IndicatorDecilesVillages"."PrevalenceDecile" = "IndicatorVillage"."PrevalenceDecile"
            AND
            "DistrictUnits"."StateId" = "IndicatorDecilesVillages"."StateId")

        UNION

        (SELECT 
            0 AS "RegionId",
            "IndicatorIndia"."Year" AS "Year",
            "IndicatorIndia"."Prevalence" AS "Prevalence",
            "IndicatorIndia"."Headcount" AS "Headcount",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            NULL AS "PrevalenceColor",
            NULL AS "HeadcountColor",
            NULL AS "Decile",
            6 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorIndia" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorIndia"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorIndia"."Year" = yearSh OR yearEnd = "IndicatorIndia"."Year")
            AND
            ("IndicatorIndia"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[])))

        UNION

        (SELECT 
            "IndicatorState"."StateId" AS "RegionId",
            "IndicatorState"."Year" AS "Year",
            "IndicatorState"."Prevalence" AS "Prevalence",
            "IndicatorState"."Headcount" AS "Headcount",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            NULL AS "PrevalenceColor",
            NULL AS "HeadcountColor",
            NULL AS "Decile",
            1 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorState" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorState"."IndicatorId"
        INNER JOIN "DistrictUnits" ON "DistrictUnits"."Id" = disid
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorState"."Year" = yearSh OR yearEnd = "IndicatorState"."Year")
            AND
            ("DistrictUnits"."StateId" = "IndicatorState"."StateId")
            AND
            ("IndicatorState"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[])))

        ORDER BY "Year" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_indvillage_indiastate(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying, disid integer) OWNER TO dbuser;

--
-- Name: get_pc_improvement_ranking(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_pc_improvement_ranking(yearsh integer, yearend integer, pcid integer) RETURNS TABLE("Ranking" bigint, "SharedBy" bigint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        WITH PcRanking AS (
            SELECT pcu."Id" AS "PcId",
                (
                    SELECT COUNT(*)
                    FROM "IndicatorPc" indpc
                    WHERE indpc."Year" = yearend
                        AND indpc."PcId" = pcu."Id"
                        AND indpc."Prevalence" >
                            CASE 
                                WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indpc."IndicatorId") = 1 THEN
                                    (
                                        SELECT indpc2."Prevalence"
                                        FROM "IndicatorPc" indpc2
                                        WHERE indpc2."Year" = yearsh
                                            AND indpc2."IndicatorId" = indpc."IndicatorId"
                                            AND indpc2."PcId" = pcu."Id"
                                        LIMIT 1
                                    )
                                WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indpc."IndicatorId") = 2 THEN
                                    -1 * (
                                        SELECT indpc2."Prevalence"
                                        FROM "IndicatorPc" indpc2
                                        WHERE indpc2."Year" = yearsh
                                            AND indpc2."IndicatorId" = indpc."IndicatorId"
                                            AND indpc2."PcId" = pcu."Id"
                                        LIMIT 1
                                    )
                                ELSE
                                    NULL
                            END
                ) AS "ImprovedIndicatorsCount"
            FROM "PcUnits" pcu
        )
        , RankedPcs AS (
            SELECT "PcId", "ImprovedIndicatorsCount",
                RANK() OVER (ORDER BY "ImprovedIndicatorsCount" DESC) AS "Rank"
            FROM PcRanking
        )
        , RankedPcsCount AS (
            SELECT "PcId", "ImprovedIndicatorsCount", "Rank",
                COUNT(*) OVER (PARTITION BY "Rank") AS "PcsWithSameRank"
            FROM RankedPcs
        )
        SELECT "Rank", "PcsWithSameRank"
        FROM RankedPcsCount
        WHERE "PcId" = pcid;
	END;
$$;


ALTER FUNCTION public.get_pc_improvement_ranking(yearsh integer, yearend integer, pcid integer) OWNER TO dbuser;

--
-- Name: get_pc_indicators_amount_per_change(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_pc_indicators_amount_per_change(yearsh integer, yearend integer, pcid integer) RETURNS TABLE("PrevalenceChangeCategory" integer, "IndicatorCount" bigint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        WITH DataWithDifference AS (
            SELECT "IndicatorId", "PcId",
                MAX(CASE WHEN "Year" = yearend THEN "Prevalence" END) -
                MAX(CASE WHEN "Year" = yearsh THEN "Prevalence" END) AS "Difference"
            FROM "IndicatorPc"
            WHERE "PcId" = pcid
            AND "Year" IN (yearsh, yearend)
            GROUP BY "IndicatorId", "PcId"
        )
        , DataWithCutoffs AS (
            SELECT dd.*,
                ic."PrevalenceChangeId",
                ic."PrevalenceChangeCutoffs"
            FROM DataWithDifference dd
            JOIN "IndicatorChangePc" ic
            ON dd."IndicatorId" = ic."IndicatorId"
        )
        , DataWithDirection AS (
            SELECT "IndicatorId", "PcId", "Difference", "PrevalenceChangeId", "PrevalenceChangeCutoffs", i."Direction"
            FROM DataWithCutoffs
            JOIN "Indicator" i
            ON "IndicatorId" = i."Id"
        )
        , RankedData AS (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY "IndicatorId" ORDER BY "PrevalenceChangeId") AS rn
            FROM DataWithDirection
            WHERE ("Direction" = 1 AND "PrevalenceChangeId" <> 0 AND "Difference" > "PrevalenceChangeCutoffs")
            OR ("Direction" = 2 AND "PrevalenceChangeId" <> 0 AND "Difference" < "PrevalenceChangeCutoffs")
        )
        , ReducedRankedData AS (
            SELECT * FROM RankedData
            WHERE rn = 1
        )
        , PrevalenceChangeCounts AS (
            SELECT "PrevalenceChangeId", COUNT(*) AS "RowCount"
            FROM ReducedRankedData
            GROUP BY "PrevalenceChangeId"
        )
        SELECT gs."PrevalenceChangeId" AS "PrevalenceChangeCategory", COALESCE(pcc."RowCount", 0) AS "IndicatorCount"
        FROM generate_series(1, 4) AS gs("PrevalenceChangeId")
        LEFT JOIN PrevalenceChangeCounts pcc
        ON gs."PrevalenceChangeId" = pcc."PrevalenceChangeId"
        ORDER BY gs."PrevalenceChangeId";
	END;
$$;


ALTER FUNCTION public.get_pc_indicators_amount_per_change(yearsh integer, yearend integer, pcid integer) OWNER TO dbuser;

--
-- Name: get_pc_indicators_better_than_all_india(integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_pc_indicators_better_than_all_india(yearsh integer, pcid integer) RETURNS TABLE("BetterThanAverage" bigint, "TotalIndicators" bigint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        SELECT 
            COUNT(*) AS "BetterThanAverage",
            (SELECT COUNT(*) FROM public."Indicator" WHERE "Description" IS NOT NULL) AS "TotalIndicators"
        FROM public."IndicatorPc" indpc
        WHERE "Year" = yearsh AND "PcId" = pcid
        AND CASE 
            WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indpc."IndicatorId") = 1 THEN
                "Prevalence"  >= (SELECT "Prevalence" FROM public."IndicatorIndia" WHERE "IndicatorId" = indpc."IndicatorId" AND "Year" = yearsh)
            WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indpc."IndicatorId") = 2 THEN
                "Prevalence"  <= (SELECT "Prevalence" FROM public."IndicatorIndia" WHERE "IndicatorId" = indpc."IndicatorId" AND "Year" = yearsh)
            ELSE
                NULL
        END;
	END;
$$;


ALTER FUNCTION public.get_pc_indicators_better_than_all_india(yearsh integer, pcid integer) OWNER TO dbuser;

--
-- Name: get_pc_indicators_better_than_state(integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_pc_indicators_better_than_state(yearsh integer, pcid integer) RETURNS TABLE("BetterThanAverage" bigint, "TotalIndicators" bigint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        SELECT 
            COUNT(*) AS "BetterThanAverage",
            (SELECT COUNT(*) FROM public."Indicator" WHERE "Description" IS NOT NULL) AS "TotalIndicators"
        FROM public."IndicatorPc" indpc
        WHERE "Year" = yearsh AND "PcId" = pcid

AND
        CASE 
                WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indpc."IndicatorId") = 1 THEN
                    "Prevalence"  >=  (
                        SELECT "Prevalence" FROM public."IndicatorState"
                        WHERE "StateId" = (
                            SELECT "ParentId" FROM "PcUnits" du
                            WHERE du."Id" = pcid
                            LIMIT 1
                        ) AND "IndicatorId" = indpc."IndicatorId" AND "Year" = yearsh
                        LIMIT 1
                    )
                WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indpc."IndicatorId") = 2 THEN
                    "Prevalence"  <= (
                        SELECT "Prevalence" FROM public."IndicatorState"
                        WHERE "StateId" = (
                            SELECT "ParentId" FROM "PcUnits" du
                            WHERE du."Id" = pcid
                            LIMIT 1
                        ) AND "IndicatorId" = indpc."IndicatorId" AND "Year" = yearsh
                        LIMIT 1
                    )
                ELSE
                    NULL
            END;
	END;
$$;


ALTER FUNCTION public.get_pc_indicators_better_than_state(yearsh integer, pcid integer) OWNER TO dbuser;

--
-- Name: get_pc_measurements(integer, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_pc_measurements(yearsh integer, yearend integer, indicatorid integer, listregid character varying) RETURNS TABLE("IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingStrategy" integer, "Description" text, "DescriptionHi" text, "Id" integer, "GeoId" character varying, "Name" text, "NameHi" text, "StateName" text, "StateNameHi" text, "StateAbbreviation" character varying, "StateAbbreviationHi" character varying, "Year" integer, "Prevalence" numeric, "Headcount" numeric, "HeadcountRank" integer, "PrevalenceRank" integer, "PrevalenceColor" character varying, "HeadcountColor" character varying, "PrevalenceDecile" integer, "HeadcountDecile" integer)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
                "Indicator"."Id" AS "IndId",
                "Indicator"."Name" AS "IndName",
                "Indicator"."Name_hi" AS "IndNameHi",
                "Indicator"."Direction" AS "IndReadingStrategy",
                "Indicator"."Description" AS "Description",
                "Indicator"."Description_hi" AS "DescriptionHi",
                "PcUnits"."Id" AS "Id",
                "PcUnits"."GeoId" AS "GeoId",
                "PcUnits"."Name" AS "Name",
                "PcUnits"."Name_hi" AS "NameHi",
                "StateUnits"."Name" AS "StateName",
                "StateUnits"."Name_hi" AS "StateNameHi",
                "StateUnits"."Abbreviation" AS "StateAbbreviation",
                "StateUnits"."Abbreviation_hi" AS "StateAbbreviationHi",
				"IndicatorPc"."Year" AS "Year",
				"IndicatorPc"."Prevalence" AS "Prevalence",
				"IndicatorPc"."Headcount" AS "Headcount",
				"IndicatorPc"."HeadcountRank",
				"IndicatorPc"."PrevalenceRank",
				 prevDecile."PrevalenceDecileHex" AS "PrevalenceColor",
            headDecile."HeadcountDecileHex" AS "HeadcountColor",
            prevDecile."PrevalenceDecile" ,
            headDecile."HeadcountDecile"
        FROM "IndicatorPc" 
        inner join "PcUnits" ON "PcUnits"."Id" = "IndicatorPc"."PcId"
        inner join "StateUnits" ON "StateUnits"."Id" = "PcUnits"."ParentId"
        inner join "Indicator" ON "Indicator"."Id" = "IndicatorPc"."IndicatorId"
       INNER JOIN "IndicatorDeciles" prevDecile ON prevDecile."IndicatorId" = "Indicator"."Id" AND prevDecile."PrevalenceDecile" = "IndicatorPc" ."PrevalenceDecile"
            and prevDecile."Year" = "IndicatorPc" ."Year" 
    LEFT  JOIN "IndicatorDeciles" headDecile ON headDecile."IndicatorId" = "Indicator"."Id" AND headDecile."HeadcountDecile" = "IndicatorPc" ."HeadcountDecile"
            AND headDecile."Year" = "IndicatorPc" ."Year"
        WHERE "Indicator"."Id" = indicatorid
			AND
			("IndicatorPc"."Year" = yearSh OR "IndicatorPc"."Year" = yearEnd)
            AND
            ("PcUnits"."Id" = ANY(STRING_TO_ARRAY(listregId,',')::INTEGER[]) OR listregId = '')
		ORDER BY "IndicatorPc"."Year" ASC;
	END;
$$;


ALTER FUNCTION public.get_pc_measurements(yearsh integer, yearend integer, indicatorid integer, listregid character varying) OWNER TO dbuser;

--
-- Name: get_pc_table_of_indicators(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_pc_table_of_indicators(yearsh integer, yearend integer, pcid integer) RETURNS TABLE("CatId" integer, "CatName" text, "CatNameHi" text, "Name" text, "NameHi" text, "GoiAbv" text, "GoiAbvHi" text, "IndiaPrevalence" numeric, "StatePrevalence" numeric, "RegionPrevalence" numeric, "Change" numeric, "PrevalenceChangeCategory" integer, "IndId" integer)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        WITH DataWithDifference AS(
            SELECT i."CategoryId", c."Name" AS "CatName", c."Name_hi" AS "CatNameHi", i."Name", i."Name_hi" AS "NameHi", i."GOI_ABV", i."GOI_ABV_hi", "IndicatorId",
                    (SELECT "Prevalence"
                    FROM public."IndicatorIndia"
                    WHERE "IndicatorId" = indpc."IndicatorId" AND "Year" = yearend) AS "India2021",
                    (
                        SELECT "Prevalence" FROM public."IndicatorState"
                        WHERE "StateId" = (
                            SELECT "ParentId" FROM "PcUnits"
                            WHERE "Id" = pcid
                            LIMIT 1
                        ) AND "IndicatorId" = indpc."IndicatorId" AND "Year" = yearend
                        LIMIT 1
                    ) AS "State2021",
                    MAX(CASE WHEN "Year" = yearend THEN "Prevalence" END) AS "Prevalence2021",
                    MAX(CASE WHEN "Year" = yearend THEN "Prevalence" END) -
                    MAX(CASE WHEN "Year" = yearsh THEN "Prevalence" END) AS "Difference",
                    i."Direction"
            FROM "IndicatorPc" indpc
            JOIN "Indicator" i ON "IndicatorId" = i."Id"
            JOIN "Category" c ON c."Id" = i."CategoryId"
            WHERE "PcId" = pcid
            AND "Year" IN (yearsh, yearend)
            GROUP BY i."CategoryId", c."Name", c."Name_hi", i."Name", i."Name_hi", i."GOI_ABV", i."GOI_ABV_hi", "IndicatorId", "PcId", i."Direction"
        )
        , DataWithCutoffs AS (
            SELECT dd.*,
                ic."PrevalenceChangeId",
                ic."PrevalenceChangeCutoffs"
            FROM DataWithDifference dd
            JOIN "IndicatorChange" ic
            ON dd."IndicatorId" = ic."IndicatorId"
        )
        , RankedData AS (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY "IndicatorId" ORDER BY "PrevalenceChangeId") AS rn
            FROM DataWithCutoffs
            WHERE ("Direction" = 1 AND "PrevalenceChangeId" <> 0 AND "Difference" > "PrevalenceChangeCutoffs")
            OR ("Direction" = 2 AND "PrevalenceChangeId" <> 0 AND "Difference" < "PrevalenceChangeCutoffs")
        )
        , ReducedRankedData AS (
            SELECT * FROM RankedData
            WHERE rn = 1
        )
        SELECT rrd."CategoryId",
                rrd."CatName",
                rrd."CatNameHi",
                rrd."Name",
                rrd."NameHi",
                rrd."GOI_ABV",
                rrd."GOI_ABV_hi",
                round(rrd."India2021",1) AS "IndiaPrevalence",
                round(rrd."State2021",1) AS "StatePrevalence",
                round(rrd."Prevalence2021",1) AS "RegionPrevalence",
                round("Difference",1) AS "Change",
                "PrevalenceChangeId" AS "PrevalenceChangeCategory",
                rrd."IndicatorId"
        FROM ReducedRankedData rrd;
	END;
$$;


ALTER FUNCTION public.get_pc_table_of_indicators(yearsh integer, yearend integer, pcid integer) OWNER TO dbuser;

--
-- Name: get_pc_top_indicators_change(integer, integer, integer, integer, boolean); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_pc_top_indicators_change(yearsh integer, yearend integer, pcid integer, count integer, improvement boolean) RETURNS TABLE("Indicator" text, "IndicatorHi" text)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        SELECT i."Name", i."Name_hi"
        FROM (
            SELECT "IndicatorId","PrevalenceChangeCategory",
                (CASE
                    WHEN (SELECT "Direction" FROM "Indicator" WHERE "Id" = "IndicatorId") = 1 THEN
                       "PrevalenceChange"
                    WHEN (SELECT "Direction" FROM "Indicator" WHERE "Id" = "IndicatorId") = 2 THEN
                        -1 *  "PrevalenceChange"
                    ELSE
                        NULL
                END) AS "Difference"
            FROM "IndicatorPc"
            WHERE "PcId" = pcid
            AND "Year" IN (yearsh, yearend)
        ) AS subquery
        JOIN "Indicator" i ON subquery."IndicatorId" = i."Id"
        WHERE subquery."Difference" IS NOT NULL and subquery."PrevalenceChangeCategory" is not null
        ORDER BY 
            CASE WHEN improvement THEN subquery."PrevalenceChangeCategory" ELSE NULL END ASC,
            CASE WHEN NOT improvement THEN subquery."PrevalenceChangeCategory" ELSE NULL END DESC,
            CASE WHEN improvement THEN subquery."Difference" ELSE NULL END DESC,
            CASE WHEN NOT improvement THEN subquery."Difference" ELSE NULL END ASC
        LIMIT count;
	END;
$$;


ALTER FUNCTION public.get_pc_top_indicators_change(yearsh integer, yearend integer, pcid integer, count integer, improvement boolean) OWNER TO dbuser;

--
-- Name: get_pccatindicators(integer, integer, integer, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_pccatindicators(yearsh integer, yearend integer, xid integer, indicatorid character varying, categoryid integer, stateid integer) RETURNS TABLE("CatId" integer, "CatName" text, "CatNameHi" text, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingStrategy" integer, "Description" text, "DescriptionHi" text, "Year" integer, "Prevalence" numeric, "Headcount" integer, "PrevalenceRank" integer, "HeadcountRank" integer, "PrevalenceColor" character varying, "HeadcountColor" character varying, "Decile" integer, "ChangeColor" character varying, "Type" integer, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$

	BEGIN 
        RETURN	QUERY
		(SELECT 
                "Category"."Id" AS "CatId",
                "Category"."Name" AS "CatName", 
                "Category"."Name_hi" AS "CatNameHi",
                "Indicator"."Id" AS "IndId",
                "Indicator"."Name" AS "IndName",
                "Indicator"."Name_hi" AS "IndNameHi",
                "Indicator"."Direction" AS "IndReadingStrategy",
                "Indicator"."Description",
                "Indicator"."Description_hi" AS "DescriptionHi",
				"IndicatorPc"."Year" AS "Year",
				"IndicatorPc"."Prevalence",
				"IndicatorPc"."Headcount",
                "IndicatorPc"."PrevalenceRank",
				"IndicatorPc"."HeadcountRank",
				"IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
				"IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
				"IndicatorDeciles"."PrevalenceDecile" AS "Decile",
                "IndicatorChangePc"."ChangeHex"  AS "ChangeColor",
				0 as "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "Indicator" 
        INNER JOIN "Category" ON "Category"."Id" = "Indicator"."CategoryId"
		INNER JOIN "IndicatorPc" ON "IndicatorPc"."IndicatorId" = "Indicator"."Id"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "IndicatorPc"."IndicatorId"
        INNER JOIN "IndicatorChangePc" ON "IndicatorChangePc"."PrevalenceChangeId" = "IndicatorPc"."PrevalenceChangeCategory" and "IndicatorChangePc"."IndicatorId" = "IndicatorPc"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE "Indicator"."CategoryId" = categoryId
			AND
			("Indicator"."Id" = ANY(STRING_TO_ARRAY(indicatorId,',')::INTEGER[]))
			AND
			("IndicatorPc"."Year" = yearSh OR "IndicatorPc"."Year" = yearEnd)
			AND
			"IndicatorPc"."PcId" = xId
            AND 
            "IndicatorDeciles"."PrevalenceDecile" = "IndicatorPc"."PrevalenceDecile"
            AND
            "IndicatorDeciles"."Year" = "IndicatorPc"."Year")

        UNION

        (SELECT 
                "Category"."Id" AS "CatId",
                "Category"."Name" AS "CatName",
                "Category"."Name_hi" AS "CatNameHi",
                "Indicator"."Id" AS "IndId",
                "Indicator"."Name" AS "IndName",
                "Indicator"."Name_hi" AS "IndNameHi",
                "Indicator"."Direction" AS "IndReadingStrategy", 
                "Indicator"."Description", 
                "Indicator"."Description_hi" AS "DescriptionHi",
				"IndicatorIndia"."Year" AS "Year",
				"IndicatorIndia"."Prevalence",
				"IndicatorIndia"."Headcount",
                NULL AS "PrevalenceRank",
				NULL AS "HeadcountRank",
				NULL AS "PrevalenceColor",
				NULL AS "HeadcountColor",
				NULL AS "Decile",
                NULL AS "ChangeColor",
                6 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "Indicator"
        INNER JOIN "Category" ON "Category"."Id" = "Indicator"."CategoryId"
		INNER JOIN "IndicatorIndia" ON "IndicatorIndia"."IndicatorId" = "Indicator"."Id"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE "Indicator"."CategoryId" = categoryId
			AND
			("Indicator"."Id" = ANY(STRING_TO_ARRAY(indicatorId,',')::INTEGER[]))
			AND
			("IndicatorIndia"."Year" = yearSh OR "IndicatorIndia"."Year" = yearEnd)
			)
        
        UNION

        (SELECT 
            "Category"."Id" AS "CatId",
            "Category"."Name" AS "CatName",
            "Category"."Name_hi" AS "CatNameHi",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "Indicator"."Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "IndicatorState"."Year" AS "Year",
            "IndicatorState"."Prevalence" AS "Prevalence",
            "IndicatorState"."Headcount" AS "Headcount",
            NULL AS "PrevalenceRank",
            NULL AS "HeadcountRank",
            NULL AS "PrevalenceColor",
            NULL AS "HeadcountColor",
            NULL AS "Decile",
            NULL AS "ChangeColor",
            1 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "Indicator" 
        INNER JOIN "Category" ON "Category"."Id" = "Indicator"."CategoryId"
		INNER JOIN "IndicatorState" ON "IndicatorState"."IndicatorId" = "Indicator"."Id"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE "Indicator"."CategoryId" = categoryId
			AND
			("Indicator"."Id" = ANY(STRING_TO_ARRAY(indicatorId,',')::INTEGER[]))
			AND
			("IndicatorState"."Year" = yearSh OR "IndicatorState"."Year" = yearEnd)
			AND
			"IndicatorState"."StateId" = stateId)
			ORDER BY "Year";
		
	END;
$$;


ALTER FUNCTION public.get_pccatindicators(yearsh integer, yearend integer, xid integer, indicatorid character varying, categoryid integer, stateid integer) OWNER TO dbuser;

--
-- Name: get_pchch(integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_pchch(pcid integer) RETURNS TABLE("Id" integer, "Name" text, "NameHi" text, "ParentId" integer, "ParentName" text, "ParentNameHi" text, "StateId" integer, "StateName" text, "StateNameHi" text)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "PcUnits"."Id" AS "Id",
            "PcUnits"."Name" as "Name",
            "PcUnits"."Name_hi" as "NameHi",
			"StateUnits"."Id" AS "ParentId",
            "StateUnits"."Name" AS "ParentName",
            "StateUnits"."Name_hi" AS "ParentNameHi",
			"StateUnits"."Id" AS "StateId",
            "StateUnits"."Name" AS "StateName",
            "StateUnits"."Name_hi" AS "StateNameHi"
        FROM "PcUnits" 
        INNER JOIN "StateUnits" ON "StateUnits"."Id" = "PcUnits"."ParentId"
        WHERE "PcUnits"."Id" = pcId;
	END;
$$;


ALTER FUNCTION public.get_pchch(pcid integer) OWNER TO dbuser;

--
-- Name: get_pcindicators(integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_pcindicators(yearsh integer, xid integer, cntregist integer, cntignored integer) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "Headcount" integer, "PrevalenceRank" integer, "HeadcountRank" integer, "HeadcountColor" character varying, "PrevalenceColor" character varying, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingstrategy" integer, "Description" text, "DescriptionHi" text, "Decile" integer)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorPc"."PcId" AS "RegionId",
            "IndicatorPc"."Year",
            "IndicatorPc"."Prevalence",
            "IndicatorPc"."Headcount",
            "IndicatorPc"."PrevalenceRank",
            "IndicatorPc"."HeadcountRank",
            "IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
            "IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "Indicator"."Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "IndicatorDeciles"."PrevalenceDecile" AS "Decile"
        FROM "IndicatorPc" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorPc"."IndicatorId"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "Indicator"."Id"
        WHERE ("IndicatorPc"."Year" = yearSh OR yearSh = 0)
               AND
               ("IndicatorPc"."PcId" = xId)
        ORDER BY "IndicatorPc"."Year" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_pcindicators(yearsh integer, xid integer, cntregist integer, cntignored integer) OWNER TO dbuser;

--
-- Name: get_pcmeasurements_cng(integer, integer, character varying, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_pcmeasurements_cng(yearsh integer, yearend integer, lstreg character varying, cntregist integer, cntignored integer, lstind character varying) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "PrevalenceChange" numeric, "ChangeId" integer, "Decile" integer, "IndId" integer, "IndName" text, "IndNameHi" text, "ChangeHex" character varying, "ChangeCutoffs" numeric, "ChangeDescription" text, "ChangeDescriptionHi" text, "India" boolean, "DeepDiveCompareColor" character varying, "Name" text, "NameHi" text, "StateName" text, "StateNameHi" text, "StateAbbreviation" character varying, "StateAbbreviationHi" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		(SELECT 
            "IndicatorPc"."PcId" AS "RegionId",
            "IndicatorPc"."Year" AS "Year",
            "IndicatorPc"."Prevalence" AS "Prevalence",
            "IndicatorPc"."PrevalenceChange" AS "PrevalenceChange",
            "IndicatorPc"."PrevalenceChangeCategory" AS "ChangeId",
            "IndicatorPc"."PrevalenceDecile"  AS "Decile",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "IndicatorChange"."ChangeHex",
            "IndicatorChange"."PrevalenceChangeCutoffs" AS "ChangeCutoffs",
            "PrevalenceChange"."Name" AS "ChangeDescription",
            "PrevalenceChange"."Name_hi" AS "ChangeDescriptionHi",
             FALSE AS "India",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor",
            "PcUnits"."Name",
            "PcUnits"."Name_hi" AS "NameHi",
            "StateUnits"."Name" AS "StateName",
            "StateUnits"."Name_hi" AS "StateNameHi",
            "StateUnits"."Abbreviation" AS "StateAbbreviation",
            "StateUnits"."Abbreviation_hi" AS "StateAbbreviationHi"
        FROM "IndicatorPc" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorPc"."IndicatorId"
        INNER JOIN "IndicatorChange" ON "IndicatorChange"."IndicatorId" = "IndicatorPc"."IndicatorId"
        INNER JOIN "PrevalenceChange" ON "PrevalenceChange"."Id" = "IndicatorChange"."PrevalenceChangeId"
        INNER JOIN "PcUnits" ON "IndicatorPc"."PcId" = "PcUnits"."Id"
        inner join "StateUnits" ON "StateUnits"."Id" = "PcUnits"."ParentId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorPc"."Year" = yearSh OR yearEnd = "IndicatorPc"."Year")
            AND
            ("IndicatorPc"."PcId" =  ANY(STRING_TO_ARRAY(lstreg,',')::INTEGER[]))
            AND
            ("IndicatorPc"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
            AND
            "IndicatorChange"."PrevalenceChangeId" = "IndicatorPc"."PrevalenceChangeCategory"

        ORDER BY "IndicatorPc"."Year" LIMIT cntRegist OFFSET cntIgnored)

        UNION

        (SELECT 
            0 AS "RegionId",
            "IndicatorIndia"."Year" AS "Year",
            "IndicatorIndia"."Prevalence" AS "Prevalence",
            "IndicatorIndia"."PrevalenceChange" AS "PrevalenceChange",
            0 AS "ChangeId",
            0 AS "Decile",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            NULL AS "ChangeHex",
            NULL AS "ChangeCutoffs",
            NULL AS "ChangeDescription",
            NULL AS "ChangeDescriptionHi",
            TRUE AS "India",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor",
            NULL AS "Name",
            NULL AS "NameHi",
            NULL AS "StateName",
            NULL AS "StateNameHi",
            NULL AS "StateAbbreviation",
            NULL AS "StateAbbreviationHi"
        FROM "IndicatorIndia" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorIndia"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorIndia"."Year" = yearsh OR "IndicatorIndia"."Year" = yearend)
            AND
            ("IndicatorIndia"."IndicatorId" = ANY(STRING_TO_ARRAY(lstind,',')::INTEGER[]))

        ORDER BY "IndicatorIndia"."Year");
	END;
$$;


ALTER FUNCTION public.get_pcmeasurements_cng(yearsh integer, yearend integer, lstreg character varying, cntregist integer, cntignored integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_pcmeasurements_ind(integer, integer, integer, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_pcmeasurements_ind(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "Headcount" integer, "PrevalenceRank" integer, "HeadcountRank" integer, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingstrategy" integer, "Description" text, "DescriptionHi" text, "PrevalenceColor" character varying, "HeadcountColor" character varying, "Decile" integer, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorPc"."PcId" AS "RegionId",
            "IndicatorPc"."Year" AS "Year",
            "IndicatorPc"."Prevalence",
            "IndicatorPc"."Headcount",
            "IndicatorPc"."PrevalenceRank",
            "IndicatorPc"."HeadcountRank",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "Indicator"."Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
            "IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
            "IndicatorDeciles"."PrevalenceDecile" AS "Decile",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorPc" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorPc"."IndicatorId"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "IndicatorPc"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorPc"."Year" = yearSh OR yearEnd = "IndicatorPc"."Year")
            AND
            ("IndicatorPc"."PcId" = xId)
            AND
            ("IndicatorPc"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
            AND 
            "IndicatorDeciles"."PrevalenceDecile" = "IndicatorPc"."PrevalenceDecile"
            AND
            "IndicatorDeciles"."Year" = "IndicatorPc"."Year"
        ORDER BY "IndicatorPc"."Year" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_pcmeasurements_ind(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_pcunits(integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_pcunits(pcid integer, parid integer, cntregist integer, cntignored integer) RETURNS TABLE("Id" integer, "GeoId" character varying, "Name" text, "NameHi" text, "Abbreviation" character varying, "AbbreviationHi" character varying, "SubId" integer, "SubGeoId" character varying, "SubName" text, "SubNameHi" text, "SubParentId" smallint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT
            "StateUnits"."Id" AS "Id",
            "StateUnits"."GeoId" AS "GeoId",
            "StateUnits"."Name" AS "Name",
            "StateUnits"."Name_hi" AS "NameHi", 
            "StateUnits"."Abbreviation" AS "Abbreviation",
            "StateUnits"."Abbreviation_hi" AS "AbbreviationHi",
            "PcUnits"."Id" AS "SubId",
            "PcUnits"."GeoId" AS "SubGeoId",
            "PcUnits"."Name" AS "SubName",
            "PcUnits"."Name_hi" AS "SubNameHi",
            "PcUnits"."ParentId" AS "SubParentId"
        FROM "PcUnits" 
        INNER JOIN "StateUnits" ON "StateUnits"."Id" = "PcUnits"."ParentId"
        WHERE ("PcUnits"."Id" = pcId OR pcId = 0)
               AND
               ("StateUnits"."Id" = parId OR parId = 0)
        ORDER BY "StateUnits"."Id" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_pcunits(pcid integer, parid integer, cntregist integer, cntignored integer) OWNER TO dbuser;

--
-- Name: get_state_measurements(integer, integer, integer, character varying, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_state_measurements(yearsh integer, yearend integer, indicatorid integer, listregid character varying, lang character varying DEFAULT 'en'::character varying) RETURNS TABLE("IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingStrategy" integer, "Description" text, "DescriptionHi" text, "Id" integer, "GeoId" character varying, "Name" text, "NameHi" text, "Year" integer, "Prevalence" numeric, "PrevalenceChange" numeric, "Headcount" numeric)
    LANGUAGE plpgsql
    AS $$

	BEGIN 
        RETURN	QUERY
		SELECT 
                "Indicator"."Id" AS "IndId",
                "Indicator"."Name" AS "IndName",
                "Indicator"."Name_hi" AS "IndNameHi",
                "Indicator"."Direction" AS "IndReadingStrategy",             
                "Indicator"."Description" AS "Description",
                "Indicator"."Description_hi" AS "DescriptionHi",
                "StateUnits"."Id" AS "Id",
                "StateUnits"."GeoId" AS "GeoId",      
                "StateUnits"."Name" AS "Name",
                "StateUnits"."Name_hi" AS "NameHi",
				"IndicatorState"."Year" AS "Year",
				"IndicatorState"."Prevalence" AS "Prevalence",
                "IndicatorState"."PrevalenceChange" AS "PrevalenceChange",
				"IndicatorState"."Headcount" AS "Headcount"
        FROM "IndicatorState" 
        inner join "StateUnits" ON "StateUnits"."Id" = "IndicatorState"."StateId"
        inner join "Indicator" ON "Indicator"."Id" = "IndicatorState"."IndicatorId"
        WHERE "Indicator"."Id" = indicatorid
			AND
			("IndicatorState"."Year" = yearSh OR "IndicatorState"."Year" = yearEnd)
            AND
            ("StateUnits"."Id" = ANY(STRING_TO_ARRAY(listregId,',')::INTEGER[]) OR listregId = '')
		ORDER BY "IndicatorState"."Year" ASC;
	END;
$$;


ALTER FUNCTION public.get_state_measurements(yearsh integer, yearend integer, indicatorid integer, listregid character varying, lang character varying) OWNER TO dbuser;

--
-- Name: get_statecatindicators(integer, integer, integer, character varying, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_statecatindicators(yearsh integer, yearend integer, xid integer, indicatorid character varying, categoryid integer) RETURNS TABLE("CatId" integer, "CatName" text, "CatNameHi" text, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingStrategy" integer, "Year" integer, "Prevalence" numeric, "Headcount" integer, "Type" integer, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$

	BEGIN 
        RETURN	QUERY
		(SELECT 
                "Category"."Id" AS "CatId",
                "Category"."Name" AS "CatName",
                "Category"."Name_hi" AS "CatNameHi",
                "Indicator"."Id" AS "IndId",
                "Indicator"."Name" AS "IndName",
                "Indicator"."Name_hi" AS "IndNameHi",
                "Indicator"."Direction" AS "IndReadingStrategy",
				"IndicatorState"."Year" AS "Year",
				"IndicatorState"."Prevalence" AS "Prevalence",
				"IndicatorState"."Headcount" AS "Headcount",
		 		0 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "Indicator" 
        INNER JOIN "Category" ON "Category"."Id" = "Indicator"."CategoryId"
		INNER JOIN "IndicatorState" ON "IndicatorState"."IndicatorId" = "Indicator"."Id"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE "Indicator"."CategoryId" = categoryId
			AND
			("Indicator"."Id" = ANY(STRING_TO_ARRAY(indicatorId,',')::INTEGER[]))
			AND
			("IndicatorState"."Year" = yearSh OR "IndicatorState"."Year" = yearEnd)
			AND
			"IndicatorState"."StateId" = xId)

        UNION

        (SELECT 
                "Category"."Id" AS "CatId",
                "Category"."Name" AS "CatName",
                "Category"."Name_hi" AS "CatNameHi",
                "Indicator"."Id" AS "IndId",
                "Indicator"."Name" AS "IndName",
                "Indicator"."Name_hi" AS "IndNameHi",
                "Indicator"."Direction" AS "IndReadingStrategy", 
				"IndicatorIndia"."Year" AS "Year",
				"IndicatorIndia"."Prevalence" AS "Prevalence",
				"IndicatorIndia"."Headcount" AS "Headcount",
                6 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "Indicator"
        INNER JOIN "Category" ON "Category"."Id" = "Indicator"."CategoryId"
		INNER JOIN "IndicatorIndia" ON "IndicatorIndia"."IndicatorId" = "Indicator"."Id"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE "Indicator"."CategoryId" = categoryId
			AND
			("Indicator"."Id" = ANY(STRING_TO_ARRAY(indicatorId,',')::INTEGER[]))
			AND
			("IndicatorIndia"."Year" = yearSh OR "IndicatorIndia"."Year" = yearEnd))
			ORDER BY "Year";
	END;
$$;


ALTER FUNCTION public.get_statecatindicators(yearsh integer, yearend integer, xid integer, indicatorid character varying, categoryid integer) OWNER TO dbuser;

--
-- Name: get_stateindicators(integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_stateindicators(yearsh integer, xid integer, cntregist integer, cntignored integer) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "Headcount" integer, "HeadcountColor" character varying, "PrevalenceColor" character varying, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingstrategy" integer, "Description" text, "DescriptionHi" text, "Decile" integer)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorState"."StateId" AS "RegionId",
            "IndicatorState"."Year",
            "IndicatorState"."Prevalence",
            "IndicatorState"."Headcount",
            "IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
            "IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "Indicator"."Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "IndicatorDeciles"."PrevalenceDecile" AS "Decile"
        FROM "IndicatorState" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorState"."IndicatorId"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "Indicator"."Id"
        WHERE ("IndicatorState"."Year" = yearSh OR yearSh = 0)
               AND
               ("IndicatorState"."StateId" = xId)
        ORDER BY "IndicatorState"."Year" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_stateindicators(yearsh integer, xid integer, cntregist integer, cntignored integer) OWNER TO dbuser;

--
-- Name: get_statemeasurements_ind(integer, integer, integer, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_statemeasurements_ind(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "Headcount" integer, "PrevalenceChange" numeric, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingstrategy" integer, "Description" text, "DescriptionHi" text, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorState"."StateId" AS "RegionId",
            "IndicatorState"."Year" AS "Year",
            "IndicatorState"."Prevalence" AS "Prevalence",
            "IndicatorState"."Headcount" AS "Headcount",
            "IndicatorState"."PrevalenceChange" AS "PrevalenceChange",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "Indicator"."Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorState" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorState"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorState"."Year" = yearSh OR yearEnd = "IndicatorState"."Year")
            AND
            ("IndicatorState"."StateId" = xId)
            AND
            ("IndicatorState"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
        ORDER BY "IndicatorState"."Year" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_statemeasurements_ind(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying) OWNER TO dbuser;

--
-- Name: Urls; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."Urls" (
    "Key" character varying(10) NOT NULL,
    "Url" text NOT NULL,
    "Clicks" integer,
    "Archived" boolean,
    "ArchivedDate" date
);


ALTER TABLE public."Urls" OWNER TO dbuser;

--
-- Name: get_urls(character varying, boolean); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_urls(xkey character varying, archived boolean) RETURNS SETOF public."Urls"
    LANGUAGE plpgsql
    AS $$
	BEGIN
		RETURN QUERY
 		SELECT *
		FROM public."Urls"        
		WHERE "Key" = xkey AND "Archived" = archived
		LIMIT 1;
	END;
$$;


ALTER FUNCTION public.get_urls(xkey character varying, archived boolean) OWNER TO dbuser;

--
-- Name: get_village_indicators_better_than_all_india(integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_village_indicators_better_than_all_india(yearsh integer, xid integer) RETURNS TABLE("BetterThanAverage" bigint, "TotalIndicators" bigint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        SELECT 
            COUNT(*) AS "BetterThanAverage",
            (SELECT COUNT(*) FROM public."Indicator" WHERE "Description" IS NOT NULL) AS "TotalIndicators"
        FROM public."IndicatorVillage" indv
        WHERE "Year" = yearsh AND "VillageId" = xid
        AND CASE 
            WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indv."IndicatorId") = 1 THEN
                "Prevalence"  >= (SELECT "Prevalence" FROM public."IndicatorIndia" WHERE "IndicatorId" = indv."IndicatorId" AND "Year" = yearsh)
            WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indv."IndicatorId") = 2 THEN
                "Prevalence"  <= (SELECT "Prevalence" FROM public."IndicatorIndia" WHERE "IndicatorId" = indv."IndicatorId" AND "Year" = yearsh)
            ELSE
                NULL
        END;
	END;
$$;


ALTER FUNCTION public.get_village_indicators_better_than_all_india(yearsh integer, xid integer) OWNER TO dbuser;

--
-- Name: get_village_indicators_better_than_district(integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_village_indicators_better_than_district(yearsh integer, xid integer) RETURNS TABLE("BetterThanAverage" bigint, "TotalIndicators" bigint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        SELECT 
            COUNT(*) AS "BetterThanAverage",
            (SELECT COUNT(*) FROM public."Indicator" WHERE "Description" IS NOT NULL) AS "TotalIndicators"
        FROM public."IndicatorVillage" indv
        WHERE "Year" = yearsh AND "VillageId" = xid

        AND CASE 
                WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indv."IndicatorId") = 1 THEN
                    "Prevalence"  >  (
                        SELECT "Prevalence" FROM public."IndicatorDistrict"
                        WHERE "DistrictId" = (
                            SELECT "DistrictId" FROM "VillageUnits" du
                            WHERE du."Id" = xid
                            LIMIT 1
                        ) AND "IndicatorId" = indv."IndicatorId" AND "Year" = yearsh
                        LIMIT 1
                    )
                WHEN (SELECT "Direction" FROM public."Indicator" WHERE "Id" = indv."IndicatorId") = 2 THEN
                    "Prevalence"  < (
                        SELECT "Prevalence" FROM public."IndicatorDistrict"
                        WHERE "DistrictId" = (
                            SELECT "DistrictId" FROM "VillageUnits" du
                            WHERE du."Id" = xid
                            LIMIT 1
                        ) AND "IndicatorId" = indv."IndicatorId" AND "Year" = yearsh
                        LIMIT 1
                    )
                ELSE
                    NULL
            END;
	END;
$$;


ALTER FUNCTION public.get_village_indicators_better_than_district(yearsh integer, xid integer) OWNER TO dbuser;

--
-- Name: get_village_indicators_per_decile(integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_village_indicators_per_decile(xid integer) RETURNS TABLE("PrevDecile" integer, "Count" bigint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT "PrevalenceDecile", COUNT(*) AS "Count"
        FROM public."IndicatorVillage"
        WHERE "VillageId" = 267341
        GROUP BY "PrevalenceDecile"
        ORDER BY "PrevalenceDecile";
	END;
$$;


ALTER FUNCTION public.get_village_indicators_per_decile(xid integer) OWNER TO dbuser;

--
-- Name: get_village_metrics(integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_village_metrics(indicatorid integer, listregid character varying) RETURNS TABLE("IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingStrategy" integer, "Description" text, "DescriptionHi" text, "Id" integer, "Name" text, "NameHi" text, "Prevalence" numeric, "PrevalenceRank" integer, "PrevalenceDecile" integer)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",     
            "Indicator"."Description" AS "Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "VillageUnits"."Id" AS "Id",
            "VillageUnits"."Name" AS "Name",
            "VillageUnits"."Name_hi" AS "NameHi",
            "IndicatorVillage"."Prevalence",
            "IndicatorVillage"."PrevalenceRank",
            "IndicatorVillage"."PrevalenceDecile"
        FROM "IndicatorVillage" 
        inner join "VillageUnits" ON "VillageUnits"."Id" = "IndicatorVillage"."VillageId"
        inner join "Indicator" ON "Indicator"."Id" = "IndicatorVillage"."IndicatorId"
        WHERE "Indicator"."Id" = indicatorid
        AND
        (listregId = '' OR "VillageUnits"."DistrictId" = ANY(STRING_TO_ARRAY(listregId,',')::INTEGER[]));
	END;
$$;


ALTER FUNCTION public.get_village_metrics(indicatorid integer, listregid character varying) OWNER TO dbuser;

--
-- Name: get_village_table_of_indicators(integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_village_table_of_indicators(yearsh integer, xid integer) RETURNS TABLE("CatId" integer, "CatName" text, "CatNameHi" text, "Name" text, "NameHi" text, "GoiAbv" text, "GoiAbvHi" text, "IndiaPrevalence" numeric, "StatePrevalence" numeric, "RegionPrevalence" numeric, "PrevDecile" integer, "IndId" integer)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN QUERY
        WITH DataWithDifference AS(
            SELECT i."CategoryId", c."Name" AS "CatName", c."Name_hi" AS "CatNameHi", i."Name", i."Name_hi" AS "NameHi", i."GOI_ABV", i."GOI_ABV_hi", "IndicatorId",
                    (SELECT "Prevalence"
                    FROM public."IndicatorIndia"
                    WHERE "IndicatorId" = indv."IndicatorId" AND "Year" = yearsh) AS "India2021",
                    (
                        SELECT "Prevalence" FROM public."IndicatorDistrict"
                        WHERE "DistrictId" = (
                            SELECT "DistrictId" FROM "VillageUnits"
                            WHERE "Id" = xid
                            LIMIT 1
                        ) AND "IndicatorId" = indv."IndicatorId" AND "Year" = yearsh
                        LIMIT 1
                    ) AS "District2021",
                    MAX(CASE WHEN "Year" = yearsh THEN "Prevalence" END) AS "Prevalence2021",
                    i."Direction"
            FROM "IndicatorVillage" indv
            JOIN "Indicator" i ON "IndicatorId" = i."Id"
            JOIN "Category" c ON c."Id" = i."CategoryId"
            WHERE "VillageId" = xid
            GROUP BY i."CategoryId", c."Name", c."Name_hi", i."Name", i."Name_hi", i."GOI_ABV", i."GOI_ABV_hi", "IndicatorId", "VillageId", i."Direction"
        )
        , DataWithDeciles AS (
            SELECT dd.*,
                iv."PrevalenceDecile"
            FROM DataWithDifference dd
            JOIN "IndicatorVillage" iv
            ON dd."IndicatorId" = iv."IndicatorId" AND iv."VillageId" = xid
        )
        SELECT dwd."CategoryId",
                dwd."CatName",
                dwd."CatNameHi",
                dwd."Name",
                dwd."NameHi",
                dwd."GOI_ABV",
                dwd."GOI_ABV_hi",
                round(dwd."India2021",1) AS "IndiaPrevalence",
                round(dwd."District2021",1) AS "DistrictPrevalence",
                round(dwd."Prevalence2021",1) AS "RegionPrevalence",
                dwd."PrevalenceDecile",
                dwd."IndicatorId"
        FROM DataWithDeciles dwd;
	END;
$$;


ALTER FUNCTION public.get_village_table_of_indicators(yearsh integer, xid integer) OWNER TO dbuser;

--
-- Name: get_villagecatindicators(integer, integer, integer, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_villagecatindicators(yearsh integer, yearend integer, xid integer, indicatorid character varying, categoryid integer, stateid integer) RETURNS TABLE("CatId" integer, "CatName" text, "CatNameHi" text, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingStrategy" integer, "Description" text, "DescriptionHi" text, "Year" integer, "Prevalence" numeric, "Headcount" integer, "PrevalenceRank" integer, "HeadcountRank" integer, "PrevalenceColor" character varying, "HeadcountColor" character varying, "Decile" integer, "Type" integer, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$

	BEGIN 
        RETURN	QUERY
		(SELECT 
                "Category"."Id" AS "CatId",
                "Category"."Name" AS "CatName", 
                "Category"."Name_hi" AS "CatNameHi", 
                "Indicator"."Id" AS "IndId",
                "Indicator"."Name" AS "IndName",
                "Indicator"."Name_hi" AS "IndNameHi",
                "Indicator"."Direction" AS "IndReadingStrategy",
                "Indicator"."Description",
                "Indicator"."Description_hi" AS "DescriptionHi",
				"IndicatorVillage"."Year" AS "Year",
				"IndicatorVillage"."Prevalence",
				"IndicatorVillage"."Headcount",
                "IndicatorVillage"."PrevalenceRank",
				"IndicatorVillage"."HeadcountRank",
				"IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
				"IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
				"IndicatorDeciles"."PrevalenceDecile" AS "Decile",
		 		0 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "Indicator" 
        INNER JOIN "Category" ON "Category"."Id" = "Indicator"."CategoryId"
		INNER JOIN "IndicatorVillage" ON "IndicatorVillage"."IndicatorId" = "Indicator"."Id"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "Indicator"."Id"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE "Indicator"."CategoryId" = categoryId
			AND
			("Indicator"."Id" = ANY(STRING_TO_ARRAY(indicatorId,',')::INTEGER[]))
			AND
			("IndicatorVillage"."Year" = yearSh OR "IndicatorVillage"."Year" = yearEnd)
			AND
			"IndicatorVillage"."VillageId" = xId
            AND 
            "IndicatorDeciles"."PrevalenceDecile" = "IndicatorVillage"."PrevalenceDecile"
            AND
            "IndicatorDeciles"."Year" = "IndicatorVillage"."Year")

        UNION

        (SELECT 
                "Category"."Id" AS "CatId",
                "Category"."Name" AS "CatName",
                "Category"."Name_hi" AS "CatNameHi",
                "Indicator"."Id" AS "IndId",
                "Indicator"."Name" AS "IndName",
                "Indicator"."Name_hi" AS "IndNameHi",
                "Indicator"."Direction" AS "IndReadingStrategy", 
                "Indicator"."Description", 
                "Indicator"."Description_hi" AS "DescriptionHi",
				"IndicatorIndia"."Year" AS "Year",
				"IndicatorIndia"."Prevalence" AS "Prevalence",
				"IndicatorIndia"."Headcount" AS "Headcount",
                NULL AS "PrevalenceRank",
				NULL AS "HeadcountRank",
				NULL AS "PrevalenceColor",
				NULL AS "HeadcountColor",
				NULL AS "Decile",
                6 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "Indicator"
        INNER JOIN "Category" ON "Category"."Id" = "Indicator"."CategoryId"
		INNER JOIN "IndicatorIndia" ON "IndicatorIndia"."IndicatorId" = "Indicator"."Id"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE "Indicator"."CategoryId" = categoryId
			AND
			("Indicator"."Id" = ANY(STRING_TO_ARRAY(indicatorId,',')::INTEGER[]))
			AND
			("IndicatorIndia"."Year" = yearSh OR "IndicatorIndia"."Year" = yearEnd)
			)
        
        UNION

        (SELECT 
            "Category"."Id" AS "CatId",
            "Category"."Name" AS "CatName",
            "Category"."Name_hi" AS "CatNameHi",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "Indicator"."Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "IndicatorState"."Year" AS "Year",
            "IndicatorState"."Prevalence" AS "Prevalence",
            "IndicatorState"."Headcount" AS "Headcount",
            NULL AS "PrevalenceRank",
            NULL AS "HeadcountRank",
            NULL AS "PrevalenceColor",
            NULL AS "HeadcountColor",
            NULL AS "Decile",
            1 AS "Type",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "Indicator" 
        INNER JOIN "Category" ON "Category"."Id" = "Indicator"."CategoryId"
		INNER JOIN "IndicatorState" ON "IndicatorState"."IndicatorId" = "Indicator"."Id"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE "Indicator"."CategoryId" = categoryId
			AND
			("Indicator"."Id" = ANY(STRING_TO_ARRAY(indicatorId,',')::INTEGER[]))
			AND
			("IndicatorState"."Year" = yearSh OR "IndicatorState"."Year" = yearEnd)
			AND
			"IndicatorState"."StateId" = stateId)
			ORDER BY "Year";
	END;
$$;


ALTER FUNCTION public.get_villagecatindicators(yearsh integer, yearend integer, xid integer, indicatorid character varying, categoryid integer, stateid integer) OWNER TO dbuser;

--
-- Name: get_villagehch(integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_villagehch(xid integer) RETURNS TABLE("Id" integer, "Name" text, "NameHi" text, "ParentId" integer, "ParentName" text, "ParentNameHi" text, "StateId" integer, "StateName" text, "StateNameHi" text)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "VillageUnits"."Id" AS "Id",
            "VillageUnits"."Name" AS "Name",
            "VillageUnits"."Name_hi" AS "NameHi",
			"DistrictUnits"."Id" AS "ParentId",
            "DistrictUnits"."Name" AS "ParentName",
            "DistrictUnits"."Name_hi" AS "ParentNameHi",
			"StateUnits"."Id" AS "StateId",
            "StateUnits"."Name" AS "StateName",
            "StateUnits"."Name_hi" AS "StateNameHi"
        FROM "VillageUnits" 
        LEFT JOIN "DistrictUnits" ON "DistrictUnits"."Id" = "VillageUnits"."DistrictId"
		LEFT JOIN "StateUnits" ON "StateUnits"."Id" = "DistrictUnits"."StateId"
        WHERE "VillageUnits"."Id" = xid;
	END;
$$;


ALTER FUNCTION public.get_villagehch(xid integer) OWNER TO dbuser;

--
-- Name: get_villageindicators(integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_villageindicators(yearsh integer, xid integer, cntregist integer, cntignored integer) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "Headcount" integer, "PrevalenceRank" integer, "HeadcountRank" integer, "HeadcountColor" character varying, "PrevalenceColor" character varying, "IndId" integer, "IndName" text, "IndNameHi" text, "IndReadingstrategy" integer, "Description" text, "DescriptionHi" text, "Decile" integer)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorVillage"."VillageId" AS "RegionId",
            "IndicatorVillage"."Year",
            "IndicatorVillage"."Prevalence",
            "IndicatorVillage"."Headcount",
            "IndicatorVillage"."PrevalenceRank",
            "IndicatorVillage"."HeadcountRank",
            "IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
            "IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "Indicator"."Description",
            "Indicator"."Description_hi" AS "DescriptionHi",
            "IndicatorDeciles"."PrevalenceDecile" AS "Decile"
        FROM "IndicatorVillage" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorVillage"."IndicatorId"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "Indicator"."Id"
        WHERE ("IndicatorVillage"."Year" = yearSh OR yearSh = 0)
               AND
               ("IndicatorVillage"."VillageId" = xId)
        ORDER BY "IndicatorVillage"."Year" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_villageindicators(yearsh integer, xid integer, cntregist integer, cntignored integer) OWNER TO dbuser;

--
-- Name: get_villagemeasurements_cng(integer, integer, character varying, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_villagemeasurements_cng(yearsh integer, yearend integer, lstreg character varying, cntregist integer, cntignored integer, lstind character varying) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "PrevalenceChange" numeric, "ChangeId" integer, "Decile" integer, "IndId" integer, "IndName" text, "IndNameHi" text, "ChangeHex" character varying, "ChangeCutoffs" numeric, "ChangeDescription" text, "ChangeDescriptionHi" text, "India" boolean, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		(SELECT 
            "IndicatorVillage"."VillageId" AS "RegionId",
            "IndicatorVillage"."Year" AS "Year",
            "IndicatorVillage"."Prevalence" AS "Prevalence",
            "IndicatorVillage"."PrevalenceChange" AS "PrevalenceChange",
            "IndicatorVillage"."PrevalenceChangeCategory" AS "ChangeId",
            "IndicatorVillage"."PrevalenceDecile"  AS "Decile",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            "IndicatorChange"."ChangeHex",
            "IndicatorChange"."PrevalenceChangeCutoffs" AS "ChangeCutoffs",
            "PrevalenceChange"."Name" AS "ChangeDescription",
            "PrevalenceChange"."Name_hi" AS "ChangeDescriptionHi",
             FALSE AS "India",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorVillage" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorVillage"."IndicatorId"
        INNER JOIN "IndicatorChange" ON "IndicatorChange"."IndicatorId" = "IndicatorVillage"."IndicatorId"
        INNER JOIN "PrevalenceChange" ON "PrevalenceChange"."Id" = "IndicatorChange"."PrevalenceChangeId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorVillage"."Year" = yearSh OR yearEnd = "IndicatorVillage"."Year")
            AND
            ("IndicatorVillage"."VillageId" =  ANY(STRING_TO_ARRAY(lstreg,',')::INTEGER[]))
            AND
            ("IndicatorVillage"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
            AND
            "IndicatorChange"."PrevalenceChangeId" = "IndicatorVillage"."PrevalenceChangeCategory"

        ORDER BY "IndicatorVillage"."Year" LIMIT cntRegist OFFSET cntIgnored)

        UNION

        (SELECT 
            0 AS "RegionId",
            "IndicatorIndia"."Year" AS "Year",
            "IndicatorIndia"."Prevalence" AS "Prevalence",
            "IndicatorIndia"."PrevalenceChange" AS "PrevalenceChange",
            0 AS "ChangeId",
            0 AS "Decile",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Name_hi" AS "IndNameHi",
            NULL AS "ChangeHex",
            NULL AS "ChangeCutoffs",
            NULL AS "ChangeDescription",
            NULL AS "ChangeDescriptionHi",
            TRUE AS "India",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorIndia" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorIndia"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorIndia"."Year" = yearsh OR "IndicatorIndia"."Year" = yearend)
            AND
            ("IndicatorIndia"."IndicatorId" = ANY(STRING_TO_ARRAY(lstind,',')::INTEGER[]))

        ORDER BY "IndicatorIndia"."Year");
	END;
$$;


ALTER FUNCTION public.get_villagemeasurements_cng(yearsh integer, yearend integer, lstreg character varying, cntregist integer, cntignored integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_villagemeasurements_ind(integer, integer, integer, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_villagemeasurements_ind(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying) RETURNS TABLE("RegionId" integer, "Year" integer, "Prevalence" numeric, "Headcount" integer, "PrevalenceRank" integer, "HeadcountRank" integer, "IndId" integer, "IndName" text, "IndReadingstrategy" integer, "Description" text, "PrevalenceColor" character varying, "HeadcountColor" character varying, "Decile" integer, "DeepDiveCompareColor" character varying)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT 
            "IndicatorVillage"."VillageId" AS "RegionId",
            "IndicatorVillage"."Year" AS "Year",
            "IndicatorVillage"."Prevalence",
            "IndicatorVillage"."Headcount",
            "IndicatorVillage"."PrevalenceRank",
            "IndicatorVillage"."HeadcountRank",
            "Indicator"."Id" AS "IndId",
            "Indicator"."Name" AS "IndName",
            "Indicator"."Direction" AS "IndReadingStrategy",
            "Indicator"."Description",
            "IndicatorDeciles"."PrevalenceDecileHex" AS "PrevalenceColor",
            "IndicatorDeciles"."HeadcountDecileHex" AS "HeadcountColor",
            "IndicatorDeciles"."PrevalenceDecile" AS "Decile",
            "GlobalConfig"."Value" AS "DeepDiveCompareColor"
        FROM "IndicatorVillage" 
        INNER JOIN "Indicator" ON "Indicator"."Id" = "IndicatorVillage"."IndicatorId"
        INNER JOIN "IndicatorDeciles" ON "IndicatorDeciles"."IndicatorId" = "IndicatorVillage"."IndicatorId"
        LEFT JOIN "GlobalConfig" ON "GlobalConfig"."Name" = 'DeepDive-Compare-Color'
        WHERE ("IndicatorVillage"."Year" = yearSh OR yearEnd = "IndicatorVillage"."Year")
            AND
            ("IndicatorVillage"."VillageId" = xId)
            AND
            ("IndicatorVillage"."IndicatorId" = ANY(STRING_TO_ARRAY(lstInd,',')::INTEGER[]))
            AND 
            "IndicatorDeciles"."PrevalenceDecile" = "IndicatorVillage"."PrevalenceDecile"
            AND
            "IndicatorDeciles"."Year" = "IndicatorVillage"."Year"
        ORDER BY "IndicatorVillage"."Year" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_villagemeasurements_ind(yearsh integer, yearend integer, xid integer, cntregist integer, cntignored integer, lstind character varying) OWNER TO dbuser;

--
-- Name: get_villageunits(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.get_villageunits(parid integer, cntregist integer, cntignored integer) RETURNS TABLE("Id" integer, "GeoId" character varying, "Name" text, "NameHi" text, "SubId" integer, "SubGeoId" character varying, "SubName" text, "SubNameHi" text, "SubParentId" smallint)
    LANGUAGE plpgsql
    AS $$
	BEGIN 
        RETURN	QUERY
		SELECT
            "DistrictUnits"."Id" AS "Id",
            "DistrictUnits"."GeoId" AS "GeoId",
            "DistrictUnits"."Name" AS "Name", 
            "DistrictUnits"."Name_hi" AS "NameHi", 
            "VillageUnits"."Id" AS "SubId",
            "VillageUnits"."GeoId" AS "SubGeoId",
            "VillageUnits"."Name" AS "SubName",
            "VillageUnits"."Name_hi" AS "SubNameHi",
            "VillageUnits"."DistrictId" AS "SubParentId"
        FROM "VillageUnits" 
        INNER JOIN "DistrictUnits" ON "DistrictUnits"."Id" = "VillageUnits"."DistrictId"
        WHERE  
               "DistrictUnits"."Id" = parId OR parId = 0
        ORDER BY "DistrictUnits"."Id" LIMIT cntRegist OFFSET cntIgnored;
	END;
$$;


ALTER FUNCTION public.get_villageunits(parid integer, cntregist integer, cntignored integer) OWNER TO dbuser;

--
-- Name: ins_url(character varying, character varying); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.ins_url(xurl character varying, xkey character varying) RETURNS SETOF public."Urls"
    LANGUAGE plpgsql
    AS $$
	BEGIN
		
		INSERT INTO public."Urls" ("Key", "Url", "Archived", "Clicks")
		VALUES (xkey, xurl, FALSE, 0);
		
		RETURN QUERY
 		
		SELECT * FROM public."Urls" WHERE "Key" = xkey AND "Archived" = FALSE
		LIMIT 1;
	END;
$$;


ALTER FUNCTION public.ins_url(xurl character varying, xkey character varying) OWNER TO dbuser;

--
-- Name: upd_url(character varying, boolean, integer); Type: FUNCTION; Schema: public; Owner: dbuser
--

CREATE FUNCTION public.upd_url(xkey character varying, archived boolean, cl integer) RETURNS SETOF public."Urls"
    LANGUAGE plpgsql
    AS $$
	BEGIN
		
		UPDATE public."Urls"
		SET "Archived" = archived, "Clicks" = cl
		WHERE "Key" = xkey;

		RETURN QUERY
 		
		SELECT * FROM public."Urls" WHERE "Key" = xkey
		LIMIT 1;
	END;
$$;


ALTER FUNCTION public.upd_url(xkey character varying, archived boolean, cl integer) OWNER TO dbuser;

--
-- Name: AcMetrics; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."AcMetrics" (
    "AcId" smallint NOT NULL,
    "PcId" smallint NOT NULL,
    "TypedIndicatorId" smallint NOT NULL,
    "Year" smallint NOT NULL,
    "Value" numeric DEFAULT 0
);


ALTER TABLE public."AcMetrics" OWNER TO dbuser;

--
-- Name: AcUnits; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."AcUnits" (
    "GeoId" character varying(12),
    "Name" text,
    "StateId" integer,
    "Id" integer,
    "Name_hi" text
);


ALTER TABLE public."AcUnits" OWNER TO dbuser;

--
-- Name: Categories_id_seq; Type: SEQUENCE; Schema: public; Owner: dbuser
--

CREATE SEQUENCE public."Categories_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Categories_id_seq" OWNER TO dbuser;

--
-- Name: Categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dbuser
--

ALTER SEQUENCE public."Categories_id_seq" OWNED BY public."Categories".id;


--
-- Name: Category; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."Category" (
    "Id" integer NOT NULL,
    "Name" text,
    "Name_hi" text
);


ALTER TABLE public."Category" OWNER TO dbuser;

--
-- Name: Census; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."Census" (
    "Division" character varying(100),
    "TotalPopulation" integer,
    "Density" integer,
    "SexRatio" integer,
    "Urban" numeric
);


ALTER TABLE public."Census" OWNER TO dbuser;

--
-- Name: ChangeAvailability; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."ChangeAvailability" (
    "Id" integer NOT NULL,
    "Name" text
);


ALTER TABLE public."ChangeAvailability" OWNER TO dbuser;

--
-- Name: ChangeAvailability_Id_seq; Type: SEQUENCE; Schema: public; Owner: dbuser
--

ALTER TABLE public."ChangeAvailability" ALTER COLUMN "Id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."ChangeAvailability_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: Direction; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."Direction" (
    "Id" integer NOT NULL,
    "Name" text
);


ALTER TABLE public."Direction" OWNER TO dbuser;

--
-- Name: Direction_Id_seq; Type: SEQUENCE; Schema: public; Owner: dbuser
--

ALTER TABLE public."Direction" ALTER COLUMN "Id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."Direction_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: DistrictMetrics; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."DistrictMetrics" (
    "Year" smallint NOT NULL,
    "Value" numeric,
    id integer NOT NULL,
    "StateId" smallint,
    "TypedIndicatorId" smallint,
    "DistrictId" smallint
);


ALTER TABLE public."DistrictMetrics" OWNER TO dbuser;

--
-- Name: DistrictMeasurements_id_seq; Type: SEQUENCE; Schema: public; Owner: dbuser
--

CREATE SEQUENCE public."DistrictMeasurements_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."DistrictMeasurements_id_seq" OWNER TO dbuser;

--
-- Name: DistrictMeasurements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dbuser
--

ALTER SEQUENCE public."DistrictMeasurements_id_seq" OWNED BY public."DistrictMetrics".id;


--
-- Name: DistrictUnits; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."DistrictUnits" (
    "GeoId" character varying(12),
    "Name" text,
    "Aspirational" boolean,
    "Id" integer,
    "StateId" integer,
    "Name_hi" text
);


ALTER TABLE public."DistrictUnits" OWNER TO dbuser;

--
-- Name: Indicator; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."Indicator" (
    "Id" integer NOT NULL,
    "Name" text,
    "CategoryId" integer,
    "Direction" integer,
    "Description" text,
    "Name_hi" text,
    "Description_hi" text,
    "GOI" text,
    "GOI_ABV" text,
    "GOI_hi" text,
    "GOI_ABV_hi" text
);


ALTER TABLE public."Indicator" OWNER TO dbuser;

--
-- Name: IndicatorAc; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."IndicatorAc" (
    "IndicatorId" integer,
    "AcId" integer,
    "Prevalence" numeric(20,2),
    "AcPrevalenceRank" integer,
    "PrevalenceDecile" integer,
    "Headcount" numeric,
    "AcHeadcountRank" integer,
    "HeadcountDecile" integer,
    "PrevalenceChange" numeric(20,2),
    "PrevalenceChangeRank" integer,
    "PrevalenceChangeCategory" integer,
    "Year" integer
);


ALTER TABLE public."IndicatorAc" OWNER TO dbuser;

--
-- Name: IndicatorCategories; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."IndicatorCategories" (
    "IndicatorId" smallint NOT NULL,
    "CategoryId" smallint NOT NULL
);


ALTER TABLE public."IndicatorCategories" OWNER TO dbuser;

--
-- Name: IndicatorChange; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."IndicatorChange" (
    "IndicatorId" integer,
    "PrevalenceChangeId" integer,
    "PrevalenceChangeCutoffs" numeric(20,2),
    "ChangeHex" character varying(100)
);


ALTER TABLE public."IndicatorChange" OWNER TO dbuser;

--
-- Name: IndicatorChangeAc; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."IndicatorChangeAc" (
    "IndicatorId" integer,
    "PrevalenceChangeId" integer,
    "PrevalenceChangeCutoffs" numeric(20,2),
    "ChangeHex" character varying(100)
);


ALTER TABLE public."IndicatorChangeAc" OWNER TO dbuser;

--
-- Name: IndicatorChangePc; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."IndicatorChangePc" (
    "IndicatorId" integer,
    "PrevalenceChangeId" integer,
    "PrevalenceChangeCutoffs" numeric(20,2),
    "ChangeHex" character varying(100)
);


ALTER TABLE public."IndicatorChangePc" OWNER TO dbuser;

--
-- Name: IndicatorDeciles; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."IndicatorDeciles" (
    "Id" integer NOT NULL,
    "IndicatorId" integer,
    "PrevalenceDecile" integer,
    "PrevalenceDecileCutoffs" numeric(20,2),
    "PrevalenceDecileHex" character varying(100),
    "HeadcountDecile" integer,
    "HeadcountDecileCutoffs" integer,
    "HeadcountDecileHex" character varying(100),
    "Year" integer
);


ALTER TABLE public."IndicatorDeciles" OWNER TO dbuser;

--
-- Name: IndicatorDecilesAc; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."IndicatorDecilesAc" (
    "Id" integer NOT NULL,
    "IndicatorId" integer,
    "PrevalenceDecile" integer,
    "PrevalenceDecileCutoffs" numeric(20,2),
    "PrevalenceDecileHex" character varying(100),
    "Year" integer
);


ALTER TABLE public."IndicatorDecilesAc" OWNER TO dbuser;

--
-- Name: IndicatorDecilesAc_Id_seq; Type: SEQUENCE; Schema: public; Owner: dbuser
--

CREATE SEQUENCE public."IndicatorDecilesAc_Id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."IndicatorDecilesAc_Id_seq" OWNER TO dbuser;

--
-- Name: IndicatorDecilesAc_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dbuser
--

ALTER SEQUENCE public."IndicatorDecilesAc_Id_seq" OWNED BY public."IndicatorDecilesAc"."Id";


--
-- Name: IndicatorDecilesPc; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."IndicatorDecilesPc" (
    "Id" integer NOT NULL,
    "IndicatorId" integer,
    "PrevalenceDecile" integer,
    "PrevalenceDecileCutoffs" numeric(20,2),
    "PrevalenceDecileHex" character varying(100),
    "HeadcountDecile" integer,
    "HeadcountDecileCutoffs" integer,
    "HeadcountDecileHex" character varying(100),
    "Year" integer
);


ALTER TABLE public."IndicatorDecilesPc" OWNER TO dbuser;

--
-- Name: IndicatorDecilesPc_Id_seq; Type: SEQUENCE; Schema: public; Owner: dbuser
--

CREATE SEQUENCE public."IndicatorDecilesPc_Id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."IndicatorDecilesPc_Id_seq" OWNER TO dbuser;

--
-- Name: IndicatorDecilesPc_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dbuser
--

ALTER SEQUENCE public."IndicatorDecilesPc_Id_seq" OWNED BY public."IndicatorDecilesPc"."Id";


--
-- Name: IndicatorDecilesVillages; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."IndicatorDecilesVillages" (
    "Id" integer NOT NULL,
    "IndicatorId" integer,
    "PrevalenceDecile" integer,
    "PrevalenceDecileCutoffs" numeric(20,2),
    "PrevalenceDecileHex" character varying(100),
    "StateId" integer
);


ALTER TABLE public."IndicatorDecilesVillages" OWNER TO dbuser;

--
-- Name: IndicatorDecilesVillages_Id_seq; Type: SEQUENCE; Schema: public; Owner: dbuser
--

ALTER TABLE public."IndicatorDecilesVillages" ALTER COLUMN "Id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."IndicatorDecilesVillages_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: IndicatorDeciles_Id_seq; Type: SEQUENCE; Schema: public; Owner: dbuser
--

ALTER TABLE public."IndicatorDeciles" ALTER COLUMN "Id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."IndicatorDeciles_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: IndicatorDistrict; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."IndicatorDistrict" (
    "IndicatorId" integer,
    "DistrictId" integer,
    "Prevalence" numeric(20,2),
    "PrevalenceRank" integer,
    "PrevalenceDecile" integer,
    "HeadcountRank" integer,
    "HeadcountDecile" integer,
    "PrevalenceChange" numeric(20,2),
    "PrevalenceChangeRank" integer,
    "PrevalenceChangeCategory" integer,
    "Year" integer,
    "Headcount" numeric
);


ALTER TABLE public."IndicatorDistrict" OWNER TO dbuser;

--
-- Name: IndicatorIndia; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."IndicatorIndia" (
    "IndicatorId" integer,
    "ChangeAvailability" integer,
    "Prevalence" numeric(20,2),
    "PrevalenceChange" numeric(20,2),
    "Headcount" numeric,
    "Year" integer
);


ALTER TABLE public."IndicatorIndia" OWNER TO dbuser;

--
-- Name: IndicatorPc; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."IndicatorPc" (
    "IndicatorId" integer,
    "PcId" integer,
    "Prevalence" numeric(20,2),
    "PrevalenceRank" integer,
    "PrevalenceDecile" integer,
    "Headcount" numeric,
    "HeadcountRank" integer,
    "HeadcountDecile" integer,
    "PrevalenceChange" numeric(20,2),
    "PrevalenceChangeRank" integer,
    "PrevalenceChangeCategory" integer,
    "Year" integer
);


ALTER TABLE public."IndicatorPc" OWNER TO dbuser;

--
-- Name: IndicatorState; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."IndicatorState" (
    "StateId" integer,
    "IndicatorId" integer,
    "Prevalence" numeric(20,2),
    "PrevalenceChange" numeric(20,2),
    "Headcount" numeric,
    "Year" integer
);


ALTER TABLE public."IndicatorState" OWNER TO dbuser;

--
-- Name: IndicatorVillage; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."IndicatorVillage" (
    "IndicatorId" integer,
    "VillageId" integer,
    "Prevalence" numeric(20,2),
    "PrevalenceRank" integer,
    "PrevalenceDecile" integer,
    "Headcount" numeric,
    "HeadcountRank" integer,
    "HeadcountDecile" integer,
    "PrevalenceChange" numeric(20,2),
    "PrevalenceChangeRank" integer,
    "PrevalenceChangeCategory" integer,
    "Year" integer
);


ALTER TABLE public."IndicatorVillage" OWNER TO dbuser;

--
-- Name: Indicators; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."Indicators" (
    id integer NOT NULL,
    "Name" character varying NOT NULL,
    "SourceId" smallint NOT NULL,
    "Definition" text,
    "ReadingStrategy" smallint DEFAULT 0 NOT NULL,
    "ExternalId" integer NOT NULL
);


ALTER TABLE public."Indicators" OWNER TO dbuser;

--
-- Name: PcDemographics; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."PcDemographics" (
    "Id" integer NOT NULL,
    "PcId" integer NOT NULL,
    "Population" integer NOT NULL,
    "Density" integer NOT NULL,
    "Female" integer NOT NULL,
    "Male" integer NOT NULL,
    "Urban" integer NOT NULL,
    "Literate" integer NOT NULL
);


ALTER TABLE public."PcDemographics" OWNER TO dbuser;

--
-- Name: PcDemographics_Id_seq; Type: SEQUENCE; Schema: public; Owner: dbuser
--

ALTER TABLE public."PcDemographics" ALTER COLUMN "Id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."PcDemographics_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: PcMetrics; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."PcMetrics" (
    "GeoId" character varying(12),
    "Year" smallint NOT NULL,
    "Value" numeric,
    "StateId" integer,
    id integer NOT NULL,
    "TypedIndicatorId" smallint
);


ALTER TABLE public."PcMetrics" OWNER TO dbuser;

--
-- Name: PcMeasurements_id_seq; Type: SEQUENCE; Schema: public; Owner: dbuser
--

CREATE SEQUENCE public."PcMeasurements_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."PcMeasurements_id_seq" OWNER TO dbuser;

--
-- Name: PcMeasurements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dbuser
--

ALTER SEQUENCE public."PcMeasurements_id_seq" OWNED BY public."PcMetrics".id;


--
-- Name: PcUnits; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."PcUnits" (
    "GeoId" character varying(12),
    "Name" text,
    "ParentId" smallint,
    "Id" integer,
    "Name_hi" text
);


ALTER TABLE public."PcUnits" OWNER TO dbuser;

--
-- Name: PrevalenceChange; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."PrevalenceChange" (
    "Id" integer NOT NULL,
    "Name" text,
    "Name_hi" text
);


ALTER TABLE public."PrevalenceChange" OWNER TO dbuser;

--
-- Name: Sources; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."Sources" (
    "Name" character varying NOT NULL,
    id integer NOT NULL
);


ALTER TABLE public."Sources" OWNER TO dbuser;

--
-- Name: Sources_id_seq; Type: SEQUENCE; Schema: public; Owner: dbuser
--

CREATE SEQUENCE public."Sources_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Sources_id_seq" OWNER TO dbuser;

--
-- Name: Sources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dbuser
--

ALTER SEQUENCE public."Sources_id_seq" OWNED BY public."Sources".id;


--
-- Name: StateUnits; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."StateUnits" (
    "GeoId" character varying(12),
    "Name" text,
    "Id" integer,
    "Abbreviation" character varying,
    "Name_hi" text,
    "Abbreviation_hi" character varying
);


ALTER TABLE public."StateUnits" OWNER TO dbuser;

--
-- Name: TypedIndicators; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."TypedIndicators" (
    "IndicatorId" smallint NOT NULL,
    "Type" smallint NOT NULL,
    id integer NOT NULL
);


ALTER TABLE public."TypedIndicators" OWNER TO dbuser;

--
-- Name: TypedIndicators_id_seq; Type: SEQUENCE; Schema: public; Owner: dbuser
--

CREATE SEQUENCE public."TypedIndicators_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."TypedIndicators_id_seq" OWNER TO dbuser;

--
-- Name: TypedIndicators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dbuser
--

ALTER SEQUENCE public."TypedIndicators_id_seq" OWNED BY public."TypedIndicators".id;


--
-- Name: VillageDemographics; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."VillageDemographics" (
    "Id" integer NOT NULL,
    "VillageId" integer NOT NULL,
    "Population" integer NOT NULL,
    "Density" integer NOT NULL,
    "Female" integer NOT NULL,
    "Male" integer NOT NULL,
    "Urban" integer NOT NULL,
    "Literate" integer NOT NULL
);


ALTER TABLE public."VillageDemographics" OWNER TO dbuser;

--
-- Name: VillageDemographics_Id_seq; Type: SEQUENCE; Schema: public; Owner: dbuser
--

ALTER TABLE public."VillageDemographics" ALTER COLUMN "Id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."VillageDemographics_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: VillageMetrics; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."VillageMetrics" (
    "VillageId" integer NOT NULL,
    "DistrictId" integer NOT NULL,
    "IndicatorId" smallint NOT NULL,
    "TypeId" smallint NOT NULL,
    "Year" smallint NOT NULL,
    "Percentage" real,
    "Count" integer,
    "PHM" real
)
PARTITION BY LIST ("Year");


ALTER TABLE public."VillageMetrics" OWNER TO dbuser;

--
-- Name: VillageMetrics2016; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."VillageMetrics2016" (
    "VillageId" integer NOT NULL,
    "DistrictId" integer NOT NULL,
    "IndicatorId" smallint NOT NULL,
    "TypeId" smallint NOT NULL,
    "Year" smallint NOT NULL,
    "Percentage" real,
    "Count" integer,
    "PHM" real
);


ALTER TABLE public."VillageMetrics2016" OWNER TO dbuser;

--
-- Name: VillageMetrics2020; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."VillageMetrics2020" (
    "VillageId" integer NOT NULL,
    "DistrictId" integer NOT NULL,
    "IndicatorId" smallint NOT NULL,
    "TypeId" smallint NOT NULL,
    "Year" smallint NOT NULL,
    "Percentage" real,
    "Count" integer,
    "PHM" real
);


ALTER TABLE public."VillageMetrics2020" OWNER TO dbuser;

--
-- Name: VillageUnits; Type: TABLE; Schema: public; Owner: dbuser
--

CREATE TABLE public."VillageUnits" (
    "Id" integer NOT NULL,
    "GeoId" character varying(12),
    "Name" text,
    "DistrictId" smallint,
    "Name_hi" text
);


ALTER TABLE public."VillageUnits" OWNER TO dbuser;

--
-- Name: VillageUnits_id_seq1; Type: SEQUENCE; Schema: public; Owner: dbuser
--

CREATE SEQUENCE public."VillageUnits_id_seq1"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."VillageUnits_id_seq1" OWNER TO dbuser;

--
-- Name: VillageUnits_id_seq1; Type: SEQUENCE OWNED BY; Schema: public; Owner: dbuser
--

ALTER SEQUENCE public."VillageUnits_id_seq1" OWNED BY public."VillageUnits"."Id";


--
-- Name: indicators_id_seq; Type: SEQUENCE; Schema: public; Owner: dbuser
--

CREATE SEQUENCE public.indicators_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.indicators_id_seq OWNER TO dbuser;

--
-- Name: indicators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dbuser
--

ALTER SEQUENCE public.indicators_id_seq OWNED BY public."Indicators".id;


--
-- Name: VillageMetrics2016; Type: TABLE ATTACH; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."VillageMetrics" ATTACH PARTITION public."VillageMetrics2016" FOR VALUES IN ('2016');


--
-- Name: VillageMetrics2020; Type: TABLE ATTACH; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."VillageMetrics" ATTACH PARTITION public."VillageMetrics2020" FOR VALUES IN ('2020');


--
-- Name: Categories id; Type: DEFAULT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."Categories" ALTER COLUMN id SET DEFAULT nextval('public."Categories_id_seq"'::regclass);


--
-- Name: DistrictMetrics id; Type: DEFAULT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."DistrictMetrics" ALTER COLUMN id SET DEFAULT nextval('public."DistrictMeasurements_id_seq"'::regclass);


--
-- Name: IndicatorDecilesAc Id; Type: DEFAULT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."IndicatorDecilesAc" ALTER COLUMN "Id" SET DEFAULT nextval('public."IndicatorDecilesAc_Id_seq"'::regclass);


--
-- Name: IndicatorDecilesPc Id; Type: DEFAULT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."IndicatorDecilesPc" ALTER COLUMN "Id" SET DEFAULT nextval('public."IndicatorDecilesPc_Id_seq"'::regclass);


--
-- Name: Indicators id; Type: DEFAULT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."Indicators" ALTER COLUMN id SET DEFAULT nextval('public.indicators_id_seq'::regclass);


--
-- Name: PcMetrics id; Type: DEFAULT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."PcMetrics" ALTER COLUMN id SET DEFAULT nextval('public."PcMeasurements_id_seq"'::regclass);


--
-- Name: Sources id; Type: DEFAULT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."Sources" ALTER COLUMN id SET DEFAULT nextval('public."Sources_id_seq"'::regclass);


--
-- Name: TypedIndicators id; Type: DEFAULT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."TypedIndicators" ALTER COLUMN id SET DEFAULT nextval('public."TypedIndicators_id_seq"'::regclass);


--
-- Name: VillageUnits Id; Type: DEFAULT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."VillageUnits" ALTER COLUMN "Id" SET DEFAULT nextval('public."VillageUnits_id_seq1"'::regclass);


--
-- Name: AcMetrics AcMetrics_pkey; Type: CONSTRAINT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."AcMetrics"
    ADD CONSTRAINT "AcMetrics_pkey" PRIMARY KEY ("AcId", "TypedIndicatorId", "Year");


--
-- Name: GlobalConfig GlobalConfig_Name_key; Type: CONSTRAINT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."GlobalConfig"
    ADD CONSTRAINT "GlobalConfig_Name_key" UNIQUE ("Name");


--
-- Name: IndicatorDecilesAc IndicatorDecilesAc_pkey; Type: CONSTRAINT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."IndicatorDecilesAc"
    ADD CONSTRAINT "IndicatorDecilesAc_pkey" PRIMARY KEY ("Id");


--
-- Name: IndicatorDecilesPc IndicatorDecilesPc_pkey; Type: CONSTRAINT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."IndicatorDecilesPc"
    ADD CONSTRAINT "IndicatorDecilesPc_pkey" PRIMARY KEY ("Id");


--
-- Name: PcMetrics PcMeasurements_pkey; Type: CONSTRAINT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."PcMetrics"
    ADD CONSTRAINT "PcMeasurements_pkey" PRIMARY KEY (id);


--
-- Name: TypedIndicators TypedIndicators_pkey; Type: CONSTRAINT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."TypedIndicators"
    ADD CONSTRAINT "TypedIndicators_pkey" PRIMARY KEY (id);


--
-- Name: Urls Urls_pkey; Type: CONSTRAINT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."Urls"
    ADD CONSTRAINT "Urls_pkey" PRIMARY KEY ("Key");


--
-- Name: VillageUnits VillageUnits_pkey1; Type: CONSTRAINT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."VillageUnits"
    ADD CONSTRAINT "VillageUnits_pkey1" PRIMARY KEY ("Id");


--
-- Name: Categories categories_pk; Type: CONSTRAINT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."Categories"
    ADD CONSTRAINT categories_pk PRIMARY KEY (id);


--
-- Name: DistrictMetrics districtmeasurements_pk; Type: CONSTRAINT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."DistrictMetrics"
    ADD CONSTRAINT districtmeasurements_pk PRIMARY KEY (id);


--
-- Name: Indicator indicator_id; Type: CONSTRAINT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."Indicator"
    ADD CONSTRAINT indicator_id PRIMARY KEY ("Id");


--
-- Name: Indicators indicators_pkey; Type: CONSTRAINT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."Indicators"
    ADD CONSTRAINT indicators_pkey PRIMARY KEY (id);


--
-- Name: Sources sources_pk; Type: CONSTRAINT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."Sources"
    ADD CONSTRAINT sources_pk PRIMARY KEY (id);


--
-- Name: IndicatorState_StateId_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX "IndicatorState_StateId_idx" ON public."IndicatorState" USING btree ("StateId");


--
-- Name: IndicatorState_indId_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX "IndicatorState_indId_idx" ON public."IndicatorState" USING btree ("IndicatorId");


--
-- Name: district_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX district_idx ON ONLY public."VillageMetrics" USING btree ("DistrictId", "IndicatorId") INCLUDE ("VillageId", "Percentage", "Count", "PHM");


--
-- Name: VillageMetrics2016_DistrictId_IndicatorId_VillageId_Percent_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX "VillageMetrics2016_DistrictId_IndicatorId_VillageId_Percent_idx" ON public."VillageMetrics2016" USING btree ("DistrictId", "IndicatorId") INCLUDE ("VillageId", "Percentage", "Count", "PHM");


--
-- Name: village_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX village_idx ON ONLY public."VillageMetrics" USING btree ("VillageId") INCLUDE ("IndicatorId", "Percentage", "Count", "PHM");


--
-- Name: VillageMetrics2016_VillageId_IndicatorId_Percentage_Count_P_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX "VillageMetrics2016_VillageId_IndicatorId_Percentage_Count_P_idx" ON public."VillageMetrics2016" USING btree ("VillageId") INCLUDE ("IndicatorId", "Percentage", "Count", "PHM");


--
-- Name: VillageMetrics2020_DistrictId_IndicatorId_VillageId_Percent_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX "VillageMetrics2020_DistrictId_IndicatorId_VillageId_Percent_idx" ON public."VillageMetrics2020" USING btree ("DistrictId", "IndicatorId") INCLUDE ("VillageId", "Percentage", "Count", "PHM");


--
-- Name: VillageMetrics2020_VillageId_IndicatorId_Percentage_Count_P_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX "VillageMetrics2020_VillageId_IndicatorId_Percentage_Count_P_idx" ON public."VillageMetrics2020" USING btree ("VillageId") INCLUDE ("IndicatorId", "Percentage", "Count", "PHM");


--
-- Name: district_id_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX district_id_idx ON public."DistrictUnits" USING btree ("Id");


--
-- Name: district_name_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX district_name_idx ON public."DistrictUnits" USING btree ("Name" varchar_pattern_ops);


--
-- Name: idx_ac_units; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX idx_ac_units ON public."AcUnits" USING btree ("Id");


--
-- Name: idx_deciles_indicator; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX idx_deciles_indicator ON public."IndicatorDeciles" USING btree ("IndicatorId");


--
-- Name: idx_villageunits_districtid; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX idx_villageunits_districtid ON public."VillageUnits" USING btree ("DistrictId");


--
-- Name: idx_villageunits_id; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX idx_villageunits_id ON public."VillageUnits" USING btree ("Id");


--
-- Name: indicatorac_acid_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX indicatorac_acid_idx ON public."IndicatorAc" USING btree ("AcId");


--
-- Name: indicatorac_indid_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX indicatorac_indid_idx ON public."IndicatorAc" USING btree ("IndicatorId");


--
-- Name: indicatordistrict_districtid_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX indicatordistrict_districtid_idx ON public."IndicatorDistrict" USING btree ("DistrictId");


--
-- Name: indicatordistrict_indid_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX indicatordistrict_indid_idx ON public."IndicatorDistrict" USING btree ("IndicatorId");


--
-- Name: indicatorid_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX indicatorid_idx ON public."IndicatorVillage" USING btree ("IndicatorId");


--
-- Name: indicatorindia_indid_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX indicatorindia_indid_idx ON public."IndicatorIndia" USING btree ("IndicatorId");


--
-- Name: indicatorpc_indid_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX indicatorpc_indid_idx ON public."IndicatorPc" USING btree ("IndicatorId");


--
-- Name: indicatorpc_pcid_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX indicatorpc_pcid_idx ON public."IndicatorPc" USING btree ("PcId");


--
-- Name: pcdemo_pcid_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX pcdemo_pcid_idx ON public."PcDemographics" USING btree ("PcId");


--
-- Name: village_indicators; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX village_indicators ON public."IndicatorVillage" USING btree ("VillageId", "IndicatorId");


--
-- Name: village_name_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX village_name_idx ON public."VillageUnits" USING btree ("Name" varchar_pattern_ops);


--
-- Name: villageid_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX villageid_idx ON public."IndicatorVillage" USING btree ("VillageId");


--
-- Name: villdemo_villageid_idx; Type: INDEX; Schema: public; Owner: dbuser
--

CREATE INDEX villdemo_villageid_idx ON public."VillageDemographics" USING btree ("VillageId");


--
-- Name: VillageMetrics2016_DistrictId_IndicatorId_VillageId_Percent_idx; Type: INDEX ATTACH; Schema: public; Owner: dbuser
--

ALTER INDEX public.district_idx ATTACH PARTITION public."VillageMetrics2016_DistrictId_IndicatorId_VillageId_Percent_idx";


--
-- Name: VillageMetrics2016_VillageId_IndicatorId_Percentage_Count_P_idx; Type: INDEX ATTACH; Schema: public; Owner: dbuser
--

ALTER INDEX public.village_idx ATTACH PARTITION public."VillageMetrics2016_VillageId_IndicatorId_Percentage_Count_P_idx";


--
-- Name: VillageMetrics2020_DistrictId_IndicatorId_VillageId_Percent_idx; Type: INDEX ATTACH; Schema: public; Owner: dbuser
--

ALTER INDEX public.district_idx ATTACH PARTITION public."VillageMetrics2020_DistrictId_IndicatorId_VillageId_Percent_idx";


--
-- Name: VillageMetrics2020_VillageId_IndicatorId_Percentage_Count_P_idx; Type: INDEX ATTACH; Schema: public; Owner: dbuser
--

ALTER INDEX public.village_idx ATTACH PARTITION public."VillageMetrics2020_VillageId_IndicatorId_Percentage_Count_P_idx";


--
-- Name: IndicatorCategories category_fk; Type: FK CONSTRAINT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."IndicatorCategories"
    ADD CONSTRAINT category_fk FOREIGN KEY ("CategoryId") REFERENCES public."Categories"(id);


--
-- Name: IndicatorCategories indicator_fk; Type: FK CONSTRAINT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."IndicatorCategories"
    ADD CONSTRAINT indicator_fk FOREIGN KEY ("IndicatorId") REFERENCES public."Indicators"(id);


--
-- Name: Indicators source_fk; Type: FK CONSTRAINT; Schema: public; Owner: dbuser
--

ALTER TABLE ONLY public."Indicators"
    ADD CONSTRAINT source_fk FOREIGN KEY ("SourceId") REFERENCES public."Sources"(id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: azure_pg_admin
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

