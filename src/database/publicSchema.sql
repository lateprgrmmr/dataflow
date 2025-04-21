
CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE staging.vendor (
    id SERIAL PRIMARY KEY,
    key TEXT NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TYPE migration_status_type AS ENUM (
    'pending',
    'in_progress',
    'completed',
    'failed'
);

CREATE TABLE staging.migration_batch (
    id SERIAL PRIMARY KEY,
    vendor_id INTEGER NOT NULL REFERENCES staging.vendor(id),
    client_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    -- status migration_status_type DEFAULT 'pending'::migration_status_type
);

CREATE TABLE staging.migration_raw_data (
    id SERIAL PRIMARY KEY,
    migration_batch_id INTEGER NOT NULL REFERENCES staging.migration_batch(id),
    client TEXT NOT NULL,
    vendor_id INTEGER NOT NULL REFERENCES staging.vendor(id),
    file_name TEXT NOT NULL,
    logical_table_name TEXT NOT NULL,
    raw_data JSONB NOT NULL,
    ingested_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);