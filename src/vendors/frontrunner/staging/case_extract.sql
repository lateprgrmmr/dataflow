SELECT
    an.run_id,
    an.data->>'LocationId' AS branch_id,
    an.data->>'Client_Rec_Id' AS external_id,
    an.data->>'Contract_No' AS case_number,
    CASE
        WHEN an.data->>'Date_of_Death' IS NULL THEN 'pre-need'
        WHEN an.data->>'PreNeed' = 'Y' THEN 'pre-need'
        ELSE 'at-need'
    END AS case_type,
    an.data->>'Contract_Date' AS created_time,
    an.data->>'Date_of_Birth' AS date_of_birth,
    an.data->>'Date_of_Death' AS date_of_death,
    an.data->>'Time_of_Death' AS time_of_death,
    an.data->>'Funeral_Director_Name' AS director,
    an.data->>'First' AS fname,
    an.data->>'Middle' AS mname,
    an.data->>'Last' AS lname,
    an.data->>'Suffix' AS suffix,
    an.data->>'MaidenName' AS maiden_name,
    an.data->>'EncSSN' AS ssn,
    an.data->>'Sex' AS gender,
    CONCAT_WS('; ', NULLIF(an.data->>'Nickname', ''), NULLIF(an.data->>'KnownAs_FullName', '')) AS aka,
    '' AS memorial_service,
    an.data->>'Native_of' AS birth_city,
    an.data->>'Native_of_State' AS birth_state,
    '' AS birth_country,
    an.data->>'City_of_Death' AS death_city,
    an.data->>'State_of_Death' AS death_state,
    an.data->>'County_of_Death' AS death_county,
    an.data->>'Country_of_Death' AS death_country,
    an.data->>'Address_of_Death' AS death_address_line_1,
    an.data->>'Zipcode_of_Death' AS death_zipcode,
    LOWER(COALESCE(NULLIF(an.data->>'Hospital_Status', ''), NULLIF(an.data->>'NonHospitalStatus', ''))) AS death_location,
    an.data->>'Place_of_Death' AS death_location_name,
    an.data->>'Physician' AS physician_name,
    '' AS physician_fax_number,
    '' AS physician_phone_number,
    an.data->>'City_of_Residence' AS residence_city,
    an.data->>'State_of_Residence' AS residence_state,
    an.data->>'County_of_Residence' AS residence_county,
    an.data->>'Country_of_Residence' AS residence_country,
    an.data->>'Street_of_Residence' AS residence_address_line_1,
    an.data->>'Zipcode_of_Residence' AS residence_zipcode,
    an.data->>'City_Limits' AS inside_city_limits,
    '' AS years_in_county,
    an.data->>'Race' AS race,
    an.data->>'Origin' AS ancestry,
    an.data->>'HispanicOrigin' AS hispanic_origin,
    an.data->>'TribalReservationName' AS tribal_reservation_name,
    an.data->>'OtherHispanc' AS other_hispanic_origin,
    father.data->>'City_of_Birth' AS father_birth_city,
    father.data->>'State_of_Birth' AS father_birth_state,
    father.data->>'Country_of_Birth' AS father_birth_country,
    an.data->>'Fathers_Birthplace' AS father_birthplace,
    mother.data->>'City_of_Birth' AS mother_birth_city,
    mother.data->>'State_of_Birth' AS mother_birth_state,
    mother.data->>'Country_of_Birth' AS mother_birth_country,
    an.data->>'Mothers_Birthplace' AS mother_birthplace,
    COALESCE(NULLIF(mother.data->>'MaidenName', ''), NULLIF(an.data->>'Mothers_Maiden', '')) AS mother_maiden_name,
    an.data->>'Date_of_Marriage' AS date_of_marriage,
    an.data->>'Marital_Status' AS marital_status,
    COALESCE(NULLIF(an.data->>'Spouses_Maiden', ''), spouse.data->>'MaidenName') AS spouse_maiden_name,
    CASE
        WHEN NULLIF(an.data->>'Veteran', '') IS NOT NULL THEN an.data->>'Veteran'
        WHEN NULLIF(an.data->>'ServiceBranch', '') IS NOT NULL THEN 'Yes'
    END AS veteran,
    LOWER(an.data->>'ServiceBranch') AS service_branch,
    COALESCE(
        NULLIF(an.data->>'HighestRank', ''),
        NULLIF(an.data->>'Rank1', ''),
        NULLIF(an.data->>'Rank2', ''),
        NULLIF(an.data->>'Rank3', ''), '') AS highest_rank,
    COALESCE(
        NULLIF((an.data->>'MilitaryServiceNumber'), '') || 
        CASE WHEN NULLIF((an.data->>'MilitaryServiceNumber2'), '') IS NOT NULL THEN ', ' || (an.data->>'MilitaryServiceNumber2') ELSE '' END ||
        CASE WHEN NULLIF((an.data->>'MilitaryServiceNumber3'), '') IS NOT NULL THEN ', ' || (an.data->>'MilitaryServiceNumber3') ELSE '' END,
        ''
    ) AS military_service_number,
    an.data->>'DateEnteredService' AS date_entered_service,
    an.data->>'DateSeparatedService' AS date_separated_service,
    CONCAT_WS(', ', NULLIF(TRIM(an.data->>'ServiceDetails'), ''), NULLIF(TRIM(an.data->>'MilitaryHonorsInfo'), '')) AS military_honors,
    an.data->>'MilitaryDeathDueToService' AS military_death_due_to_service,
    an.data->>'Education' AS education,
    CONCAT_WS('; ',
        NULLIF(an.data->>'EducationElementary', ''),
        NULLIF(an.data->>'EducationSecondary', ''),
        NULLIF(an.data->>'EducationElemSec', ''),
        NULLIF(an.data->>'EducationCollege', ''),
        NULLIF(an.data->>'EducationDetails', '')
    ) AS education_history,
    '' AS retired_in_year,
    an.data->>'Employer' AS current_employer,
    an.data->>'Occupation' AS normal_occupation,
    '' AS employed_options,
    an.data->>'Industry' AS normal_occupation_industry,
    LOWER(an.data->>'Disposition') AS disposition,
    '' AS disposition_other,
    COALESCE(NULLIF(an.data->>'Disposition_Date', ''), NULLIF(an.data->>'IntermentDate', '')) AS disposition_date,
    CONCAT_WS('; ',
        CASE WHEN NULLIF(an.data->>'CemeterySection', '') IS NOT NULL THEN 'Section: ' || (an.data->>'CemeterySection') ELSE NULL END,
        CASE WHEN NULLIF(an.data->>'CemeteryBlock', '') IS NOT NULL THEN 'Block: ' || (an.data->>'CemeteryBlock') ELSE NULL END,
        CASE WHEN NULLIF(an.data->>'CemeteryRange', '') IS NOT NULL THEN 'Range: ' || (an.data->>'CemeteryRange') ELSE NULL END,
        CASE WHEN NULLIF(an.data->>'CemeteryLot', '') IS NOT NULL THEN 'Lot: ' || (an.data->>'CemeteryLot') ELSE NULL END,
        CASE WHEN NULLIF(an.data->>'CemeteryGate', '') IS NOT NULL THEN 'Gate: ' || (an.data->>'CemeteryGate') ELSE NULL END,
        CASE WHEN NULLIF(an.data->>'CemeteryRow', '') IS NOT NULL THEN 'Row: ' || (an.data->>'CemeteryRow') ELSE NULL END,
        CASE WHEN NULLIF(an.data->>'CemeteryPlot', '') IS NOT NULL THEN 'Plot: ' || (an.data->>'CemeteryPlot') ELSE NULL END
    ) AS cemetery_property_details,
    NULLIF(an.data->>'PlotOwner', '') IS NOT NULL AS plot_owner,
    an.data->>'CemeteryCity' AS cemetery_city,
    an.data->>'CemeteryState' AS cemetery_state,
    an.data->>'CemeteryCounty' AS cemetery_county,
    an.data->>'CemeteryAddress' AS cemetery_address,
    an.data->>'CemeteryZipcode' AS cemetery_zipcode,
    an.data->>'Interment' AS interment,
    CONCAT_WS('|',
        NULLIF(an.data->>'Notes', ''),
        NULLIF(custom_questions.all_custom_questions, ''),
        NULLIF(TRIM(military_service.service_entered), ''),
        NULLIF(TRIM(military_service.service_entered_place), ''),
        NULLIF(TRIM(military_service.service_released), ''),
        NULLIF(TRIM(military_service.service_released_place), ''),
        NULLIF(TRIM(military_service.war_campaign), ''),
        NULLIF(TRIM(military_service.discharge_type), '')
    ) AS case_note
    
