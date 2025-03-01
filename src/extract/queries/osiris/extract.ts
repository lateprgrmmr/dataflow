import * as fs from 'fs';
import * as path from 'path';
import * as ExcelJS from 'exceljs';
import * as sqlite3 from 'sqlite3';
import { OsirisTableNameMap, TableData } from '../../../types';


export const osirisExtract = async (directoryPath: string, fhId: number): Promise<string[]> => {
    const files = await fs.promises.readdir(directoryPath);
    console.log('files', files);

    const result: string[] = [];

    for (const file of files) {
        if (file.endsWith('CaseData.xlsx')) {
            const filePath = path.join(directoryPath, file);
            try {
                const sheetsData = await readExcelFile(filePath);
                await processExcelData(fhId, sheetsData);
                result.push(`File ${file} processed successfully.`);
            } catch (error) {
                result.push(`Error processing ${file}: ${(error as any).message}`);
            }
        }
    }

    return result;
};

const readExcelFile = async (filePath: string): Promise<{ [sheetName: string]: any[] }> => {
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.readFile(filePath);

    const result: { [sheetName: string]: any[] } = {};

    workbook.eachSheet((worksheet, sheetId) => {
        const sheetName = worksheet.name;
        const data = worksheet.getSheetValues();
        result[sheetName] = data;
    });

    return result;
};

const processExcelData = async (fhId: number, sheetsData: { [sheetName: string]: any[] }): Promise<void> => {
    const db = new sqlite3.Database(`./${fhId}_osiris.db`, sqlite3.OPEN_CREATE | sqlite3.OPEN_READWRITE, (err) => {
        if (err) {
            throw err;
        }
    });

    try {
        for (const sheetName in sheetsData) {
            if (sheetsData.hasOwnProperty(sheetName)) {
                const tableData = sheetsData[sheetName];
                const tableName = OsirisTableNameMap(sheetName);

                if (tableName !== 'SKIP') {
                    await createAndInsertTable(fhId, tableName, tableData);
                }
            }
        }
    } finally {
        db.close();
    }
};

const createAndInsertTable = async (fhId: number, tableName: string, tableData: TableData[]): Promise<void> => {
    return new Promise(async (resolve, reject) => {
        const db = new sqlite3.Database(`./${fhId}_osiris.db`, sqlite3.OPEN_CREATE | sqlite3.OPEN_READWRITE, (err) => {
            if (err) {
                reject(err);
            }
        });

        try {
            await new Promise<void>((resolve, reject) => {
                db.run(`CREATE TABLE IF NOT EXISTS ${tableName} (table_id INTEGER PRIMARY KEY AUTOINCREMENT, ${getColumnsDefinition(tableData)})`, (err) => {
                    if (err) {
                        reject(err);
                    } else {
                        resolve();
                    }
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


const getColumnsDefinition = (tableData: TableData[]): string => {
    if (tableData.length === 0) {
        return 'data TEXT'; // Default column name if no data to infer
    }

    const exampleRow = tableData[0];
    return Object.keys(exampleRow).map((columnName) => {
        // Ensure the column name is valid SQL (no spaces, special characters, etc.)
        // Also wrapped in brackets to avoid reserved words conflicts
        const sanitizedColumnName = columnName.replace(/[^a-zA-Z0-9_]/g, '_');
        return `[${sanitizedColumnName}] TEXT`
    }).join(', ');
};

const getColumns = (tableData: TableData[]): string => {
    if (tableData.length === 0) {
        return 'data';
    }

    return Object.keys(tableData[0]).map((columnName) => {
        // Ensure the column name is valid SQL (no spaces, special characters, etc.)
        // Also wrapped in brackets to avoid reserved words conflicts
        const sanitizedColumnName = columnName.replace(/[^a-zA-Z0-9_]/g, '_');
        return `[${sanitizedColumnName}]`
    }).join(', ');
};

const getValuesPlaceholders = (tableData: TableData[]): string => {
    return Array.from({ length: Object.keys(tableData[0]).length }, () => '?').join(', ');
};

const getValues = (row: TableData): any[] => {
    return Object.values(row);
};

