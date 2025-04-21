WITH dc1 AS (
    SELECT
        raw_data,
        logical_table_name,
        raw_data->>'Case Number' AS case_number
    FROM staging.migration_raw_data AS raw
    WHERE logical_table_name = 'dc1'
), dc2 AS (
    SELECT
        raw_data,
        logical_table_name,
        raw_data->>'Case Identifier' AS case_number
    FROM staging.migration_raw_data AS raw
    WHERE logical_table_name = 'dc2'
), vet AS (
    SELECT
        raw_data,
        raw_data->>'Case Number' AS case_number
    FROM staging.migration_raw_data AS raw
    WHERE logical_table_name = 'vet'
)

SELECT
    COALESCE(TRIM(dc2.raw_data->>'Case Branch'), '') AS "Case Branch",
    COALESCE(TRIM(dc2.raw_data->>'Case Branch'), '') AS "branch_id",
    COALESCE(TRIM(dc1.raw_data->>'Case Number'), '') AS "case_number",
    COALESCE(dc1.raw_data->>'Case Types', '') AS "case_type",
    COALESCE(dc1.raw_data->>'Case Created At', '') AS "created_time",
    COALESCE(dc1.raw_data->>'Decedent Birth Date', '') AS "date_of_birth",
    COALESCE(dc1.raw_data->>'Decedent Date of Death', '') AS "date_of_death",
    COALESCE(dc1.raw_data->>'Decedent Time of Death', '') AS "time_of_death",
    COALESCE(dc1.raw_data->>'Case Assigned To', '') AS "Case Assigned To",
    '' AS "assignee.email",
    COALESCE(dc1.raw_data->>'Decedent First Name', 'Unknown') AS "fname",
    COALESCE(dc1.raw_data->>'Decedent Middle Name', '') AS "mname",
    COALESCE(dc1.raw_data->>'Decedent Last Name', 'Unknown') AS "lname",
    COALESCE(dc1.raw_data->>'Decedent Suffix', '') AS "suffix",
    '' AS "deathcertificate.about.birthLastName",
    COALESCE(dc2.raw_data->>'Decedent Gender', '') AS "deathcertificate.about.gender",
    COALESCE(dc2.raw_data->>'Decedent SSN', '') AS "deathcertificate.about.ssn",
    COALESCE(dc1.raw_data->>'Decedent Alternate Name', '') AS "deathcertificate.about.aka",
    CASE
        WHEN dc1.raw_data->>'Memorial Service - First' IS NOT NULL
        OR dc1.raw_data->>'Memorial Service - Second' IS NOT NULL
        OR dc1.raw_data->>'Memorial Service - Third' IS NOT NULL
        OR dc1.raw_data->>'Memorial Service - Fourth' IS NOT NULL THEN 'true'
        ELSE ''
    END AS "deathcertificate.about.hasMemorialService",
    COALESCE(dc1.raw_data->>'Decedent Birth City', '') AS "deathcertificate.life.birthPlace.city",
    COALESCE(dc1.raw_data->>'Decedent Birth State', '') AS "deathcertificate.life.birthPlace.state",
    COALESCE(dc1.raw_data->>'Decedent Birth Country', '') AS "deathcertificate.life.birthPlace.country",
    COALESCE(dc1.raw_data->>'Decedent Death City', '') AS "deathcertificate.life.deathPlace.city",
    COALESCE(dc1.raw_data->>'Decedent Death State', '') AS "deathcertificate.life.deathPlace.state",
    COALESCE(dc1.raw_data->>'Decedent Death County', '') AS "deathcertificate.life.deathPlace.county",
    COALESCE(dc1.raw_data->>'Decedent Death Country', '') AS "deathcertificate.life.deathPlace.country",
    COALESCE(dc1.raw_data->>'Decedent Death Address Line 1', '') AS "deathcertificate.life.deathPlace.address1",
    COALESCE(dc1.raw_data->>'Decedent Death Address Line 2', '') AS "deathcertificate.life.deathPlace.address2",
    COALESCE(dc1.raw_data->>'Decedent Death Zip', '') AS "deathcertificate.life.deathPlace.postalCode",
    COALESCE(dc2.raw_data->>'Decedent Location of Death Name', '') AS "deathcertificate.life.deathPlace.locationName",
    COALESCE(dc2.raw_data->>'Decedent Location of Death', '') AS "deathcertificate.life.deathLocation",
    COALESCE(dc1.raw_data->>'Pronounced By Full Name', '') AS "deathcertificate.life.physicianName",
    COALESCE(dc1.raw_data->>'Pronounced By Fax', '') AS "deathcertificate.life.physicianFaxNumber",
    COALESCE(
        dc1.raw_data->>'Pronounced By Primary Phone',
        dc1.raw_data->>'Pronounced By Secondary Phone',
        dc1.raw_data->>'Pronounced By Other Phone',
        ''
    ) AS "deathcertificate.life.physicianPhoneNumber",
    COALESCE(dc1.raw_data->>'Decedent Address City', '') AS "deathcertificate.life.residencePlace.city",
    COALESCE(dc1.raw_data->>'Decedent Address State', '') AS "deathcertificate.life.residencePlace.state",
    '' AS "deathcertificate.life.residencePlace.county",
    COALESCE(dc1.raw_data->>'Decedent Address Country', '') AS "deathcertificate.life.residencePlace.country",
    COALESCE(dc1.raw_data->>'Decedent Address Line 1', '') AS "deathcertificate.life.residencePlace.address1",
    COALESCE(dc1.raw_data->>'Decedent Address Line 2', '') AS "deathcertificate.life.residencePlace.address2",
    COALESCE(dc1.raw_data->>'Decedent Address Zip', '') AS "deathcertificate.life.residencePlace.postalCode",
    '' AS "deathcertificate.life.residencePlace.yearsInCounty",
    COALESCE(dc1.raw_data->>'Decedent Address Inside City Limits', '') AS "deathcertificate.life.residencePlace.insideCityLimits",
    COALESCE(dc1.raw_data->>'Decedent Race', '') AS "raw_race",
    COALESCE(dc1.raw_data->>'Decedent Ethnicity', '') AS "deathcertificate.race.hispanicOrigin",
    COALESCE(LOWER(dc1.raw_data->>'Decedent Citizenship'), '') AS "deathcertificate.race.isUsCitizen",
    '' AS "deathcertificate.race.ancestry",
    '' AS "deathcertificate.parents.fatherBirthPlace.city",
    '' AS "deathcertificate.parents.fatherBirthPlace.state",
    '' AS "deathcertificate.parents.fatherBirthPlace.country",
    '' AS "deathcertificate.parents.motherBirthPlace.city",
    '' AS "deathcertificate.parents.motherBirthPlace.state",
    '' AS "deathcertificate.parents.motherBirthPlace.country",
    '' AS "deathcertificate.marriage.marriageDate",
    COALESCE(dc1.raw_data->>'Decedent Marital Status', '') AS "deathcertificate.marriage.maritalStatus",
    '' AS "deathcertificate.marriage.marriagePlace.description",
    COALESCE(dc1.raw_data->>'Veteran', '') AS "deathcertificate.military.military",
    COALESCE(dc1.raw_data->>'Veteran Primary Branch of Service', '') AS "deathcertificate.military.militaryBranch",
    COALESCE(vet.raw_data->>'Military Serial Number', '') AS "deathcertificate.military.militaryServiceNumber",
    COALESCE(
        NULLIF(vet.raw_data->>'Date of Enlistment', ''), '0') AS "SrvcEnteredYear",
    COALESCE(
        NULLIF(vet.raw_data->>'Date of Discharge', ''), '0') AS "SrvcReleasedYear",
    COALESCE(vet.raw_data->>'Current Ranking', '') AS "deathcertificate.military.militaryRank",
    CASE
        WHEN vet.raw_data->>'Service-Connected Death' = '1' THEN 'true'
        ELSE ''
    END AS "deathcertificate.military.disabilityContributedToDeath",
    COALESCE(dc1.raw_data->>'Decedent Education', '') AS "deathcertificate.education.educationListOfOptions",
    '' AS "deathcertificate.education.educationHistory",
    '' AS "deathcertificate.workHistory.retiredInYear",
    COALESCE(dc1.raw_data->>'Decedent Employer', '') AS "deathcertificate.workHistory.currentEmployer",
    COALESCE(dc1.raw_data->>'Decedent Industry', '') AS "deathcertificate.workHistory.normalOccupationIndustry",
    COALESCE(dc1.raw_data->>'Decedent Occupation', '') AS "deathcertificate.workHistory.normalOccupation",
    CASE
        WHEN COALESCE(
            dc1.raw_data->>'Decedent Employer',
            dc1.raw_data->>'Decedent Industry',
            dc1.raw_data->>'Decedent Occupation',
            ''
        ) != '' THEN 'Employed'
        ELSE ''
    END AS "deathcertificate.workHistory.occupationListOfOptions",
    COALESCE(dc2.raw_data->>'Disposition Type', '') AS "deathcertificate.restingPlace.options",
    '' AS "deathcertificate.restingPlace.specifyOther",
    COALESCE(
        NULLIF(dc1.raw_data->>'Final Disposition', ''),
        NULLIF(dc2.raw_data->>'Disposition Notes', ''),
        ''
    ) AS "deathcertificate.restingPlace.dispositionPlace.locationName",
    COALESCE(dc2.raw_data->>'Disposition Date', '') AS "deathcertificate.restingPlace.dispositionDate",
    '' AS "deathcertificate.restingPlace.cemeteryPropertyDetails",
    COALESCE(dc2.raw_data->>'Disposition Address 1', '') AS "deathcertificate.restingPlace.dispositionPlace.address1",
    COALESCE(dc2.raw_data->>'Disposition Address 2', '') AS "deathcertificate.restingPlace.dispositionPlace.address2",
    COALESCE(dc2.raw_data->>'Disposition City', '') AS "deathcertificate.restingPlace.dispositionPlace.city",
    COALESCE(dc2.raw_data->>'Disposition State', '') AS "deathcertificate.restingPlace.dispositionPlace.state",
    '' AS "deathcertificate.restingPlace.dispositionPlace.county",
    COALESCE(dc2.raw_data->>'Disposition Zip', '') AS "deathcertificate.restingPlace.dispositionPlace.postalCode",
    COALESCE(dc2.raw_data->>'Disposition Country', '') AS "deathcertificate.restingPlace.dispositionPlace.country",
    TRIM(COALESCE(NULLIF(dc1.raw_data->>'All Notes (basic)', ''), '')) AS case_note -- Case Notes
FROM dc1
JOIN dc2
    ON dc1.case_number = dc2.case_number
LEFT JOIN vet
    ON dc1.case_number = vet.case_number
;