import * as fs from 'fs';
import * as xlsx from 'xlsx';
import * as sqlite3 from 'sqlite3';
import { VendorEnum } from '../types';
import path from 'path';

export const xlsxExport = async (vendor: VendorEnum, fhId: number, directoryPath: string) => {
    const dbPath = path.join(`${fhId}_${vendor}.db`);
    const db = new sqlite3.Database(dbPath, sqlite3.OPEN_CREATE | sqlite3.OPEN_READWRITE);
    // read in schema.txt - NOTE: This is currently static for Osiris migrations, but we should build dynamic solution
    const schema = fs.readFileSync('/Users/kevinbratt/dataxform/src/extract/queries/osiris/schema.txt', 'utf-8');
    db.exec(schema, (err) => {
        if (err) {
            console.log('err', err);
        }
    });

    const caseFolders = fs.readdirSync(directoryPath).filter(folder => !folder.endsWith('.DS_Store'));
    // Go throught the directory
    // for (const folder of caseFolders) {
    caseFolders.forEach(folder => {
        const fstat = fs.statSync(path.join(directoryPath, folder));
        if (!fstat.isDirectory()) {
            throw new Error('Input must be a directory');
        }
        console.log('folder', folder);
        // Get the contents of the folder
        const caseFolderContents = fs.readdirSync(path.join(directoryPath, folder)).filter(item => !item.endsWith('.DS_Store'));
        // Find the CaseData workbook, parse and load it in the database
        const caseDataWb = caseFolderContents.filter(item => item.startsWith('CaseData'));
        const caseData = xlsx.readFile(path.join(directoryPath, folder, caseDataWb[0]));
        // Go through all the sheets in the workbook, build create table and insert statements for each
        caseData.SheetNames.forEach(sheetName => {
            const sheetData = caseData.Sheets[sheetName];
            const preHeader = ['fileNumber']
            const headers = preHeader.concat(xlsx.utils.sheet_to_csv(sheetData).split('\n')[0].split(','));
            db.exec(`CREATE TABLE IF NOT EXISTS ${sheetName} (table_id INTEGER PRIMARY KEY AUTOINCREMENT, ${headers.map((header: string) => `\`${header}\` TEXT`).join(', ')})`);
            generateSql(sheetData, sheetName, folder).then(data => {
                data.forEach(query => {
                    db.run(query, (err) => {
                        if (err) {
                            console.log('err1', err);
                        }
                    });
                });

            }).catch(err => {
                console.log('err2', err);
            });
        });

        // Now we need to get all the contracts...
        const contractsFolder = caseFolderContents.filter(item => item.startsWith('Contracts'));
        contractsFolder.forEach(contractFolder => {
            const contractFolderContents = fs.readdirSync(path.join(directoryPath, folder, contractFolder)).filter(item => !item.endsWith('.DS_Store'));
            contractFolderContents.forEach(contractFile => {
                const contractData = xlsx.readFile(path.join(directoryPath, folder, contractFolder, contractFile));
                contractData.SheetNames.forEach(sheetName => {
                    const sheetData = contractData.Sheets[sheetName];
                    const dbSheetName = sheetName.replaceAll(' ', '');
                    const preHeader = ['fileNumber']
                    const headers = preHeader.concat(xlsx.utils.sheet_to_csv(sheetData).split('\n')[0].split(','));
                    db.exec(`CREATE TABLE IF NOT EXISTS ${dbSheetName} (table_id INTEGER PRIMARY KEY AUTOINCREMENT, ${headers.map((header: string) => `\`${header}\` TEXT`).join(', ')})`);
                    generateSql(sheetData, dbSheetName, folder).then(data => {
                        data.forEach(query => {
                            db.run(query, (err) => {
                                if (err) {
                                    console.log('err1', err);
                                }
                            });
                        });

                    }).catch(err => {
                        console.log('err2', err);
                    });
                });
            });

        });
        // Now we need to check for and get the paths to all the attachments (i.e. Documents directory)
        const documentsFolder = caseFolderContents.filter(item => item.startsWith('Documents'));
        documentsFolder.forEach(documentFolder => {
            const documentFolderContents = fs.readdirSync(path.join(directoryPath, folder, documentFolder)).filter(item => !item.endsWith('.DS_Store'));
            documentFolderContents.forEach(documentFile => {
                const docHeader = ['fileNumber', 'documentName', 'documentPath'];
                // write these paths to csv
                
                console.log('documentFile', documentFile);
            });
        });
    });
};

// Function to generate SQL from a worksheet
export const generateSql = async (ws: any, wsName: string, fileNumber: string) => {
    const aoo: {}[] = xlsx.utils.sheet_to_json(ws);

    const hdr: string[] = ['`file_number`'];
    aoo.forEach(row => Object.entries(row).forEach(([k, v]) => {
        if (!hdr.includes(k)) {
            hdr.push(k.replaceAll("\"\"\"", "\""));
        }
    }));
    const inserts: string[] = [];
    aoo.map(row => {
        const entries = Object.entries(row);
        const fields: string[] = ['`file_number`']
        const values: string[] = [`'${fileNumber}'`];
        entries.forEach(([k, v]) => {
            if (v == null) {
                fields.push(`\`\``);
            } else {
                fields.push(`\`${k}\``);
            }
            if (typeof v === 'string') {
                values.push(`'${v.toString().replaceAll("'", "''")}'`);
            }
        })
        if (fields.length) inserts.push(`INSERT INTO \`${wsName}\` (${fields.join(", ")}) VALUES (${values.join(", ")})`);
    }).filter(i => i);
    return inserts;
};