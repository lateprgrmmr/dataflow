import { MigrationContext, Vendor } from "../types";
import { FrontrunnerPipeline } from "./runners/frontrunner/extract";

export interface VendorPipeline {
    vendor: Vendor;

    extract(ctx: MigrationContext): Promise<void>;
    transform?(ctx: MigrationContext): Promise<void>;
}


export const vendorRegistry: Record<Vendor, VendorPipeline> = {
    [Vendor.frontrunner]: new FrontrunnerPipeline(),
};