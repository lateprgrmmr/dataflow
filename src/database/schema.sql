CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE staging.raw_records (
    id SERIAL PRIMARY KEY,
    run_id TEXT NOT NULL,
    source_system TEXT NOT NULL,
    source_file TEXT NOT NULL,
    row_number INTEGER NOT NULL,
    data JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_raw_records_run ON staging.raw_records(run_id);
CREATE INDEX idx_raw_records_file ON staging.raw_records(source_file);
CREATE INDEX idx_raw_records_data_gin ON staging.raw_records USING gin (data);
