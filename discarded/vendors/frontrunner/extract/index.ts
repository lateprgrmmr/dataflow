import { MigrationContext } from "../../../runtime/context";

export const buildFrontrunnerStagingViews = async (ctx: MigrationContext) => {
    const db = await ctx.getConnection();
    console.log('Building Frontrunner staging views...');

    // need to actually build the views here if they don't exist
    const sqlPath = ctx.vendorPath('staging/build_views.sql');
    const rawRecords = await db.staging.raw_records.find({
        run_id: ctx.run.run_id,
        source_system: 'frontrunner',
    });
    console.log('Found ', rawRecords.length, ' raw records to build views from.');
}

export const extractFrontrunnerCases = async (ctx: MigrationContext) => {
    const db = await ctx.getConnection();
    const sqlPath = ctx.vendorPath('staging/case_extract.sql');
    console.log(sqlPath);
    console.log('Extracting Frontrunner cases...');

    const sql = await ctx.loadSqlFile(sqlPath);

    console.log('SQL file loaded.');
    const result = await db.query(sql, [ctx.run.run_id]);
    return result;
}

export const stageFrontrunnerCasesToImport = async (ctx: MigrationContext, cases: any[]) => {
    const db = await ctx.getConnection();
    console.log('Staging Frontrunner cases to import table...');

    console.log('Found ', cases.length, ' cases to stage.');
}

export const extractFrontrunnerCaseContacts = async (ctx: MigrationContext) => {
    const db = await ctx.getConnection();
    const sqlPath = ctx.vendorPath('staging/contact_extract.sql');
    console.log(sqlPath);
    console.log('Extracting Frontrunner case contacts...');

    const sql = await ctx.loadSqlFile(sqlPath);
    const result = await db.query(sql, [ctx.run.run_id]);
    return result;
}