import meow from 'meow';
import chalk from 'chalk';
import fs from 'fs';
import os from 'os';
// import getStdin from 'get-stdin';
import { DataXformPart, VendorEnum, VendorBatchType, VendorFileType } from './src/types';
import { csvBatch } from './src/extract/csvBatch';
import { jsonExport } from './src/extract/jsonExport';
import { xlsxBatch } from './src/extract/xlsxBatch';
import { getVendorBatchType } from './src/shared/utils';
import { xlsxExport } from './src/extract/newXlsx';
import path from 'path';

const cli = meow(
    chalk`{underline Usage}
    {italic $ dataxform -v <vendor> -f <funeralHomeId> -t <type> -p <process> -i <input>}

  {underline Options}
    {bold --vendor, -v} Vendor name
    {bold --funeralHomeId, -f} Funeral Home ID
    {bold --type, -t} Type of data ${chalk.dim('(dc, help, finance, docs)')}
    {bold --process, -p} Process to run ${chalk.dim('(extract, transform, load)')}
    {bold --input, -i} Path to input file(s)
    {bold --commit, -c} Commit changes to database ${chalk.red('WARNING: This will overwrite existing database!')}

  {underline Examples}
    {italic dataxform -v crakn -f 1234 -t dc -p extract -i /path/to/file.json}
`, {
    flags: {
        vendor: {
            type: 'string',
            alias: 'v',
            isRequired: true,
            isMultiple: false,
            choices: Object.values(VendorEnum),
        },
        funeralHomeId: {
            type: 'string',
            alias: 'f',
            isRequired: true,
            isMultiple: false,
        },
        type: {
            type: 'string',
            alias: 't',
            isRequired: true,
            isMultiple: false,
            choices: Object.values(DataXformPart),
        },
        process: {
            type: 'string',
            alias: 'p',
            isRequired: true,
            isMultiple: false,
            choices: ['extract', 'transform'], //, 'load'], ??
        },
        inputFile: {
            type: 'string',
            alias: 'i',
            isRequired: true,
            isMultiple: true,
        },
        commit: {
            type: 'boolean',
            alias: 'c',
            isRequired: false,
            isMultiple: false,
            default: false,
        }
    },
    inferType: true,
});

type DataXformFlags = typeof cli.flags;

async function main(flags: DataXformFlags) {
    console.log('flags', flags);
    const fhId: number = parseInt(flags.funeralHomeId);
    const process: string = flags.process;
    const type: string = flags.type;
    let inputData = Buffer;
    const fstat = fs.statSync(flags.inputFile[0]);
    // Setup the output directory
    // const outputDir = `~/migration_temp/output/${fhId}`;
    const outputDir = path.join(os.homedir(), 'migration_temp', 'output', fhId.toString());
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
    }

    // Based on vendor, determine which process to run to extract data and build tables in staging schema
    // Lookup VendorFileType based on flags.vendor (this is the format we received the data in)
    // Lookup VendorBatchType based on flags.vendor, bearing in mind that flags.vendor is a string and can't be used as an index
    const vendorKey = Object.keys(VendorEnum).find(key => VendorEnum[key as keyof typeof VendorEnum] === flags.vendor.toLowerCase());
    const vendorFileType = getVendorBatchType(vendorKey as VendorEnum);
    // console.log('vendorFileType', vendorFileType);
    if (vendorFileType) {
        switch (vendorFileType) {
            case 'json':
                if (!fstat.isFile()) { // Crakn data is in a single JSON file
                    throw new Error('Input file must be a file');
                }
                jsonExport(VendorEnum.crakn, fhId, flags.inputFile[0])
                    .then((result) => {
                        console.log(result);
                    })
                    .catch((error) => {
                        console.error(`Error processing JSON file: ${error.message}`);
                    });
                break;
            case 'csv':
                console.log('CSV', vendorFileType);
                break;
            case 'xlsx':
                console.log('XLSX', vendorFileType);
                xlsxExport(VendorEnum.osiris, fhId, flags.inputFile[0]);
                break;
            case 'sql':
                console.log('SQL', vendorFileType);
                break;
            default:
                console.log('XXXXX', vendorFileType);
        }
    }
}




// try {
//     switch (flags.vendor) {
//         case Vendor.batesville:
//             break;
//         case Vendor.crakn:
//             if (!fstat.isFile()) { // Crakn data is in a single JSON file
//                 throw new Error('Input file must be a file');
//             }
//             jsonExport(Vendor.crakn, fhId, flags.inputFile[0])
//                 .then((result) => {
//                     console.log(result);
//                 })
//                 .catch((error) => {
//                     console.error(`Error processing JSON file: ${error.message}`);
//                 });
//             break;
//         case Vendor.frontrunner:
//             if (!fstat.isDirectory()) { // FrontRunner data is in a directory of CSVs
//                 throw new Error('Input must be a directory');
//             }
//             csvBatch(Vendor.frontrunner, fhId, flags.inputFile[0])
//                 .then((result) => {
//                     console.log(result);
//                 })
//                 .catch((error) => {
//                     console.error(`Error processing CSV files: ${error.message}`);
//                 });
//             break;
//         case Vendor.funeraltech:
//             break;
//         case Vendor.halcyon:
//             break;
//         case Vendor.mims:
//             break;
//         case Vendor.mortware:
//             break;
//         case Vendor.osiris:
//             if (!fstat.isDirectory()) { // Osiris data is in a nested directory of XLSXs
//                 throw new Error('Input must be a directory');
//             }
//             xlsxBatch(Vendor.osiris, fhId, flags.inputFile[0]);
//             break;
//         case Vendor.passare:
//             if (!fstat.isDirectory()) { // Passare data is in a directory of CSVs
//                 throw new Error('Input must be a directory');
//             }
//             csvBatch(Vendor.passare, fhId, flags.inputFile[0])
//                 .then((result) => {
//                     console.log(result);
//                 })
//                 .catch((error) => {
//                     console.error(`Error processing CSV files: ${error.message}`);
//                 });
//             break;
//         case Vendor.srs:
//             break;
//         case Vendor.tda:
//             break;

//         default:
//             throw new Error('Unknown vendor');
//     }
// } catch (err) {
//     throw `error: ${(err as NodeJS.ErrnoException).message}`;
// }

main(cli.flags);
