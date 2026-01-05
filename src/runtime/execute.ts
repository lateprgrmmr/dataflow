import { MigrationContext } from "./context";

export const executeRun = async (ctx: MigrationContext, steps: [string, (ctx: MigrationContext) => Promise<void>][]) => {
    for (const [stepName] of Object.entries(ctx.run.steps)) {
        const step = ctx.getStep(stepName);
        if (step.status === 'completed') {
            continue;
        }
        await ctx.startStep(stepName);
        try {
            await ctx.completeStep(stepName);
        } catch (error) {
            await ctx.failStep(stepName, error instanceof Error ? error : new Error(String(error)));
            throw error;
        }
    }
}
