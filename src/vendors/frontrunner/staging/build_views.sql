-- Frontrunner Staging Views
-- At Need ClientInfo
CREATE OR REPLACE VIEW staging.frontrunner_atneed_client_info AS
SELECT
    run_id,
    r.data->>'Client_Rec_Id' AS client_rec_id,
    r.data
FROM staging.raw_records r
WHERE r.source_system = 'frontrunner'
AND r.source_file like 'AtNeed-ClientInfo%';

-- Pre Need ClientInfo
CREATE OR REPLACE VIEW staging.frontrunner_preneed_client_info AS
SELECT
    run_id,
    r.data->>'Client_Rec_Id' AS client_rec_id,
    r.data
FROM staging.raw_records r
WHERE r.source_system = 'frontrunner'
AND r.source_file like 'Preneed-ClientInfo%';

-- ClientContacts
CREATE OR REPLACE VIEW staging.frontrunner_client_contacts AS
SELECT
    run_id,
    r.data->>'Client_Rec_ID' AS client_rec_id,
    LOWER(TRIM(r.data->>'Relationship')) AS relationship,
    r.data
FROM staging.raw_records r
WHERE r.source_system = 'frontrunner'
AND r.source_file like 'ClientContacts%';

-- OptionalData
CREATE OR REPLACE VIEW staging.frontrunner_optional_data AS
SELECT
    run_id,
    r.data->>'Client_Rec_Id' AS client_rec_id,
    r.data
FROM staging.raw_records r
WHERE r.source_system = 'frontrunner'
AND r.source_file like 'OptionalData-%';

-- OptionalFields
CREATE OR REPLACE VIEW staging.frontrunner_optional_fields AS
SELECT
    run_id,
    r.data->>'ID' AS id,
    r.data->>'FieldNameDataEntry' AS field_name,
    r.data
FROM staging.raw_records r
WHERE r.source_system = 'frontrunner'
AND r.source_file like 'OptionalFields-%';