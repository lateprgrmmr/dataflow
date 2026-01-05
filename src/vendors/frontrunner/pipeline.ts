import { MigrationContext } from "../../runtime/context";
import { ingestCsvToRawStaging } from "../../runtime/ingest/csv";
import {
    buildFrontrunnerStagingViews,
    extractFrontrunnerCaseContacts,
    extractFrontrunnerCases,
    // stageFrontrunnerCasesToImport
} from "./extract";

export const runFrontrunnerPipeline = async (ctx: MigrationContext) => {
    console.log('Running Frontrunner pipeline...');
    const steps = ctx.run.steps;

    if (!ctx.isStepCompleted('process_csv_directory')) {
        console.log('Steps:', steps.process_csv_directory.status);
        // Ingest CSV data
        await ctx.startStep('process_csv_directory');
        try {
            await ingestCsvToRawStaging(ctx);
            await ctx.completeStep('process_csv_directory', []);
            console.log('CSV data extracted.');
        } catch (error) {
            await ctx.failStep('process_csv_directory', error as Error);
            throw error;
        }
    } else {
        // skipping, already completed
        console.log('CSV data already extracted.');
    }
    if (!ctx.isStepCompleted('build_frontrunner_staging_views')) {
        // Stage data to Postgres
        await ctx.startStep('build_frontrunner_staging_views');
        try {
            await buildFrontrunnerStagingViews(ctx);
            await ctx.completeStep('build_frontrunner_staging_views', []);
            console.log('Postgres data staged.');
        } catch (error) {
            await ctx.failStep('build_frontrunner_staging_views', error as Error);
            throw error;
        }
    } else {
        // skipping, already completed
        console.log('Postgres data already staged.');
    }

    // Extract cases from Postgres
    // this is idempotent, so we can run it multiple times
    await ctx.startStep('extract_frontrunner_cases');
    try {
        await extractFrontrunnerCases(ctx);
        await ctx.completeStep('extract_frontrunner_cases', []);
        console.log('Cases extracted.');
    } catch (error) {
        await ctx.failStep('extract_frontrunner_cases', error as Error);
        throw error;
    }

    // Extract contacts from Postgres
    await ctx.startStep('extract_frontrunner_contacts');
    try {
        await extractFrontrunnerCaseContacts(ctx);
        await ctx.completeStep('extract_frontrunner_contacts', []);
        console.log('Contacts extracted.');
    } catch (error) {
        await ctx.failStep('extract_frontrunner_contacts', error as Error);
        throw error;
    }

    // // stage cases to import table
    // await ctx.startStep('stage_frontrunner_cases_to_import');
    // try {
    //     await stageFrontrunnerCasesToImport(ctx);
    //     await ctx.completeStep('stage_frontrunner_cases_to_import', []);
    //     console.log('Cases staged to import table.');
    // } catch (error) {
    //     await ctx.failStep('stage_frontrunner_cases_to_import', error as Error);
    //     throw error;
    // }

    console.log('Steps:', JSON.stringify(steps, null, 2));
}