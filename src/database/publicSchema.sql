
CREATE TYPE migration_status AS ENUM ('pending', 'in_progress', 'review', 'completed', 'failed');
CREATE TABLE vendors (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    notes TEXT
);

CREATE TABLE migration_history (
    id SERIAL PRIMARY KEY,
    vendor_id INTEGER NOT NULL REFERENCES vendors(id),
    schema_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status migration_status DEFAULT 'pending'
);

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

-- DROP FUNCTION IF EXISTS create_dynamic_schema(_schema_name TEXT);
CREATE FUNCTION create_dynamic_schema(_schema_name TEXT) 
RETURNS TEXT AS $schema_name$
DECLARE
    schema_name TEXT;
    sql TEXT;
BEGIN
    sql := format('CREATE SCHEMA IF NOT EXISTS %I', _schema_name);
    EXECUTE sql;
    schema_name := _schema_name;
    RETURN schema_name;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Schema creation failed: %', SQLERRM;
        RETURN NULL;
END;
$schema_name$
LANGUAGE plpgsql;

-- DROP FUNCTION IF EXISTS create_dynamic_table(_schema_name TEXT, _table_name TEXT, _columns TEXT);

CREATE FUNCTION create_dynamic_table(
    _schema_name TEXT,
    _table_name TEXT,
    _columns TEXT
    )
RETURNS VOID AS $$
DECLARE
    sql TEXT;
BEGIN
    RAISE NOTICE 'Creating table: %.%', _schema_name, _table_name;
    RAISE NOTICE 'Columns: %', _columns;
    sql := format('CREATE TABLE IF NOT EXISTS %I.%I (
            id SERIAL PRIMARY KEY,
            %s);',
             _schema_name, _table_name, _columns);
    EXECUTE sql;
END;
$$ LANGUAGE plpgsql;


DROP FUNCTION insert_dynamic_data(_schema_name TEXT, _table_name TEXT, _columns TEXT, _json_values jsonb);

CREATE FUNCTION insert_dynamic_data(
    _schema_name TEXT,
    _table_name TEXT,
    _columns TEXT,
    _json_values JSONB
)
RETURNS VOID AS $$
DECLARE
    sql TEXT;
    full_table_name TEXT;
BEGIN
    full_table_name := format('%I.%I', _schema_name, _table_name);

    -- Check if the table exists and is a composite type
    IF NOT EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = _schema_name AND c.relname = _table_name
    ) THEN
        RAISE EXCEPTION 'Table % does not exist or is not recognized as a composite type', full_table_name;
    END IF;

    -- Construct and execute the insert statement
    sql := format(
        'INSERT INTO %I.%I (%s) 
        SELECT %s FROM jsonb_populate_recordset(NULL::%I.%I, $1);',
        _schema_name, _table_name, _columns, _columns, _schema_name, _table_name
    );

    
    EXECUTE sql USING _json_values;
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION insert_dynamic_data(
    _schema_name TEXT,
    _table_name TEXT,
    _columns TEXT,
    _json_values jsonb
)
RETURNS VOID AS $$
DECLARE
    sql TEXT;
BEGIN
    RAISE NOTICE 'Inserting data into table: %.%', _schema_name, _table_name;
    RAISE NOTICE 'Columns: %', _columns;
    RAISE NOTICE 'Values: %', _json_values;
    sql := format('INSERT INTO %I.%I (%s) SELECT * FROM jsonb_populate_recordset(NULL::%I.%I, $1);',
              _schema_name, _table_name, _columns, _schema_name, _table_name || ' %ROWTYPE');

    -- sql := format('INSERT INTO %I.%I (%s) SELECT * FROM json_populate_recordset(NULL::%I.%I, $1);',
    --              _schema_name, _table_name, _columns, _schema_name, _table_name);
    EXECUTE sql USING _json_values;
END;
$$ LANGUAGE plpgsql;