FROM staging.frontrunner_atneed_client_info an
LEFT JOIN (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY client_rec_id ORDER BY run_id) AS rn
        FROM staging.frontrunner_client_contacts
        WHERE LOWER(TRIM(relationship)) IN ('wife', 'spouse', 'widow')
    ) AS spouse
    ON an.run_id = spouse.run_id
    AND an.client_rec_id = spouse.client_rec_id
    AND spouse.rn = 1
LEFT JOIN (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY client_rec_id ORDER BY run_id) AS rn
    FROM staging.frontrunner_client_contacts
    WHERE LOWER(relationship) IN ('father')
) AS father
    ON an.run_id = father.run_id
    AND an.client_rec_id = father.client_rec_id
    AND father.rn = 1
LEFT JOIN (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY client_rec_id ORDER BY run_id) AS rn
    FROM staging.frontrunner_client_contacts
    WHERE LOWER(relationship) IN ('mother')
) AS mother
    ON an.run_id = mother.run_id
    AND an.client_rec_id = mother.client_rec_id
    AND mother.rn = 1
LEFT JOIN (
    SELECT
        od.run_id,
        od.client_rec_id,
        STRING_AGG((of.data->>'FieldNameDataEntry') || ': ' || (od.data->>'Value'), ' | ') AS all_custom_questions
    FROM staging.frontrunner_optional_data AS od
    JOIN staging.frontrunner_optional_fields AS of ON od.data->>'OptionalFieldID' = of.id
    GROUP BY od.run_id, od.client_rec_id
) AS custom_questions
ON an.run_id = custom_questions.run_id
AND an.client_rec_id = custom_questions.client_rec_id
LEFT JOIN (
    SELECT
        client_rec_id,
        CASE WHEN m.data->>'DateEnteredService' IS NOT NULL AND m.data->>'DateEnteredService' != ''
            THEN 'Service Entered Date: ' || (m.data->>'DateEnteredService')
        ELSE '' END AS service_entered,
        CASE WHEN m.data->>'PlaceEnteredService' IS NOT NULL AND m.data->>'PlaceEnteredService' != ''
            THEN 'Service Entered Place: ' || (m.data->>'PlaceEnteredService')
        ELSE '' END AS service_entered_place,
        CASE WHEN m.data->>'DateSeparatedService' IS NOT NULL AND m.data->>'DateSeparatedService' != ''
            THEN 'Service Released Date: ' || (m.data->>'DateSeparatedService')   
        ELSE '' END AS service_released,
        CASE WHEN m.data->>'PlaceSeparatedService' IS NOT NULL AND m.data->>'PlaceSeparatedService' != ''
            THEN 'Service Released Place: ' || (m.data->>'PlaceSeparatedService')
        ELSE '' END AS service_released_place,
        CASE WHEN m.data->>'War' IS NOT NULL AND m.data->>'War' != ''
            THEN 'War: ' || (m.data->>'War')
        ELSE '' END AS war_campaign,
        CASE WHEN m.data->>'Type_of_Discharge' IS NOT NULL AND m.data->>'Type_of_Discharge' != ''
            THEN 'Discharge Type: ' || (m.data->>'Type_of_Discharge')   
        ELSE '' END AS discharge_type
    FROM staging.frontrunner_atneed_client_info AS m
) AS military_service
ON an.client_rec_id = military_service.client_rec_id
-- WHERE an.run_id = $1
WHERE an.client_rec_id = '2063'
-- TODO: add pre-need cases
;