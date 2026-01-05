import { connectDatabase, Connection } from '../database/database';
import fs from 'fs';
import { parse } from 'csv-parse';
import { stringify } from 'csv-stringify';

interface InternalCase {
    id: string;
    first_name: string;
    last_name: string;
    date_of_death: string;
    [key: string]: any;
}

interface ExternalCase {
    id: string;
    first_name: string;
    last_name: string;
    date_of_death: string;
    [key: string]: any;
}

interface MatchResult {
    external_id: string;
    internal_id: string | null;
    matched: number;
    problem: string;
    external_first_name: string;
    external_last_name: string;
    external_dod: string;
    internal_first_name: string | null;
    internal_last_name: string | null;
    internal_dod: string | null;
}

async function parseCsv<T>(csvContent: string): Promise<T[]> {
    return new Promise((resolve, reject) => {
        parse(csvContent, {
            columns: true,
            skip_empty_lines: true,
        }, (err, output) => {
            if (err) reject(err);
            else resolve(output as T[]);
        });
    });
}

async function loadInternalCases(db: Connection, csvPath: string): Promise<void> {
    console.log(`Loading internal cases from ${csvPath}...`);

    const csvContent = fs.readFileSync(csvPath, 'utf-8');
    const records: InternalCase[] = await parseCsv<InternalCase>(csvContent);

    console.log(`Found ${records.length} internal cases`);

    // Create temp table
    await db.none(`
    DROP TABLE IF EXISTS temp_internal_case CASCADE;
    CREATE TEMP TABLE temp_internal_case (
      id TEXT PRIMARY KEY,
      first_name TEXT,
      last_name TEXT,
      date_of_death TEXT,
      key1 TEXT,
      key2 TEXT,
      key3 TEXT,
      key4 TEXT,
      key5 TEXT,
      key6 TEXT,
      external_case_id TEXT
    );
  `);

    // Insert data
    for (const record of records) {
        await db.none(`
      INSERT INTO temp_internal_case (id, first_name, last_name, date_of_death)
      VALUES ($1, $2, $3, $4)
    `, [record.id, record.first_name, record.last_name, record.date_of_death]);
    }

    // Generate keys using the clean_name function
    await db.none(`
    UPDATE temp_internal_case SET
      key1 = public.clean_name(first_name, last_name, date_of_death),
      key2 = public.clean_name(
        SUBSTRING(first_name FROM 1 FOR 3),
        SUBSTRING(last_name FROM 1 FOR 3),
        date_of_death
      ),
      key3 = public.clean_name(
        SUBSTRING(first_name FROM 1 FOR 3),
        SUBSTRING(SUBSTRING(last_name FROM '[^\\s-]*$') FROM 1 FOR 3),
        date_of_death
      ),
      key4 = public.clean_name(
        SUBSTRING(last_name FROM '[^\\s-]*$'),
        date_of_death,
        NULL
      ),
      key5 = public.clean_name(
        SUBSTRING(first_name FROM '^[^\\s-]*'),
        date_of_death,
        NULL
      ),
      key6 = public.clean_name(first_name, last_name, NULL)
  `);

    console.log('✓ Internal cases loaded and keys generated');
}

async function loadExternalCases(db: Connection, csvPath: string): Promise<void> {
    console.log(`Loading external cases from ${csvPath}...`);

    const csvContent = fs.readFileSync(csvPath, 'utf-8');
    const records: ExternalCase[] = await parseCsv<ExternalCase>(csvContent);

    console.log(`Found ${records.length} external cases`);

    // Create temp table
    await db.none(`
    DROP TABLE IF EXISTS temp_external_case CASCADE;
    CREATE TEMP TABLE temp_external_case (
      id TEXT PRIMARY KEY,
      first_name TEXT,
      last_name TEXT,
      date_of_death TEXT,
      key1 TEXT,
      key2 TEXT,
      key3 TEXT,
      key4 TEXT,
      key5 TEXT,
      key6 TEXT,
      gather_case_id TEXT,
      matched INTEGER DEFAULT 0,
      problem TEXT DEFAULT 'NONE'
    );
  `);

    // Insert data
    for (const record of records) {
        await db.none(`
      INSERT INTO temp_external_case (id, first_name, last_name, date_of_death)
      VALUES ($1, $2, $3, $4)
    `, [record.id, record.first_name, record.last_name, record.date_of_death]);
    }

    // Generate keys
    await db.none(`
    UPDATE temp_external_case SET
      key1 = public.clean_name(first_name, last_name, date_of_death),
      key2 = public.clean_name(
        SUBSTRING(first_name FROM 1 FOR 3),
        SUBSTRING(last_name FROM 1 FOR 3),
        date_of_death
      ),
      key3 = public.clean_name(
        SUBSTRING(first_name FROM 1 FOR 3),
        SUBSTRING(SUBSTRING(last_name FROM '[^\\s-]*$') FROM 1 FOR 3),
        date_of_death
      ),
      key4 = public.clean_name(
        SUBSTRING(last_name FROM '[^\\s-]*$'),
        date_of_death,
        NULL
      ),
      key5 = public.clean_name(
        SUBSTRING(first_name FROM '^[^\\s-]*'),
        date_of_death,
        NULL
      ),
      key6 = public.clean_name(first_name, last_name, NULL)
  `);

    console.log('✓ External cases loaded and keys generated');
}

