import { MigrationContext } from '../runtime/context';
import { runFrontrunnerPipeline } from './frontrunner/pipeline';

export const runVendorPipeline = async (ctx: MigrationContext) => {
    switch (ctx.vendor) {
        case 'frontrunner':
            return runFrontrunnerPipeline(ctx);
        default:
            throw new Error(`Unsupported vendor: ${ctx.vendor}`);
    }
}