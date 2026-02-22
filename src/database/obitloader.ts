import StreamArray from 'stream-json/streamers/StreamArray';
import { Connection } from "./database";
import ProgressBar from "progress";
import stream from 'stream';

import stringify from 'csv-stringify';
import { GatherCase, FuneralHome } from '../types/obitTypes';
import { BatchType } from '../types';

interface ValidationRecord {
    row_number: number;
    external_id: string;
    problem: string;
    action: string;
}

// export async function loadObitEntries(
//     db: Connection,
//     fhs: FuneralHome[],
//     datasource: string,
//     inputData: Buffer,
//     outData: NodeJS.WriteStream,
//     commit: boolean,
// ) {
//     const bufferStream = new stream.PassThrough();
//     bufferStream.end(inputData);
//     const pipeline = bufferStream.pipe(StreamArray.withParser());
//     let i = 0;
//     const records: GatherCase[] = [];
//     const badRecords: ValidationRecord[] = [];
//     await new Promise(fulfill => pipeline.on('data', async data => {
//         const obit: GatherCase = data.value;
//         i++;
//         try {
//             GatherCase.validate(obit);
//             const mutatedObit = obit as any;
//             // Sometimes there is no structured dod, but one was scraped from the obit text
//             if (!obit.decedent.date_of_death && (obit.decedent as any).obit_dod) {
//                 obit.decedent.date_of_death = (obit.decedent as any).obit_dod;
//             }
//             if (!obit.decedent.date_of_birth && (obit.decedent as any).obit_dob) {
//                 obit.decedent.date_of_birth = (obit.decedent as any).obit_dob;
//             }
//             records.push(obit);
//         } catch (ex) {
//             badRecords.push({
//                 row_number: i,
//                 external_id: obit.decedent && obit.decedent.external_id ? obit.decedent.external_id : 'not-found',
//                 problem: '',
//                 action: '',
//             });
//         }
//     }).on('finish', fulfill));

//     if (badRecords.length > 0) {
//         stringify({ header: true }, badRecords as any).pipe(outData);
//         throw `Input file validation failed. See validation column of output file for details`;
//     } else if (!commit) {
//         // If we aren't committing the records to the database then bail out at this point
//         return;
//     }

//     // Create a scrape batch
//     const scrapeId = await GatherDB.initObitScrape(db, datasource, fhs.map(f => f.id,));
//     // Show the user the obit_scrape.id
//     console.log(`dataload.obit_scrape.id = ${scrapeId}`);

//     // Create a dataload batch
//     const batchId = await GatherDB.createBatch(db, BatchType.Obit, fhs[0].id, records);

//     const bar = new ProgressBar(
//         'loading :bar :current/:total ext::row',
//         { total: records.length, width: 100 }
//     );

//     // Commit each of the records in the batch and update the status bar
//     const outRecords: ValidationRecord[] = [];
//     for (let i = 0; i < records.length; i++) {
//         const record = records[i];
//         const result = await GatherDB.processObitRecord(db, batchId, scrapeId, i + 1);
//         const outRecord: ValidationRecord = {
//             row_number: i,
//             external_id: record.decedent.external_id || '',
//             problem: '',
//             action: '',
//         };
//         if (!result.success) {
//             outRecord.problem = result.message;
//         } else {
//             outRecord.action = result.message;
//         }
//         bar.tick({
//             row: record.decedent.external_id,
//         });
//     }
//     stringify({ header: true }, outRecords as any).pipe(outData);
// }