async function runMatchingAlgorithm(db: Connection): Promise<void> {
    console.log('\nRunning matching algorithm...');

    // FIRST PASS - KEY1
    console.log('  Pass 1: KEY1 (exact match)...');
    await db.none(`
    WITH dup AS(
      SELECT gc.id AS gather_case_id,
        gc.key1,
        COUNT(gc.id) OVER(PARTITION BY gc.key1) AS dups
      FROM temp_internal_case AS gc
      WHERE gc.external_case_id IS NULL
    )
    UPDATE temp_external_case AS obit SET
      gather_case_id = CASE WHEN dup.dups > 1 THEN NULL ELSE dup.gather_case_id END,
      matched = 1,
      problem = CASE WHEN dup.dups > 1 THEN 'AMBIGUOUS' ELSE 'NONE' END
    FROM dup
    WHERE obit.matched = 0 AND dup.key1 = obit.key1
  `);

    await db.none(`
    UPDATE temp_internal_case AS ic
    SET external_case_id = ex.id
    FROM temp_external_case AS ex
    WHERE ic.external_case_id IS NULL
      AND ex.problem = 'AMBIGUOUS'
      AND ic.key1 = ex.key1
  `);

    await db.none(`
    WITH canonical AS (
      SELECT MAX(id) AS external_case_id, gather_case_id
      FROM temp_external_case
      WHERE gather_case_id IS NOT NULL AND matched = 1
      GROUP BY gather_case_id
    )
    UPDATE temp_internal_case AS internal
    SET external_case_id = canonical.external_case_id
    FROM canonical
    WHERE canonical.gather_case_id = internal.id
      AND internal.external_case_id IS NULL
  `);

    // SECOND PASS - KEY2
    console.log('  Pass 2: KEY2 (first 3 + last 3)...');
    await runPass(db, 2, 'key2');

    // THIRD PASS - KEY3
    console.log('  Pass 3: KEY3 (first 3 + last token 3)...');
    await runPass(db, 3, 'key3');

    // FOURTH PASS - KEY4
    console.log('  Pass 4: KEY4 (last token + DOD)...');
    await runPass(db, 4, 'key4');

    // FIFTH PASS - KEY5
    console.log('  Pass 5: KEY5 (first token + DOD)...');
    await runPass(db, 5, 'key5');

    // SIXTH PASS - KEY6
    console.log('  Pass 6: KEY6 (first + last, no DOD)...');
    await runPass(db, 6, 'key6');

    // Mark duplicates
    await db.none(`
    UPDATE temp_external_case AS obit
    SET problem = 'DUPLICATE'
    FROM temp_internal_case AS gc
    WHERE obit.gather_case_id = gc.id
      AND gc.external_case_id != obit.id
  `);

    console.log('✓ Matching complete');
}

async function runPass(db: Connection, passNum: number, keyField: string): Promise<void> {
    await db.none(`
    WITH dup AS(
      SELECT gc.id AS gather_case_id,
        gc.${keyField},
        COUNT(gc.id) OVER(PARTITION BY gc.${keyField}) AS dups
      FROM temp_internal_case AS gc
      WHERE gc.external_case_id IS NULL
    )
    UPDATE temp_external_case AS obit SET
      gather_case_id = CASE WHEN dup.dups > 1 THEN NULL ELSE dup.gather_case_id END,
      matched = ${passNum},
      problem = CASE WHEN dup.dups > 1 THEN 'AMBIGUOUS' ELSE 'NONE' END
    FROM dup
    WHERE obit.matched = 0 AND dup.${keyField} = obit.${keyField}
  `);

    await db.none(`
    UPDATE temp_internal_case AS ic
    SET external_case_id = ex.id
    FROM temp_external_case AS ex
    WHERE ic.external_case_id IS NULL
      AND ex.problem = 'AMBIGUOUS'
      AND ic.${keyField} = ex.${keyField}
  `);

    await db.none(`
    WITH canonical AS (
      SELECT MAX(id) AS external_case_id, gather_case_id
      FROM temp_external_case
      WHERE gather_case_id IS NOT NULL AND matched = ${passNum}
      GROUP BY gather_case_id
    )
    UPDATE temp_internal_case AS internal
    SET external_case_id = canonical.external_case_id
    FROM canonical
    WHERE canonical.gather_case_id = internal.id
      AND internal.external_case_id IS NULL
  `);
}

