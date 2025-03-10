import { Connection } from "./database";
import { getColumns, getColumnsDefinition, getTableNameMap } from "../shared/utils";
import { TableData, Vendor } from "../types";

export const buildSchema = async (db: Connection, vendor: Vendor, fhId: number): Promise<Array<Record<string, string>>> => {
    return db.create_dynamic_schema(`${vendor}_${fhId}`);
};

export const createTable = async (db: Connection, vendor: Vendor, schemaName: string, fileName: string, data: TableData[]) => {
    // create a table, with dynamic schema based on the column defs provided
    const tableName = getTableNameMap(vendor, fileName);
    // console.log(`Processed ${fileName} successfully, creating table ${tableName}`);
    const columns = getColumnsDefinition(data, true);
    // console.log(`${tableName} Columns: ${columns}\n########\n`);
    console.log(`Creating table ${schemaName}.${tableName}...`);
    await db.create_dynamic_table(schemaName, tableName, columns);
    await insertData(db, vendor, schemaName, fileName, data, columns);
};

export const insertData = async (db: Connection, vendor: Vendor, schemaName: string, fileName: string, data: TableData[], columns: string) => {
    // insert data into the table
    const tableName = getTableNameMap(vendor, fileName);
    const columnsArr = getColumns(data);
    console.log(`Inserting data...`, columnsArr, '\n#######\n');
    console.log(`Inserting data into ${schemaName}.${tableName}...`);
    const jsonData = JSON.stringify(data);

    await db.insert_dynamic_data(schemaName, tableName, columnsArr, jsonData);
};