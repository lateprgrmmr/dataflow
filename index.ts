import meow from 'meow';
import chalk from 'chalk';
import fs from 'fs';
import os from 'os';
// import getStdin from 'get-stdin';
import { DataXformPart, getVendorEnum, MigrationContext, Vendor } from './src/types';
import path from 'path';
import { connectDatabase, Connection } from './src/database/database';
import { VendorPipelineRunner } from './src/ingest/runners';
import { v4 as uuidv4 } from 'uuid';
import { getMigrationTempDir } from './src/shared/constants';
import { findOrCreateMigration } from './src/database/api';

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
            choices: Object.values(Vendor),
        },
        clientName: {
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
            isMultiple: false,
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

type FlagType = typeof cli.flags;

async function main(flags: FlagType) {
    // console.log('flags', flags);
    const vendorInput = cli.flags.vendor as string | undefined;

    if (!vendorInput) {
        throw new Error(`ERROR: Missing --vendor flag`);
    }

    const vendor = getVendorEnum(vendorInput);
    if (!vendor) {
        throw new Error(`ERROR: Invalid vendor ${vendorInput}`);
    }

    const db: Connection = await connectDatabase();
    const vendorRecord = await db.vendor.find({
        key: vendor,
    });
    if (!vendorRecord || vendorRecord.length === 0) {
        throw new Error(`ERROR: Vendor ${vendorInput} not found in the database`);
    };
    console.log(`vendorRecord`, vendorRecord);
    const migrationRecord = await findOrCreateMigration(db, flags.clientName, vendorRecord[0].id);
    console.log(`Using migration ${migrationRecord.id} for client ${flags.clientName} and vendor ${vendorInput}`);
    console.log(`Migration record: ${JSON.stringify(migrationRecord, null, 2)}`);

    const outputDir = getMigrationTempDir(flags.clientName);
    const ctx: MigrationContext = {
        migration_id: migrationRecord.id,
        vendor,
        clientname: flags.clientName,
        type: flags.type as DataXformPart,
        inputPath: flags.inputFile,
        outputDir: outputDir,
        db,
    }

    const runner = new VendorPipelineRunner(ctx);
    // Based on vendor, determine which process to run to extract data and build tables in staging schema
    // Lookup VendorFileType based on flags.vendor (this is the format we received the data in)
    // Lookup VendorBatchType based on flags.vendor, bearing in mind that flags.vendor is a string and can't be used as an index
    // const vendorKey = Object.keys(Vendor).find(key => Vendor[key as keyof typeof Vendor] === flags.vendor.toLowerCase());

    const vendorKey = getVendorEnum(vendor)
    if (vendorKey === undefined) {
        throw new Error(`Vendor must be one of ${Object.values(Vendor)}`);
    }

    switch (flags.process) {
        case "extract":
            await runner.extract(ctx);
            break;
        case "transform":
            // await runner.transform?.(ctx);
            break;
        default:
            throw new Error(`Unknown process ${flags.process}`);
    }
}

main(cli.flags);
