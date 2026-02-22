SELECT
    cc.run_id,
    cc.client_rec_id,
    COALESCE(an.data->>'Contract_No', pn.data->>'Contract_No') AS case_number,
    cc.data->>'FirstName' AS fname,
    cc.data->>'MiddleName' AS mname,
    cc.data->>'LastName' AS lname,
    cc.data->>'Suffix' AS suffix,
    cc.data->>'EmailAddr' AS email,
    cc.data->>'Phone1' AS phone,
    cc.relationship,
    cc.data->>'Address' AS address1,
    '' AS address2,
    cc.data->>'City' AS city,
    cc.data->>'State' AS state,
    cc.data->>'Zipcode' AS zip,
    CASE WHEN cc.data->>'InformantFlag' = '1' THEN TRUE ELSE FALSE END AS is_informant,
    CASE WHEN NULLIF(TRIM(cc.data->>'DOD'), '') IS NOT NULL THEN TRUE ELSE FALSE END AS is_deceased
FROM staging.frontrunner_client_contacts cc
LEFT JOIN staging.frontrunner_atneed_client_info an
    ON cc.run_id = an.run_id
    AND cc.client_rec_id = an.client_rec_id
LEFT JOIN staging.frontrunner_preneed_client_info pn 
    ON cc.run_id = pn.run_id 
    AND cc.client_rec_id = pn.client_rec_id
WHERE cc.run_id = $1
;