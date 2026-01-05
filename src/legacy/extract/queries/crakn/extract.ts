import * as fs from 'fs';
import * as sqlite3 from 'sqlite3';
import { TableData } from '../../../types';


const path = '/Users/kevinbratt/Downloads/Holt Crakn Data.json';

export const craknExtract = (path: string, fhId: number, process: string, type: string) => {
    fs.readFile(path, 'utf8', (err: NodeJS.ErrnoException | null, data: string) => {
        if (err) {
            console.error(err);
            return;
        }

        try {
            const json = JSON.parse(data);

            const db = new sqlite3.Database(`./${fhId}_crakn.db`, sqlite3.OPEN_CREATE | sqlite3.OPEN_READWRITE, (err) => {
                if (err) {
                    console.error('err', err);
                }
            });

            Object.keys(json).forEach((key: string) => {
                const tableData: TableData[] = json[key];

                db.run(`CREATE TABLE IF NOT EXISTS ${key} (id INTEGER PRIMARY KEY AUTOINCREMENT, data TEXT)`);
                const stmt: sqlite3.Statement = db.prepare(`INSERT INTO ${key} (data) VALUES (?)`);
                tableData.forEach((row: TableData) => {
                    stmt.run(JSON.stringify(row));
                });
                stmt.finalize();
            });
            db.close();

            console.log('Database created successfully!');
        } catch (jsonErr) {
            console.error('Error parsing JSON: ', (jsonErr as any).message);
        }
        return `File ${path} processed successfully.`
    })
}