-- This SQL script reads some of the output tables of PrepAnalysis.R
-- and creates combined views of them for QGIS use.
--
-- NOTE: the table hcr_population must exist before running this script!
-- I have used a population dataset from Helsinki Region Infoshare at
-- https://hri.fi/data/en_GB/dataset/paakaupunkiseudun-vaestoennuste (I used
-- the file labeled 2012-2022), but the downloaded spreadsheet has to be
-- cleaned and imported manually; only the rows with totals are needed, and
-- I also renamed most columns. I used csvkit (https://csvkit.readthedocs.io/)
-- to import the cleaned spreadsheet and then executed the following commands
-- to further clean the table:
--
-- ALTER TABLE hcr_population ALTER "RegID" TYPE TEXT USING LPAD("RegID"::text, 10, '0');
-- ALTER TABLE hcr_population ALTER "RegName" TYPE TEXT USING ("RegName"::text);
-- ALTER TABLE hcr_population ALTER "AreaID" TYPE TEXT USING ("AreaID"::text);
-- ALTER TABLE hcr_population ALTER "MunID" TYPE TEXT USING LPAD("MunID"::text, 3, '0');
-- ALTER TABLE hcr_population ADD PRIMARY KEY("RegID");

DROP VIEW IF EXISTS res_agg_j_all_reg_pt_changes_2013_2015;
CREATE VIEW res_agg_j_all_reg_pt_changes_2013_2015 AS (
	SELECT * FROM (
		SELECT r.gid,
		CASE WHEN r.nimi<>'' THEN r.nimi ELSE 'Kauniainen' END AS nimi,
		r.geom,
		j1."MunID",
		j1."AreaID",
		j1."DistID",
		j1."Count" AS "C1",
		j1."Total" AS "F1",
		j2."Count" AS "C2",
		j2."Total" AS "F2",
		ROUND(CAST(j2."Total"-j1."Total" AS NUMERIC), 2) AS "FChange",
		j3."Total" AS "T1",
		j4."Total" AS "T2",
		ROUND(CAST(j4."Total"-j3."Total" AS NUMERIC)) AS "TChange",
		"Pop2012",
		"Pop2016",
		"Pop2016"-"Pop2012" AS "PopChange"
		FROM hcr_subregions r
		LEFT JOIN res_agg_j_all_reg_pt_ttyfreq_mun j1
			ON r.kokotun=j1."RegID" AND j1."TTM" = 2013
		LEFT JOIN res_agg_j_all_reg_pt_ttyfreq_mun j2
			ON r.kokotun=j2."RegID" AND j2."TTM" = 2015
		LEFT JOIN res_agg_j_all_reg_pt_mun j3
			ON r.kokotun=j3."RegID" AND j3."TTM" = 2013
		LEFT JOIN res_agg_j_all_reg_pt_mun j4
			ON r.kokotun=j4."RegID" AND j4."TTM" = 2015
		LEFT JOIN hcr_population p
			ON r.kokotun=p."RegID"
	) AS Q
	WHERE "FChange" IS NOT NULL AND "TChange" IS NOT NULL
);

DROP VIEW IF EXISTS res_agg_j_all_reg_pt_changes_2015_2018;
CREATE VIEW res_agg_j_all_reg_pt_changes_2015_2018 AS (
	SELECT * FROM (
		SELECT r.gid,
		CASE WHEN r.nimi<>'' THEN r.nimi ELSE 'Kauniainen' END AS nimi,
		r.geom,
		j1."MunID",
		j1."AreaID",
		j1."DistID",
		j1."Count" AS "C1",
		j1."Total" AS "F1",
		j2."Count" AS "C2",
		j2."Total" AS "F2",
		ROUND(CAST(j2."Total"-j1."Total" AS NUMERIC), 2) AS "FChange",
		j3."Total" AS "T1",
		j4."Total" AS "T2",
		ROUND(CAST(j4."Total"-j3."Total" AS NUMERIC)) AS "TChange",
		"Pop2016",
		"Pop2018",
		"Pop2018"-"Pop2016" AS "PopChange"
		FROM hcr_subregions r
		LEFT JOIN res_agg_j_all_reg_pt_ttyfreq_mun j1
			ON r.kokotun=j1."RegID" AND j1."TTM" = 2015
		LEFT JOIN res_agg_j_all_reg_pt_ttyfreq_mun j2
			ON r.kokotun=j2."RegID" AND j2."TTM" = 2018
		LEFT JOIN res_agg_j_all_reg_pt_mun j3
			ON r.kokotun=j3."RegID" AND j3."TTM" = 2015
		LEFT JOIN res_agg_j_all_reg_pt_mun j4
			ON r.kokotun=j4."RegID" AND j4."TTM" = 2018
		LEFT JOIN hcr_population p
			ON r.kokotun=p."RegID"
	) AS Q
	WHERE "FChange" IS NOT NULL AND "TChange" IS NOT NULL
);

DROP VIEW IF EXISTS res_agg_j_all_reg_car_changes_2013_2015;
CREATE VIEW res_agg_j_all_reg_car_changes_2013_2015 AS (
	SELECT * FROM (
		SELECT r.gid,
		CASE WHEN r.nimi<>'' THEN r.nimi ELSE 'Kauniainen' END AS nimi,
		r.geom,
		j1."MunID",
		j1."AreaID",
		j1."DistID",
		j1."Count" AS "C1",
		j1."Total" AS "F1",
		j2."Count" AS "C2",
		j2."Total" AS "F2",
		ROUND(CAST(j2."Total"-j1."Total" AS NUMERIC), 2) AS "FChange",
		j3."Total" AS "T1",
		j4."Total" AS "T2",
		ROUND(CAST(j4."Total"-j3."Total" AS NUMERIC)) AS "TChange",
		"Pop2012",
		"Pop2016",
		"Pop2016"-"Pop2012" AS "PopChange"
		FROM hcr_subregions r
		LEFT JOIN res_agg_j_all_reg_car_ttyfreq_mun j1
			ON r.kokotun=j1."RegID" AND j1."TTM" = 2013
		LEFT JOIN res_agg_j_all_reg_car_ttyfreq_mun j2
			ON r.kokotun=j2."RegID" AND j2."TTM" = 2015
		LEFT JOIN res_agg_j_all_reg_car_mun j3
			ON r.kokotun=j3."RegID" AND j3."TTM" = 2013
		LEFT JOIN res_agg_j_all_reg_car_mun j4
			ON r.kokotun=j4."RegID" AND j4."TTM" = 2015
		LEFT JOIN hcr_population p
			ON r.kokotun=p."RegID"
	) AS Q
	WHERE "FChange" IS NOT NULL AND "TChange" IS NOT NULL
);

DROP VIEW IF EXISTS res_agg_j_all_reg_car_changes_2015_2018;
CREATE VIEW res_agg_j_all_reg_car_changes_2015_2018 AS (
	SELECT * FROM (
		SELECT r.gid,
		CASE WHEN r.nimi<>'' THEN r.nimi ELSE 'Kauniainen' END AS nimi,
		r.geom,
		j1."MunID",
		j1."AreaID",
		j1."DistID",
		j1."Count" AS "C1",
		j1."Total" AS "F1",
		j2."Count" AS "C2",
		j2."Total" AS "F2",
		ROUND(CAST(j2."Total"-j1."Total" AS NUMERIC), 2) AS "FChange",
		j3."Total" AS "T1",
		j4."Total" AS "T2",
		ROUND(CAST(j4."Total"-j3."Total" AS NUMERIC)) AS "TChange",
		"Pop2016",
		"Pop2018",
		"Pop2018"-"Pop2016" AS "PopChange"
		FROM hcr_subregions r
		LEFT JOIN res_agg_j_all_reg_car_ttyfreq_mun j1
			ON r.kokotun=j1."RegID" AND j1."TTM" = 2015
		LEFT JOIN res_agg_j_all_reg_car_ttyfreq_mun j2
			ON r.kokotun=j2."RegID" AND j2."TTM" = 2018
		LEFT JOIN res_agg_j_all_reg_car_mun j3
			ON r.kokotun=j3."RegID" AND j3."TTM" = 2015
		LEFT JOIN res_agg_j_all_reg_car_mun j4
			ON r.kokotun=j4."RegID" AND j4."TTM" = 2018
		LEFT JOIN hcr_population p
			ON r.kokotun=p."RegID"
	) AS Q
	WHERE "FChange" IS NOT NULL AND "TChange" IS NOT NULL
);
