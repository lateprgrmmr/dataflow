import fs from "fs/promises";
import { MigrationContext } from "../../runtime/context";
import path from "path";
import { parse } from "csv-parse/sync";

export const ingestCsvToRawStaging = async (ctx: MigrationContext) => {
    const db = await ctx.getConnection();
    console.log('Extracting CSV data...');

    const inputPath = ctx.inputPath("");
    const files = await fs.readdir(inputPath);

    let totalRows = 0;
    for (const file of files) {
        if (!file.endsWith('.csv')) {
            continue;
        }
        const filePath = path.join(inputPath, file);
        const fileContent = await fs.readFile(filePath, 'utf8');

        const records = parse(fileContent, {
            columns: true,
            skip_empty_lines: true,
            trim: true,
        });

        try {
            console.log(`Inserting ${file} records into raw staging...`);
            let rowNumber = 1;
            for (const record of records) {
                await db.staging.raw_records.insert({
                    run_id: ctx.run.run_id,
                    source_system: ctx.vendor,
                    source_file: file,
                    row_number: rowNumber++,
                    data: record,
                });
                totalRows++;
            }
        } catch (error) {
            throw error;
        }
    }
    console.log('Inserted ', totalRows, ' records into raw staging.');
    return;
}