import * as fs from 'fs';
import { MigrationContext, Vendor } from '../../../types';
import { stageCsvData } from '../../csvBatch';
import { VendorPipeline } from '../../types';
import path from 'path';

export class FrontrunnerPipeline implements VendorPipeline {
    vendor = Vendor.frontrunner;

    async extract(ctx: MigrationContext) {

        const stat = fs.statSync(ctx.inputPath);
        if (!stat.isDirectory()) {
            throw new Error("FrontRunner input must be a directory");
        }
        await stageCsvData(ctx);
    }

    buildStagingViews = async (ctx: MigrationContext) => {
        console.log('Building Frontrunner staging views...');
    
        // need to actually build the views here if they don't exist
        const sqlPath = path.join(__dirname, '../../../vendors/frontrunner/staging/build_views.sql');
        const rawRecords = await ctx.db.raw_records.find({
            migration_id: ctx.migration_id,
        });
        console.log('Found ', rawRecords.length, ' raw records to build views from.');
    }
}


