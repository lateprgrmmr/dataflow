import { Connection } from "./database";
import { getColumnsDefinition, getTableNameMap } from "../shared/utils";
import { TableData, Vendor } from "../types";

export const buildSchema = async (db: Connection, vendor: Vendor, fhId: number): Promise<Array<Record<string, string>>> => {
    return db.create_dynamic_schema(`${vendor}_${fhId}`);
};

export const createAndInsertTable = async (db: Connection, vendor: Vendor, schemaName: string, fileName: string, data: TableData[]) => {
    // create a table, with dynamic schema based on the column defs provided
    const tableName = getTableNameMap(vendor, fileName);
    // console.log(`Processed ${fileName} successfully, creating table ${tableName}`);
    const columns = getColumnsDefinition(data, true);
    // console.log(`${tableName} Columns: ${columns}\n########\n`);
    await db.create_dynamic_table(`${schemaName}.${tableName}`, columns);
    console.log(`Created table ${tableName} successfully`);
};