WITH cases AS (
    SELECT
        an.run_id,
        an.client_rec_id,
        an.data->>'Contract_No' AS case_number
    FROM staging.frontrunner_atneed_client_info an
    -- WHERE an.run_id = $1
    WHERE an.client_rec_id = '2027'
)
SELECT
    se.run_id,
    se.client_rec_id,
    c.case_number,
    se.data->>'ServiceType' AS service_type,
    se.data->>'IntermentDate' AS service_date,
    se.data->>'ServiceTime' AS service_time
FROM cases c
JOIN staging.frontrunner_atneed_client_info se
    ON c.run_id = se.run_id
    AND c.client_rec_id = se.client_rec_id
;