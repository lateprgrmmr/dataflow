import * as fs from 'fs';
import * as path from 'path';
// import * as ExcelJS from 'exceljs';
import * as xlsx from 'xlsx';
import * as sqlite3 from 'sqlite3';
import { getColumnsDefinition, getColumns, getValuesPlaceholders, getValues, getTableNameMap } from '../shared/utils';
import { TableData, VendorEnum } from '../types';


const pathIsDirectory = (path: string): boolean => { 
    if (path === undefined) {
        return false;
    }
    return fs.statSync(path).isDirectory()
};

export const xlsxBatch = async (vendor: VendorEnum, fhId: number, directoryPath: string): Promise<string[]> => {
    const files = await fs.promises.readdir(directoryPath);
    // console.log('files', files);

    let caseDataheaders: { [sheetName: string]: string[] } = {};
    let contractDataHeaders: { [sheetName: string]: string[] } = {};
    const result: string[] = [];
    const fileList: {file: string, subFile: string}[] = [];

    for (const file of files) {
        if (!file.startsWith('.DS_Store')) {
            const subFiles = await fs.promises.readdir(path.join(directoryPath, file));
            for (const subFile of subFiles) {
                // Get the CaseData.xlsx files headers
                if (subFile.endsWith('CaseData.xlsx')) {
                    fileList.push({ file, subFile });
                    const filePath = path.join(directoryPath, file, subFile);
                    try {
                        // Need to get headers from every sheet
                        const curCaseDataheaderseaders = await getExcelFileHeaders(filePath);
                        caseDataheaders = { ...caseDataheaders, ...curCaseDataheaderseaders };
                        // await processExcelData(vendor, fhId, sheetsData);
                        result.push(`File '${filePath}' processed successfully.`);
                    } catch (error) {
                        result.push(`Error processing '${filePath}': ${(error as any).message}`);
                    }
                } else if (pathIsDirectory(path.join(directoryPath, file, subFile)) && subFile === 'Contracts') {
                    const contractSubFiles = await fs.promises.readdir(path.join(directoryPath, file, subFile));
                    for (const contractSubFile of contractSubFiles) { 
                        const contractSubFilepath = path.join(directoryPath, file, subFile, contractSubFile);
                        try {
                            const curContractDataHeaders = await getExcelFileHeaders(contractSubFilepath);
                            contractDataHeaders = { ...contractDataHeaders, ...curContractDataHeaders };
                            result.push(`File '${contractSubFilepath}' processed successfully.`);
                        } catch (error) {
                            result.push(`Error processing '${contractSubFilepath}': ${(error as any).message}`);
                        }
                    }
                }
            }
        }

    }
    console.log('caseDataHeaders', caseDataheaders);
    console.log('contractDataHeaders', contractDataHeaders);
    // console.log('fileList', fileList);
    return result;
};

export const getExcelFileHeaders = async (filePath: string) => {
    try {
        const file = xlsx.readFile(filePath);
        const sheets = file.SheetNames;
        const headers: { [sheetName: string]: string[] } = {};

        for (let i = 0; i < sheets.length; i++) {
            const sheetName: string = sheets[i];
            const sheetData: any[] = xlsx.utils.sheet_to_json(file.Sheets[sheetName], { header: 1 });

            // Skip empty sheets
            if (sheetData.length > 0) {
                sheetData.forEach((row: string[], idx: number) => {
                    // Get the first row of data as the header, and only add it if it doesn't already exist
                    if (idx === 0 && !headers.hasOwnProperty(sheetName)) {
                        headers[sheetName] = row.concat('file_number');
                    }
                });
            }
        }
        return headers;
    }
    catch (err) {
        console.log(err);
        return { '': [] }
    }
}

// const readExcelFile = async (filePath: string): Promise<{ [sheetName: string]: any[] }> => {
//     console.log('I made it here...');
//     const result: { [sheetName: string]: any[] } = {};
//     const workbook = xlsx.readFile(filePath);
//     let data: string[] = [];
//     const sheets = workbook.SheetNames;
//     // console.log('sheets', sheets);

