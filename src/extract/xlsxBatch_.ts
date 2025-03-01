import * as fs from 'fs';
import * as path from 'path';
import * as xlsx from 'xlsx';
import sqlite3 from 'sqlite3';
import { VendorEnum } from '../types';

// enum FileType {
//     DC = 'dc',
//     HELP = 'help',
//     FINANCE = 'finance',
//     DOCUMENTS = 'documents'
// }

export const xlsxBatch = (vendor: VendorEnum, fhId: number, directoryPath: string): void => {
    // export const init = (basePath: string, client: string, dest: string, file_type: FileType): void => {
    const db_file = path.join(`./${fhId}_${vendor}.db`);

    console.log(db_file, fs.existsSync(db_file));
    if (!fs.existsSync(db_file)) {
        console.log('wut', !fs.existsSync(db_file));
        const folders_path = fs.readdirSync(directoryPath);

        let funeral_home_table: any[] = [];
        // let vitals_table: any[] = [];
        // let va_info_table: any[] = [];
        // let case_contacts_table: any[] = [];
        // let contract_table: any[] = [];
        // let sales_tax_table: any[] = [];
        // let services_table: any[] = [];
        // let merchandise_table: any[] = [];
        // let cash_advance_table: any[] = [];
        // let credit_table: any[] = [];
        // let pending_payment_table: any[] = [];
        // let payment_table: any[] = [];
        // let buyers_table: any[] = [];

        for (const folder of folders_path) {
            if (!folder.startsWith('.')) {
                const case_files_path = fs.readdirSync(path.join(directoryPath, folder));

                for (const file of case_files_path) {
                    if (!file.startsWith('.')) {
                        if (file === 'CaseData.xlsx') {
                            const current_file = path.join(directoryPath, folder, file);
                            const workbook = xlsx.readFile(current_file);

                            // FuneralHomeData tab
                            const funeral_home_data = readExcelSheet(workbook, 'FuneralHomeData', ['created_time']);
                            funeral_home_data.forEach((data: string[], idx: number) => {
                                if (idx === 0) {
                                    data.push('file_number')
                                } else {
                                    data.push(folder);
                                }
                            });
                            console.log('funeral_home_data', funeral_home_data);
                            funeral_home_table = funeral_home_table.concat(funeral_home_data);

                            // // Vitals tab
                            // const vitals_data = readExcelSheet(workbook, 'Vitals', ['Date of Marriage'], true);
                            // vitals_data.forEach((data: any) => {
                            //     data.file_number = folder;
                            // });
                            // vitals_table = vitals_table.concat(vitals_data);

                            // // VAGeneralInfo tab
                            // const va_info_data = readExcelSheet(workbook, 'VAGeneralInfo');
                            // va_info_data.forEach((data: any) => {
                            //     data.file_number = folder;
                            // });
                            // va_info_table = va_info_table.concat(va_info_data);

                            // // CaseContacts tab
                            // const case_contacts_data = readExcelSheet(workbook, 'CaseContacts');
                            // if (case_contacts_data.length !== 0) {
                            //     case_contacts_data.forEach((data: any) => {
                            //         data.file_number = folder;
                            //     });
                            //     case_contacts_table = case_contacts_table.concat(case_contacts_data);
                            // }
                        }
                    }

                    // // Populate database with all the dataframes
                    // writeToDatabase('FuneralHomeData', funeral_home_table, db_file);
                    // writeToDatabase('Vitals', vitals_table, db_file);
                    // writeToDatabase('VAGeneralInfo', va_info_table, db_file);
                    // writeToDatabase('CaseContacts', case_contacts_table, db_file);

                    // // Get Financials
                    // const contracts_path = path.join(directoryPath, folder, 'Contracts');
                    // const contract_files_path = fs.readdirSync(contracts_path);

                    // for (const file of contract_files_path) {
                    //     const current_file = path.join(contracts_path, file);
                    //     const workbook = xlsx.readFile(current_file);

                    //     // Contract tab
                    //     const contract_data = readExcelSheet(workbook, 'Contract', ['DateOfDeath', 'DateOfStatement']);
                    //     if (contract_data.length !== 0) {
                    //         contract_data.forEach((data: any) => {
                    //             data.file_number = folder;
                    //         });
                    //         contract_table = contract_table.concat(contract_data);
                    //     }

                    //     // Contract Sales Tax tab
                    //     const sales_tax_data = readExcelSheet(workbook, 'Sales Tax');
                    //     if (sales_tax_data.length !== 0) {
                    //         sales_tax_data.forEach((data: any) => {
                    //             data.file_number = folder;
                    //         });
                    //         sales_tax_table = sales_tax_table.concat(sales_tax_data);
                    //     }

                    //     // Contract Services tab
                    //     const services_data = readExcelSheet(workbook, 'Contract Services');
                    //     if (services_data.length !== 0) {
                    //         services_data.forEach((data: any) => {
                    //             data.file_number = folder;
                    //         });
                    //         services_table = services_table.concat(services_data);
                    //     }

                    //     // Contract Merchandise tab
                    //     const merchandise_data = readExcelSheet(workbook, 'Contract Merchandise');
                    //     if (merchandise_data.length !== 0) {
                    //         merchandise_data.forEach((data: any) => {
                    //             data.file_number = folder;
                    //         });
                    //         merchandise_table = merchandise_table.concat(merchandise_data);
                    //     }

                    //     // Contract Cash Advance tab
                    //     const cash_advance_data = readExcelSheet(workbook, 'Contract Cash Advance');
                    //     if (cash_advance_data.length !== 0) {
                    //         cash_advance_data.forEach((data: any) => {
                    //             data.file_number = folder;
                    //         });
                    //         cash_advance_table = cash_advance_table.concat(cash_advance_data);
                    //     }

                    //     // Contract Credit tab
                    //     const credit_data = readExcelSheet(workbook, 'Contract Credit');
                    //     if (credit_data.length !== 0) {
                    //         credit_data.forEach((data: any) => {
                    //             data.file_number = folder;
                    //         });
                    //         credit_table = credit_table.concat(credit_data);
                    //     }

                    //     // Contract Pending Payments tab
                    //     const pending_payment_data = readExcelSheet(workbook, 'Contract Pending Payments');
                    //     if (pending_payment_data.length !== 0) {
                    //         pending_payment_data.forEach((data: any) => {
                    //             data.file_number = folder;
                    //         });
                    //         pending_payment_table = pending_payment_table.concat(pending_payment_data);
                    //     }

                    //     // Contract Payments tab
                    //     const payment_data = readExcelSheet(workbook, 'Contract Payments', ['transaction_date']);
                    //     if (payment_data.length !== 0) {
                    //         payment_data.forEach((data: any) => {
                    //             data.file_number = folder;
                    //         });
                    //         payment_table = payment_table.concat(payment_data);
                    //     }

                    //     const buyers_data = readExcelSheet(workbook, 'Contract Buyers');
                    //     if (buyers_data.length !== 0) {
                    //         buyers_data.forEach((data: any) => {
                    //             data.file_number = folder;
                    //         });
                    //         buyers_table = buyers_table.concat(buyers_data);
                    //     }
                    // }

                    // // Populate database with all the dataframes
                    // writeToDatabase('Contract', contract_table, db_file);
                    // writeToDatabase('SalesTax', sales_tax_table, db_file);
                    // writeToDatabase('ContractServices', services_table, db_file);
                    // writeToDatabase('ContractMerchandise', merchandise_table, db_file);
                    // writeToDatabase('ContractCashAdvance', cash_advance_table, db_file);
                    // writeToDatabase('ContractCredit', credit_table, db_file);
                    // writeToDatabase('ContractPendingPayments', pending_payment_table, db_file);
                    // writeToDatabase('ContractPayments', payment_table, db_file);
                    // writeToDatabase('ContractBuyers', buyers_table, db_file);
                }
            }
        }
    } else {
        console.log(`${db_file} already exists... using that to query migration data`);
    }

    // switch (file_type) {
    // case FileType.DC:
    //     get_dc_data(db_file, client, dest);
    //     break;
    // case FileType.HELP:
    //     get_help_data(db_file, client, dest);
    //     break;
    // case FileType.FINANCE:
    //     get_finance_data(db_file, client, dest);
    //     break;
    // case FileType.DOCUMENTS:
    //     get_document_data(basePath, client, dest);
    //     break;
    //     default:
    //         console.error(`ERROR: ${file_type} is not a recognized file type!`);
    //         process.exit(1);
    // }
};

