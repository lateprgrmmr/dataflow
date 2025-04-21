import * as fs from 'fs';
import * as path from 'path';
import * as fastCsv from 'fast-csv';
import { TableData, Vendor } from '../types';
import massive from 'massive';
import { shouldExcludeFile } from '../shared/constants';
import { stageData } from '../database/api';

/**
 * 
 * @param db 
 * @param vendor 
 * @param fhId 
 * @param directoryPath 
 * 
 * This function is meant to accept a directory of csv files
 * We will iterate through the files and insert them into the staging table
 * 
 */

export const csvBatch = async (db: massive.Database, vendor: Vendor, clientName: string, directoryPath: string) => {
    const files = await fs.promises.readdir(directoryPath);

    for (const file of files) {
        if (file.endsWith('.csv') && !shouldExcludeFile(file)) {
            const tableName = path.basename(file, '.csv');
            const filePath = path.join(directoryPath, file)

            try {
                const tableData = await readCsv(filePath);
                await stageData(db, vendor, clientName, tableName, tableData);
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
            .on('data', (row) => {
                rows.push(row);
            })
            .on('end', () => { resolve(rows) })
            .on('error', (error) => { reject(error) });
    });
};
