import * as fs from 'fs';
import * as path from 'path';
import * as fastCsv from 'fast-csv';
import * as sqlite3 from 'sqlite3';
import { TableData, VendorEnum } from '../types';
import { getColumns, getColumnsDefinition, getTableNameMap, getValues, getValuesPlaceholders, sanitizedColumnName } from '../shared/utils';


export const csvBatch = async (vendor: VendorEnum, fhId: number, directoryPath: string): Promise<string[]> => {
    const files = await fs.promises.readdir(directoryPath);

    const result: string[] = [];

    for (const file of files) {
        const tableName: string = getTableNameMap(vendor, file)
        if (file.endsWith('.csv') && tableName !== 'SKIP') {
            const filePath = path.join(directoryPath, file);
            try {
                const tableData = await readCsvFile(filePath);
                await createAndInsertTable(vendor, fhId, tableName, tableData);
                result.push(`File ${file} processed successfully.`);
            } catch (error) {
                result.push(`Error processing ${file}: ${(error as any).message}`);
            }
        }
    }

    return result;
};

const readCsvFile = (filePath: string): Promise<TableData[]> => {
    return new Promise((resolve, reject) => {
        const rows: TableData[] = [];

        fs.createReadStream(filePath)
            .pipe(fastCsv.parse({ headers: true }))
            .on('data', (row) => {
                rows.push(row);
            })
            .on('end', () => {
                resolve(rows);
            })
            .on('error', (error) => {
                reject(error);
            });
    });
};

const createAndInsertTable = async (vendor: VendorEnum, fhId: number, tableName: string, tableData: TableData[]): Promise<void> => {
    return new Promise(async (resolve, reject) => {
        const db = new sqlite3.Database(`./${fhId}_${vendor}.db`, sqlite3.OPEN_CREATE | sqlite3.OPEN_READWRITE, (err) => {
            if (err) {
                reject(err);
            }
        });

        try {
            await new Promise<void>((resolve, reject) => {
                db.run(`CREATE TABLE IF NOT EXISTS ${tableName} (table_id INTEGER PRIMARY KEY AUTOINCREMENT, ${getColumnsDefinition(tableData, true)})`, (err) => {
                    if (err) reject(err);
                    else resolve();
                });
            });

            const stmt: sqlite3.Statement = db.prepare(`INSERT INTO ${tableName} (${getColumns(tableData)}) VALUES (${getValuesPlaceholders(tableData)})`);
            console.log(`Inserting data into ${tableName}...`);

            await new Promise<void>((resolve, reject) => {
                tableData.forEach((row) => {
                    stmt.run(...getValues(row), (err: any) => {
                        if (err) {
                            reject(err);
                        }
                    });
                });

                stmt.finalize((err) => {
                    if (err) {
                        reject(err);
                    } else {
                        resolve();
                    }
                });
            });
        } catch (error) {
            reject(error);
        } finally {
            db.close((err) => {
                if (err) {
                    reject(err);
                } else {
                    resolve();
                }
            });
        }
    });
};