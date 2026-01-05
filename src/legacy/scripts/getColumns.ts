// Script to pull column names from a directory of CSV files
import fs from 'fs';
import * as csv from '@fast-csv/parse';
import path from 'path';
import { shouldExcludeFile } from '../shared/constants';
import { FrontRunnerTableNameMap, TableNameMapLookup } from '../types';

/**
 * Function to get columns from a directory of CSV files
 * @param vendor - Vendor name
 * @param client - Client number
 * @param directoryPath - Path to the directory containing CSV files
 * @returns - Array of column names
 */
export const getColumns = async (
    vendor: string,
    client: number,
    directoryPath: string,
    outputPath: string = path.join(directoryPath, `${vendor}_${client}_schema.json`)
): Promise<void> => {
    console.log('Starting getColumns function');
    const files = await fs.promises.readdir(directoryPath);
    // console.log('Files read from directory:', files);
    const tableSchema: Record<string, { columns: string[] }> = {};

    const fileProcessPromises = files
        .filter(file => {
            const exclude = shouldExcludeFile(file);
            // console.log(`Should exclude file ${file}:`, exclude);
            return !exclude;
        })
        .map(async file => {
            if (!file.endsWith('.csv')) {
                console.log(`Skipping non-CSV file: ${file}`);
                return Promise.resolve(); // Ensure we return a promise
            }

            return new Promise<void>((resolve, reject) => {
                const filePath = path.join(directoryPath, file);
                const tableMap = TableNameMapLookup(vendor);
                if (!tableMap) {
                    console.error(`No table map found for vendor: ${vendor}`);
                    return reject(new Error(`No table map found for vendor: ${vendor}`));
                }
                const tableName = tableMap(file);
                console.log('Processing file:', filePath, 'Table name:', tableName);

                const columnsSet = new Set<string>();

                const stream = fs.createReadStream(filePath)
                    .on('error', (error) => {
                        console.error(`Stream error for ${filePath}:`, error);
                        reject(error);
                    });
                const parser = csv.parse({ headers: true })
                    .on('error', (error) => {
                        console.error(`Error reading file ${filePath}:`, error);
                        reject(error);
                    })
                    .on('headers', (headers: string[]) => {
                        headers.forEach(header => columnsSet.add(header));
                    })
                    .on('data', () => { })
                    .on('end', () => {
                        console.log(`Finished processing file: ${filePath}`);
                        tableSchema[tableName] = { columns: Array.from(columnsSet) };
                        resolve();
                    });
                stream.pipe(parser);
            });
        });

    console.log('Waiting for all file processing promises to resolve');
    try {
        await Promise.all(fileProcessPromises);
    } catch (error) {
        console.error('Error processing files:', error);
    }
    console.log('All file processing promises resolved');

    const jsonOutput = JSON.stringify(tableSchema, null, 4);
    await fs.promises.writeFile(outputPath, jsonOutput);
    console.log(`Output written to ${outputPath}`);
};


// Example usage
getColumns('test', 123, '/Users/kevinbratt/Downloads/migration_test/frontrunner_export');