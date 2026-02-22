import { MigrationContext } from "../../runtime/context";
import { ingestCsvToRawStaging } from "../../runtime/ingest/csv";
import { FrontRunnerSteps } from "../../shared/types";
import {
    buildFrontrunnerStagingViews,
    extractFrontrunnerCaseContacts,
    extractFrontrunnerCases,
    // stageFrontrunnerCasesToImport
} from "./extract";

export const runFrontrunnerPipeline = async (ctx: MigrationContext) => {
    console.log('Running Frontrunner pipeline...');
    const steps = ctx.run.steps;

    if (!ctx.isStepCompleted(FrontRunnerSteps.ProcessCsvDirectory)) {
        console.log('Steps:', steps.process_csv_directory.status);
        // Ingest CSV data
        await ctx.startStep(FrontRunnerSteps.ProcessCsvDirectory);
        try {
            await ingestCsvToRawStaging(ctx);
            await ctx.completeStep(FrontRunnerSteps.ProcessCsvDirectory, []);
            console.log('CSV data extracted.');
        } catch (error) {
            await ctx.failStep(FrontRunnerSteps.ProcessCsvDirectory, error as Error);
            throw error;
        }
    } else {
        // skipping, already completed
        console.log('CSV data already extracted.');
    }
    if (!ctx.isStepCompleted(FrontRunnerSteps.BuildFrontrunnerStagingViews)) {
        // Stage data to Postgres
        await ctx.startStep(FrontRunnerSteps.BuildFrontrunnerStagingViews);
        try {
            await buildFrontrunnerStagingViews(ctx);
            await ctx.completeStep(FrontRunnerSteps.BuildFrontrunnerStagingViews, []);
            console.log('Postgres data staged.');
        } catch (error) {
            await ctx.failStep(FrontRunnerSteps.BuildFrontrunnerStagingViews, error as Error);
            throw error;
        }
    } else {
        // skipping, already completed
        console.log('Postgres data already staged.');
    }

    // Extract cases from Postgres
    // this is idempotent, so we can run it multiple times
    await ctx.startStep(FrontRunnerSteps.ExtractFrontrunnerCases);
    try {
        await extractFrontrunnerCases(ctx);
        await ctx.completeStep(FrontRunnerSteps.ExtractFrontrunnerCases, []);
        console.log('Cases extracted.');
    } catch (error) {
        await ctx.failStep(FrontRunnerSteps.ExtractFrontrunnerCases, error as Error);
        throw error;
    }

    // Extract contacts from Postgres
    await ctx.startStep(FrontRunnerSteps.ExtractFrontrunnerCaseContacts);
    try {
        await extractFrontrunnerCaseContacts(ctx);
        await ctx.completeStep(FrontRunnerSteps.ExtractFrontrunnerCaseContacts, []);
        console.log('Contacts extracted.');
    } catch (error) {
        await ctx.failStep(FrontRunnerSteps.ExtractFrontrunnerCaseContacts, error as Error);
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