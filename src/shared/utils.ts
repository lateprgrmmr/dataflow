import * as fs from 'fs';
import * as sqlite3 from 'sqlite3';
import { queryDatabase } from "./../database";
import * as xlsx from 'xlsx';

import { FrontRunnerTableNameMap, PassareTableNameMap, TableData, VendorBatchType, VendorEnum, VendorFileType } from '../types';
import { promisify } from 'util';

export const readFileAsync = promisify(fs.readFile);

export const sanitizedColumnName = (columnName: string) => columnName.replace(/[^a-zA-Z0-9_]/g, '_');

const vendorBatchTypeLookup: Record<VendorEnum, VendorFileType | undefined> = {
    [VendorEnum.arranger_adv]: VendorFileType.XXXX,
    [VendorEnum.aurora]: VendorFileType.csv,
    [VendorEnum.batesville]: VendorFileType.sql,
    [VendorEnum.crakn]: VendorFileType.json,
    [VendorEnum.directors_asst]: VendorFileType.sql,
    [VendorEnum.fdm]: VendorFileType.csv,
    [VendorEnum.frontrunner]: VendorFileType.csv,
    [VendorEnum.funeralone]: VendorFileType.csv,
    [VendorEnum.funeraltech]: VendorFileType.XXXX,
    [VendorEnum.halcyon]: VendorFileType.sql,
    [VendorEnum.last_writes]: VendorFileType.XXXX,
    [VendorEnum.mims]: VendorFileType.sql,
    [VendorEnum.mortware]: VendorFileType.sql,
    [VendorEnum.none]: VendorFileType.XXXX,
    [VendorEnum.osiris]: VendorFileType.xlsx,
    [VendorEnum.parting_pro]: VendorFileType.XXXX,
    [VendorEnum.passare]: VendorFileType.csv,
    [VendorEnum.salesforce]: VendorFileType.XXXX,
    [VendorEnum.srs]: VendorFileType.sql,
};

export const getVendorBatchType = (vendor: VendorEnum): VendorFileType | undefined => {
    return vendorBatchTypeLookup[vendor];
};


type VendorTableNameMapCallback = (fileName: string) => string;
const VENDOR_TABLE_NAME_MAP_LOOKUP: Record<VendorEnum, VendorTableNameMapCallback | null> = {
    [VendorEnum.arranger_adv]: null, // ArrangerAdvTableNameMap,
    [VendorEnum.aurora]: null, // AuroraTableNameMap,
    [VendorEnum.batesville]: null, // BatesvilleTableNameMap,
    [VendorEnum.crakn]: null, // CraknTableNameMap,
    [VendorEnum.directors_asst]: null, // TdaTableNameMap,
    [VendorEnum.fdm]: null, // FdmTableNameMap,
    [VendorEnum.frontrunner]: FrontRunnerTableNameMap,
    [VendorEnum.funeralone]: null, // FuneralOneTableNameMap,
    [VendorEnum.funeraltech]: null, // FuneralTechTableNameMap,
    [VendorEnum.halcyon]: null, // HalcyonTableNameMap,
    [VendorEnum.last_writes]: null, // LastWritesTableNameMap,
    [VendorEnum.mims]: null, // MimsTableNameMap,
    [VendorEnum.mortware]: null, // MortwareTableNameMap,
    [VendorEnum.none]: null, // None
    [VendorEnum.osiris]: null, // OsirisTableNameMap,
    [VendorEnum.parting_pro]: null, // PartingProTableNameMap,
    [VendorEnum.passare]: PassareTableNameMap,
    [VendorEnum.salesforce]: null, // SalesforceTableNameMap,
    [VendorEnum.srs]: null, // SrsTableNameMap,
};

export const getTableNameMap = (vendor: VendorEnum, fileName: string) => {
    const vendorTableNameMapCallback = VENDOR_TABLE_NAME_MAP_LOOKUP[vendor];
    const tableName = vendorTableNameMapCallback?.(fileName) ?? 'SKIP';
    return tableName;
};

export const getColumnsDefinition = (tableData: TableData[], isCreate: boolean): string => {
    if (tableData.length === 0) {
        return `data${isCreate ? ' TEXT' : ''}`; // Default column name if no data to infer
    }

    const exampleRow = tableData[0];
    return Object.keys(exampleRow).map((columnName) => {
        // Ensure the column name is valid SQL (no spaces, special characters, etc.)
        // Also wrapped in brackets to avoid reserved words conflicts
        return `[${sanitizedColumnName(columnName)}]${isCreate ? ' TEXT' : ''}`
    }).join(', ');
};

