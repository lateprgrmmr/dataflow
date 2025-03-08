import * as fs from 'fs';
import * as path from 'path';
import * as fastCsv from 'fast-csv';
import { TableData, Vendor } from '../types';
import { getColumns, getColumnsDefinition, getTableNameMap, getValues, getValuesPlaceholders, sanitizedColumnName } from '../shared/utils';
import massive from 'massive';
import { shouldExcludeFile } from '../shared/constants';
import { buildSchema, createAndInsertTable } from '../database/api';

/**
 * 
 * @param db 
 * @param vendor 
 * @param fhId 
 * @param directoryPath 
 * 
 * This function is meant to accept a directory of csv files
 * We will iterate through the files and create a staging table for each csv
 * 
 */

export const csvBatch = async (db: massive.Database, vendor: Vendor, fhId: number, directoryPath: string) => {

    console.log('vendor', vendor);
    const files = await fs.promises.readdir(directoryPath);
    const createdSchema: Array<Record<string, string>> = await buildSchema(db, vendor, fhId);
    const schemaName = createdSchema[0].create_dynamic_schema;
    console.log('schemaName', createdSchema, schemaName);


    for (const file of files) {
        if (file.endsWith('.csv') && !shouldExcludeFile(file)) {
            const tableName = path.basename(file, '.csv');
            const filePath = path.join(directoryPath, file)

            try {
                const tableData = await readCsv(filePath);
                await createAndInsertTable(db, vendor, schemaName, tableName, tableData);
            } catch (error) {
                console.error(`Error processing ${file}`, error);
            }
        }
    }
};

const readCsv = (filePath: string): Promise<TableData[]> => {
    return new Promise((resolve, reject) => {
        const rows: TableData[] = [];

        fs.createReadStream(filePath)
            .pipe(fastCsv.parse({ headers: true }))
            .on('data', (row) => { rows.push(row) })
            .on('end', () => { resolve(rows) })
            .on('error', (error) => { reject(error) });
    });
};



// export const csvBatch = async (vendor: Vendor, fhId: number, directoryPath: string): Promise<string[]> => {
//     const files = await fs.promises.readdir(directoryPath);

//     const result: string[] = [];

//     for (const file of files) {
//         const tableName: string = getTableNameMap(vendor, file)
//         if (file.endsWith('.csv') && tableName !== 'SKIP') {
//             const filePath = path.join(directoryPath, file);
//             try {
//                 const tableData = await readCsvFile(filePath);
//                 await createAndInsertTable(vendor, fhId, tableName, tableData);
//                 result.push(`File ${file} processed successfully.`);
//             } catch (error) {
//                 result.push(`Error processing ${file}: ${(error as any).message}`);
//             }
//         }
//     }

//     return result;
// };



// const createAndInsertTable = async (vendor: Vendor, fhId: number, tableName: string, tableData: TableData[]): Promise<void> => {
//     return new Promise(async (resolve, reject) => {
//         const db = new sqlite3.Database(`./${fhId}_${vendor}.db`, sqlite3.OPEN_CREATE | sqlite3.OPEN_READWRITE, (err) => {
//             if (err) {
//                 reject(err);
//             }
//         });

//         try {
//             await new Promise<void>((resolve, reject) => {
//                 db.run(`CREATE TABLE IF NOT EXISTS ${tableName} (table_id INTEGER PRIMARY KEY AUTOINCREMENT, ${getColumnsDefinition(tableData, true)})`, (err) => {
//                     if (err) reject(err);
//                     else resolve();
//                 });
//             });

//             const stmt: sqlite3.Statement = db.prepare(`INSERT INTO ${tableName} (${getColumns(tableData)}) VALUES (${getValuesPlaceholders(tableData)})`);
//             console.log(`Inserting data into ${tableName}...`);

//             await new Promise<void>((resolve, reject) => {
//                 tableData.forEach((row) => {
//                     stmt.run(...getValues(row), (err: any) => {
//                         if (err) {
//                             reject(err);
//                         }
//                     });
//                 });

//                 stmt.finalize((err) => {
//                     if (err) {
//                         reject(err);
//                     } else {
//                         resolve();
//                     }
//                 });
//             });
//         } catch (error) {
//             reject(error);
//         } finally {
//             db.close((err) => {
//                 if (err) {
//                     reject(err);
//                 } else {
//                     resolve();
//                 }
//             });
//         }
//     });
// };