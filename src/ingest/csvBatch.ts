import * as fs from 'fs';
import * as path from 'path';
import * as fastCsv from 'fast-csv';
import { MigrationContext, TableData, Vendor } from '../types';
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
export const readCsv = (filePath: string): Promise<TableData[]> => {
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

export const stageCsvData = async (ctx: MigrationContext) => {
    console.log('Extracting CSV data...');

    const files = await fs.promises.readdir(ctx.inputPath);

    let totalRows = 0;
    for (const file of files) {
        if (!file.endsWith('.csv')) {
            continue;
        }
        const filePath = path.join(ctx.inputPath, file);
        const records = await readCsv(filePath);

        try {
            console.log(`Processing ${file} records...`);
            let rowNumber = 1;
            for (const record of records) {
                await ctx.db.query(`
                    INSERT INTO raw_records (migration_id, source_file, row_number, data)
                    VALUES ($1, $2, $3, $4)
                    ON CONFLICT (migration_id, source_file, row_number)
                    DO UPDATE SET data = EXCLUDED.data
                    RETURNING *
                `, [ctx.migration_id, file, rowNumber++, record]);
                totalRows++;
            }
        } catch (error) {
            throw error;
        }
    }
    console.log('Processed ', totalRows, ' records.');
    return;
}