export const getColumns = (tableData: TableData[]): string => {
    if (tableData.length === 0) {
        return 'data';
    }

    return Object.keys(tableData[0]).map((columnName) => {
        // Ensure the column name is valid SQL (no spaces, special characters, etc.)
        // Also wrapped in brackets to avoid reserved words conflicts
        return `[${sanitizedColumnName(columnName)}]`
    }).join(', ');
};

export const getValuesPlaceholders = (tableData: TableData[]): string => {
    if (tableData.length === 0) {
        return '?';
    }
    return Array.from({ length: Object.keys(tableData[0]).length }, () => '?').join(', ');
};

export const getValues = (row: TableData): any[] => {
    return Object.values(row);
};


export const createTable = async (tableName: string, columns: string[]) => {
    const columnDefs = columns.map((col) => `${col} TEXT`).join(', ');
    const query = `CREATE TABLE IF NOT EXISTS ${tableName} (${columnDefs})`;
    await queryDatabase(query);
};

export const insertData = async (tableName: string, data: any[]) => {
    if (data.length === 0) {
        return;
    }
    const columns = Object.keys(data[0]);
    const placeholders = columns.map((_, index) => `$${index + 1}`).join(', ');
    const query = `INSERT INTO ${tableName} (${columns.join(', ')}) VALUES (${placeholders})`;

    const promises = data.map((row) => {
        return queryDatabase(query, Object.values(row));
    });

    await Promise.all(promises);
};

// export const createDb = (dbPath: string, commit: boolean) => {
//     let db: sqlite3.Database;
//     if (!fs.existsSync(dbPath)) {
//         console.log('dbPath exists', fs.existsSync(dbPath));
//         db = new sqlite3.Database(dbPath);
//         return db;
//     }
//     if (commit) {
//         console.log('commit', commit)
//         // If we're for real, delete the existing database if it's there and create a new one
//         console.log('what', fs.existsSync(dbPath));
//         if (fs.existsSync(dbPath)) {
//             // File exists, delete it
//             try {
//                 fs.unlinkSync(dbPath);
//                 console.log(`File ${dbPath} deleted successfully.`);
//             } catch (err) {
//                 console.error(`Error deleting file ${dbPath}: ${(err as any).message}`);
//             }
//         } else {
//             console.log(`File ${dbPath} does not exist.`);
//         }
//         db = new sqlite3.Database(dbPath, sqlite3.OPEN_CREATE | sqlite3.OPEN_READWRITE, (err) => {
//             if (err) {
//                 console.error('err', err);
//             }
//         });
//         return db;
//     }
//     db = new sqlite3.Database(dbPath, sqlite3.OPEN_READWRITE, (err) => {
//         if (err) {
//             console.error(`Error connecting to database ${dbPath} \n ${err.message}`);
//         } else {
//             console.log(`Connected to database ${dbPath} successfully.`);
//         }
//     });
//     return db;
// };

export const processCSVFiles = (dbPath: string, directoryPath: string) => {
    fs.readdir(directoryPath, async (err, files) => {
        if (err) {
            console.error(`Error reading directory: ${err.message}`);
            return;
        }

        for (const file of files) {
            const fstat = fs.statSync(file);
            if (file.endsWith('.csv')) {
                const filePath = `${directoryPath}/${file}`;
                if (!fstat.isFile()) {
                    throw new Error('Input must be a directory');
                }
                console.log(`Processing file: ${filePath}`);
                // const { tableName, columns } = await readCSV(filePath);
                // createTable(tableName, columns);
                // const data = await readCSV(filePath);
                // insertData(tableName, data);
            }
        }

        // db.close();
    });
}


// // export const createTable = (db: sqlite3.Database, tableName: string, columns: string[]) => {

// //     const columnsStr = columns.map((col) => `"${col}" TEXT`).join(', ');
// //     const query = `CREATE TABLE IF NOT EXISTS ${tableName} (${columnsStr})`;
// //     console.log('columnsStr', columnsStr);
// //     console.log('query', query);
// //     // db.run(query, (err) => {
// //     //     if (err) {
// //     //         console.error(`Error creating table ${tableName}: ${err.message}`);
// //     //     } else {
// //     //         console.log(`Table ${tableName} created successfully.`);
// //     //     }
// //     // });
// // };