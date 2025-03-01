import * as fs from 'fs';
import * as sqlite3 from 'sqlite3';
import { TableData, VendorEnum } from '../types';
import { readFileAsync } from '../shared/utils';

// const path = '/Users/kevinbratt/Downloads/Holt Crakn Data.json';

// TODO: This currently stuffs all the data into a single jsonified column... need to 
// figure out how to parse the data into individual columns
export const jsonExport = async (vendor: VendorEnum, fhId: number, directoryPath: string) => {

    try {
        const data = await readFileAsync(directoryPath, 'utf-8');
        const json = JSON.parse(data);

        const db = new sqlite3.Database(`./${fhId}_${vendor}.db`, sqlite3.OPEN_CREATE | sqlite3.OPEN_READWRITE);

        for (const key of Object.keys(json)) {
            const tableData: TableData[] = json[key];
            if (tableData.length === 0) {
                continue;
            }

            // Extract keys from all rows to get all possible columns
            const allColumnsSet = new Set<string>();
            tableData.forEach(row => {
                Object.keys(row).forEach(column => {
                    allColumnsSet.add(column);
                });
            });

            // Convert the set to an array
            const allColumns = Array.from(allColumnsSet);

            await new Promise<void>((resolve, reject) => {
                // Create the table with all possible columns
                const createTableQuery = `CREATE TABLE IF NOT EXISTS ${key} (table_id INTEGER PRIMARY KEY AUTOINCREMENT, ${allColumns.map(col => `[${col}] TEXT`).join(', ')})`;
                db.run(createTableQuery, (err) => {
                    if (err) reject(err);
                    else resolve();
                });
            });


            let stmt: sqlite3.Statement;
            for (const row of tableData) {
                const rowKeys = Object.keys(row);
                const rowValues = Object.values(row);
                // Since each object may have different keys, we need to dynamically create the insert statement
                stmt = db.prepare(`INSERT INTO ${key} (${rowKeys.map(col => `[${col}]`).join(', ')}) VALUES (${rowValues.map(() => '?').join(', ')})`);

                await new Promise<void>((resolve, reject) => {
                    stmt.run(...Object.values(row), (err: any) => {
                        if (err) reject(err);
                        else resolve();
                    });
                });
            }

            await new Promise<void>((resolve, reject) => {
                stmt.finalize((err) => {
                    if (err) reject(err);
                    else resolve();
                });
            });
        }

        await new Promise<void>((resolve, reject) => {
            db.close((err) => {
                if (err) reject(err);
                else resolve();
            });
        });

        console.log('Database created successfully!');
        return `File ${directoryPath} processed successfully.`;
    } catch (error) {
        console.error('Error:', (error as any).message);
        return `Error processing file ${directoryPath}: ${(error as any).message}`;
    }
};