async function exportResults(db: Connection, outputPath: string): Promise<void> {
    console.log('\nExporting results...');

    const results: MatchResult[] = await db.any(`
    SELECT 
      ex.id as external_id,
      ex.gather_case_id as internal_id,
      ex.matched,
      ex.problem,
      ex.first_name as external_first_name,
      ex.last_name as external_last_name,
      ex.date_of_death as external_dod,
      ic.first_name as internal_first_name,
      ic.last_name as internal_last_name,
      ic.date_of_death as internal_dod
    FROM temp_external_case ex
    LEFT JOIN temp_internal_case ic ON ex.gather_case_id = ic.id
    ORDER BY 
      CASE ex.problem
        WHEN 'NONE' THEN 1
        WHEN 'AMBIGUOUS' THEN 2
        WHEN 'DUPLICATE' THEN 3
        ELSE 4
      END,
      ex.matched DESC,
      ex.id
  `);

    const csv = await new Promise<string>((resolve, reject) => {
        stringify(results, {
            header: true,
            columns: [
                { key: 'external_id', header: 'External ID' },
                { key: 'internal_id', header: 'Matched Internal ID' },
                { key: 'matched', header: 'Match Level' },
                { key: 'problem', header: 'Problem' },
                { key: 'external_first_name', header: 'External First Name' },
                { key: 'external_last_name', header: 'External Last Name' },
                { key: 'external_dod', header: 'External DOD' },
                { key: 'internal_first_name', header: 'Internal First Name' },
                { key: 'internal_last_name', header: 'Internal Last Name' },
                { key: 'internal_dod', header: 'Internal DOD' },
            ]
        }, (err, output) => {
            if (err) reject(err);
            else resolve(output);
        });
    });

    fs.writeFileSync(outputPath, csv);

    // Print statistics
    const stats = {
        total: results.length,
        matched: results.filter(r => r.internal_id && r.problem === 'NONE').length,
        ambiguous: results.filter(r => r.problem === 'AMBIGUOUS').length,
        duplicate: results.filter(r => r.problem === 'DUPLICATE').length,
        notMatched: results.filter(r => !r.internal_id && r.problem === 'NONE').length,
    };

    console.log('\n✓ Results exported to:', outputPath);
    console.log('\n📊 Statistics:');
    console.log(`  Total External Cases: ${stats.total}`);
    console.log(`  Matched: ${stats.matched} (${Math.round(stats.matched / stats.total * 100)}%)`);
    console.log(`  Not Matched: ${stats.notMatched}`);
    console.log(`  Ambiguous: ${stats.ambiguous}`);
    console.log(`  Duplicates: ${stats.duplicate}`);

    const byLevel: Record<number, number> = {};
    for (let i = 1; i <= 6; i++) {
        byLevel[i] = results.filter(r => r.matched === i && r.problem === 'NONE').length;
    }
    console.log('\n  By Match Level:');
    for (let i = 1; i <= 6; i++) {
        console.log(`    Level ${i}: ${byLevel[i]}`);
    }
}

async function main() {
    const args = process.argv.slice(2);

    if (args.length < 2) {
        console.error('Usage: ts-node src/database/matcher.ts <internal.csv> <external.csv> [output.csv]');
        console.error('\nExample:');
        console.error('  ts-node src/database/matcher.ts internal_cases.csv external_obits.csv results.csv');
        process.exit(1);
    }

    const internalCsv = args[0];
    const externalCsv = args[1];
    const outputCsv = args[2] || 'matching_results.csv';

    if (!fs.existsSync(internalCsv)) {
        console.error(`Error: File not found: ${internalCsv}`);
        process.exit(1);
    }

    if (!fs.existsSync(externalCsv)) {
        console.error(`Error: File not found: ${externalCsv}`);
        process.exit(1);
    }

    console.log('🔍 Case Matching Tool\n');
    console.log(`Internal CSV: ${internalCsv}`);
    console.log(`External CSV: ${externalCsv}`);
    console.log(`Output CSV: ${outputCsv}\n`);

    const db = await connectDatabase();

    try {
        await loadInternalCases(db, internalCsv);
        await loadExternalCases(db, externalCsv);
        await runMatchingAlgorithm(db);
        await exportResults(db, outputCsv);

        console.log('\n✅ Done!');
    } catch (error) {
        console.error('\n❌ Error:', error);
        process.exit(1);
    } finally {
        await db.$pool.end();
    }
}

main();