
CREATE TYPE migration_status AS ENUM ('pending', 'in_progress', 'review', 'completed', 'failed');
CREATE TABLE vendor (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    notes TEXT
);

CREATE TABLE migration (
    id SERIAL PRIMARY KEY,
    vendor_id INTEGER NOT NULL REFERENCES vendor(id),
    client_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status migration_status DEFAULT 'pending'
);

CREATE TABLE raw_records (
    id SERIAL PRIMARY KEY,
    migration_id INTEGER NOT NULL REFERENCES migration(id),
    source_file TEXT NOT NULL,
    row_number INTEGER NOT NULL,
    data JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT raw_record_unique UNIQUE (migration_id, source_file, row_number)
);

CREATE INDEX idx_raw_records_migration ON raw_records(migration_id);
CREATE INDEX idx_raw_records_file ON raw_records(source_file);

CREATE OR REPLACE FUNCTION normalize_text(text) RETURNS TEXT AS $$
    SELECT lower(regexp_replace($1, E'[^a-zA-Z0-9\\s]', '', 'g'));
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION normalize_alphanumeric(text) RETURNS TEXT AS $$
    SELECT lower(regexp_replace($1, E'[^a-zA-Z]', '', 'g'));
$$ LANGUAGE SQL;

CREATE TYPE data_mapping_type AS ENUM (
    'death_place',
    'marital_status',
    'education_level',
    'military_branch',
    'race',
    'hispanic_origin',
    'disposition',
    'citizenship'
);

CREATE TYPE normalization_type AS ENUM (
    'text',
    'alphanumeric'
);

CREATE TABLE data_mappings (
    id SERIAL PRIMARY KEY,
    type data_mapping_type NOT NULL,
    raw_value TEXT NOT NULL,
    normalization_rule normalization_type,
    normalized_value TEXT GENERATED ALWAYS AS (
        CASE
            WHEN normalization_rule = 'text' THEN normalize_text(raw_value)
            WHEN normalization_rule = 'alphanumeric' THEN normalize_alphanumeric(raw_value)
        END
    ) STORED,
    mapped_value TEXT NOT NULL
);

CREATE INDEX data_mapping_raw_idx ON data_mappings(raw_value);
CREATE INDEX data_mapping_normalized_idx ON data_mappings(normalized_value);
CREATE INDEX data_mapping_mapped_value_idx ON data_mappings(mapped_value);