const readExcelSheet = (workbook: xlsx.WorkBook, sheetName: string, dateColumns: string[] = [], header: boolean = false): any[] => {
    const sheetData: any[] = xlsx.utils.sheet_to_json(workbook.Sheets[sheetName], { header: 1, dateNF: 'yyyy-mm-dd' });

    if (sheetData.length !== 0) {
        if (header) {
            // Add date format to specified date columns
            dateColumns.forEach((col) => {
                sheetData.forEach((row) => {
                    if (row[col] instanceof Date) {
                        row[col] = row[col].toISOString().split('T')[0];
                    }
                });
            });
        }

        return sheetData;
    }

    return [];
};

// const writeToDatabase = (tableName: string, data: any[], dbFilePath: string): void => {
//     if (data.length !== 0 && Array.isArray(data)) {
//         const db = new sqlite3.Database(dbFilePath);
//         const columns = Object.keys(data[0]);
//         const placeholders = columns.map(() => '?').join(', ');

//         const createTableQuery = `CREATE TABLE IF NOT EXISTS ${tableName} (${columns.map((col) => `[${col}] TEXT`).join(', ')})`;

//         db.run(createTableQuery);

//         const insertQuery = `INSERT INTO ${tableName} (${columns.join(', ')}) VALUES (${placeholders})`;
//         console.log('values', data);

//         data.forEach((row) => {
//             const values = columns.map((col) => row[col]);
//             db.run(insertQuery, values);
//         });

//         db.close();
//     }
// };

// init('/Users/kevinbratt/Downloads/UrbanUndertakers', '1000', '/Users/kevinbratt/Downloads', FileType.DC);

// const get_dc_data = (db_file: string, client: string, dest: string): void => {
//     const con = new sqlite3.Database(db_file);
//     const cur = con.prepare('SELECT * FROM YourTable'); // Replace YourTable with the actual table name
//     const rows = cur.all();

//     const cols = cur.columns();
//     const df = rows.map((row) => {
//         const obj: any = {};
//         cols.forEach((col) => {
//             obj[col] = row[col];
//         });
//         return obj;
//     });

//     df.to_csv(path.join(dest, `${client}_dc.csv`));
// };

// const get_help_data = (db_file: string, client: string, dest: string): void => {
//     const con = new sqlite3.Database(db_file);
//     const cur = con.prepare('SELECT *
