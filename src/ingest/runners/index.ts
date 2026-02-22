import { MigrationContext } from "../../types";
import { vendorRegistry } from "../types";

export class VendorPipelineRunner {
    constructor(private readonly ctx: MigrationContext) { }

    async extract(ctx: MigrationContext) {
        const pipeline = vendorRegistry[ctx.vendor];
        await pipeline.extract(this.ctx);
    }
}