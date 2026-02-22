-- Frontrunner Staging Views
-- At Need ClientInfo
CREATE OR REPLACE VIEW frontrunner_atneed_client_info AS
SELECT
    migration_id,
    r.data->>'Client_Rec_Id' AS client_rec_id,
    r.data
FROM raw_records r
WHERE r.migration_id = $1
AND r.source_file like 'AtNeed-ClientInfo%';

-- Pre Need ClientInfo
CREATE OR REPLACE VIEW frontrunner_preneed_client_info AS
SELECT
    migration_id,
    r.data->>'Client_Rec_Id' AS client_rec_id,
    r.data
FROM raw_records r
WHERE r.migration_id = $1
AND r.source_file like 'Preneed-ClientInfo%';

-- ClientContacts
CREATE OR REPLACE VIEW frontrunner_client_contacts AS
SELECT
    migration_id,
    r.data->>'Client_Rec_ID' AS client_rec_id,
    LOWER(TRIM(r.data->>'Relationship')) AS relationship,
    r.data
FROM raw_records r
WHERE r.migration_id = $1
AND r.source_file like 'ClientContacts%';

-- OptionalData
CREATE OR REPLACE VIEW frontrunner_optional_data AS
SELECT
    migration_id,
    r.data->>'Client_Rec_Id' AS client_rec_id,
    r.data
FROM raw_records r
WHERE r.migration_id = $1
AND r.source_file like 'OptionalData-%';

-- OptionalFields
CREATE OR REPLACE VIEW frontrunner_optional_fields AS
SELECT
    migration_id,
    r.data->>'ID' AS id,
    r.data->>'FieldNameDataEntry' AS field_name,
    r.data
FROM raw_records r
WHERE r.migration_id = $1
AND r.source_file like 'OptionalFields-%';