import { Connection } from "./database";
import { getTableNameMap } from "../shared/utils";
import { MigrationRecord, RawDataRow, TableData, Vendor, VendorRecord } from "../types";


export const stageData = async (db: Connection, vendor: VendorRecord, clientName: string, fileName: string, data: TableData[], batchId: number) => {
    const tableName = getTableNameMap(vendor.key, fileName);
    console.log(`Staging data: ${ data.length} rows in ${tableName}`);

    const start = new Date();
    const payload: RawDataRow[] = data.map(row => ({
        migration_batch_id: batchId,
        client: clientName,
        vendor_id: vendor.id,
        file_name: fileName,
        logical_table_name: tableName,
        raw_data: JSON.stringify(row),
    }))

    await batchInsert(db, payload);
    const end = new Date();
    const duration = end.getTime() - start.getTime();
    console.log(`Staged data in ${duration}ms`);
};

export const batchInsert = async(db: Connection, rows: RawDataRow[]) => {
    const batchSize = 100;
    for (let i = 0; i < rows.length; i += batchSize) {
        const batch = rows.slice(i, i + batchSize);
        await db.staging.migration_raw_data.insert(batch);
    }
}

export const findOrCreateMigration = async (db: Connection, clientName: string, vendorId: number): Promise<MigrationRecord> => {
    console.log(`Finding or creating migration for client ${clientName} and vendor ${vendorId}`);
    const migrationRecord = await db.migration.find({
        client_name: clientName,
        vendor_id: vendorId,
    });
    console.log(`existing migrationRecord`, migrationRecord);
    if (migrationRecord?.length > 0) {
        console.log(`Found existing migrationRecord`, migrationRecord[0]);
        return migrationRecord[0];
    }
    const newMigrationRecord = await db.migration.insert({
        client_name: clientName,
        vendor_id: vendorId,
    });
    console.log(`newMigrationRecord`, newMigrationRecord);
    return newMigrationRecord;
}