//     sheets.forEach((sheetName) => {
//         const sheet = workbook.Sheets[sheetName];
//         // get column names from each sheet
//         // let columnNames: string[] = [];
//         const sheetNames = workbook.Props.SheetNames;
//         // const columnMetaArray: {t: string, v: string, r: string, h: string, w: string}[] = Object.values(sheet);
//         // columnMetaArray.forEach((columnMeta) => { 
//         //     if (!(typeof columnMeta === 'object')) {
//         //         return;
//         //     }
//         //     columnNames.push(columnMeta.v);

//         // });

//         console.log('columnNames', sheetName, columnNames);
//         // const sheetData = xlsx.utils.sheet_to_json(sheet);
//         // console.log(sheet, ' -> ', sheetData);
//         // sheetData.forEach((row) => {
//         //     data.push((row as string));
//         // })
//     });
// const workbook = new ExcelJS.Workbook();
// await workbook.xlsx.readFile(filePath);


// const result: { [sheetName: string]: any[] } = {};

// workbook.eachSheet((worksheet, sheetId) => {
//     const sheetName = worksheet.name;
//     const data = worksheet.getSheetValues();
//     result[sheetName] = data;
// });

//     return result;
// };

// const readExcelFile = async (filePath: string): Promise<{ [sheetName: string]: any[] }> => {
//     console.log('I made it here...');

//     try {
//         const workbook = new ExcelJS.Workbook();
//         await workbook.xlsx.readFile(filePath);

//         const result: { [sheetName: string]: any[] } = {};

//         workbook.eachSheet((worksheet) => {
//             const sheetName = worksheet.name;
//             const data = worksheet.getSheetValues();
//             result[sheetName] = data;
//         });

//         return result;
//     } catch (error) {
//         console.error('Error reading Excel file:', error.message);
//         throw error;
//     }
// };

// const processExcelData = async (vendor: Vendor, fhId: number, sheetsData: { [sheetName: string]: any[] }): Promise<void> => {
//     const db = new sqlite3.Database(`./${fhId}_${vendor}.db`, sqlite3.OPEN_CREATE | sqlite3.OPEN_READWRITE, (err) => {
//         if (err) {
//             throw err;
//         }
//     });

//     try {
//         for (const sheetName in sheetsData) {
//             if (sheetsData.hasOwnProperty(sheetName)) {
//                 const tableData = sheetsData[sheetName];
//                 const tableName = getTableNameMap(vendor, sheetName);

//                 if (tableName !== 'SKIP') {
//                     await createAndInsertTable(fhId, tableName, tableData);
//                 }
//             }
//         }
//     } finally {
//         db.close();
//     }
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
//                     if (err) {
//                         reject(err);
//                     } else {
//                         resolve();
//                     }
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


// const getColumnsDefinition = (tableData: TableData[]): string => {
//     if (tableData.length === 0) {
//         return 'data TEXT'; // Default column name if no data to infer
//     }

//     const exampleRow = tableData[0];
//     return Object.keys(exampleRow).map((columnName) => {
//         // Ensure the column name is valid SQL (no spaces, special characters, etc.)
//         // Also wrapped in brackets to avoid reserved words conflicts
//         const sanitizedColumnName = columnName.replace(/[^a-zA-Z0-9_]/g, '_');
//         return `[${sanitizedColumnName}] TEXT`
//     }).join(', ');
// };

// const getColumns = (tableData: TableData[]): string => {
//     if (tableData.length === 0) {
//         return 'data';
//     }

//     return Object.keys(tableData[0]).map((columnName) => {
//         // Ensure the column name is valid SQL (no spaces, special characters, etc.)
//         // Also wrapped in brackets to avoid reserved words conflicts

//         const sanitizedColumnName = columnName.replace(/[^a-zA-Z0-9_]/g, '_');
//         return `[${sanitizedColumnName}]`
//     }).join(', ');
// };

// const getValuesPlaceholders = (tableData: TableData[]): string => {
//     return Array.from({ length: Object.keys(tableData[0]).length }, () => '?').join(', ');
// };

// const getValues = (row: TableData): any[] => {
//     return Object.values(row);
// };

