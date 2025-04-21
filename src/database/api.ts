import { Connection } from "./database";
import { getTableNameMap } from "../shared/utils";
import { RawDataRow, TableData, Vendor } from "../types";


export const stageData = async (db: Connection, vendor: Vendor, clientName: string, fileName: string, data: TableData[]) => {
    const vendorRecord = await db.staging.vendor.findOne({ key: vendor });
    if (!vendorRecord) {
        throw new Error(`Vendor ${vendor} not found in the database`);
    }
    const tableName = getTableNameMap(vendor, fileName);
    console.log(`Staging data: ${ data.length} rows in ${tableName}`);
    const newBatch = await db.staging.migration_batch.insert({
        vendor_id: vendorRecord.id,
        client_name: clientName,
    });

    const start = new Date();
    const payload: RawDataRow[] = data.map(row => ({
        migration_batch_id: newBatch.id,
        client: clientName,
        vendor_id: vendorRecord.id,
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