import meow from 'meow';
import chalk from 'chalk';
import { loadRun } from './runtime/run';
import { MigrationContext } from './runtime/context';
import { colors } from './shared/types';
import { runVendorPipeline } from './vendors';

const cli = meow(
    `
    Usage
    $ dataflow <vendor> <run-path>

    Options
    --vendor, -v Vendor name
    --run-path, -r Run path

    Examples
    $ dataflow frontrunner runs/frontrunner_test/run.json
    `, {
    flags: {
        vendor: {
            type: 'string',
            alias: 'v',
            isRequired: true,
        },
        clientName: {
            type: 'string',
            alias: 'f',
            isRequired: true,
            isMultiple: false,
        },
        runPath: {
            type: 'string',
            alias: 'r',
            isRequired: true,
        },
    },
    inferType: true,
});

type FlagType = typeof cli.flags;

async function main(flags: FlagType) {
    const { vendor, clientName, runPath } = flags;

    const run = await loadRun(runPath);
    const context = new MigrationContext(clientName, vendor, runPath, run);
    await runVendorPipeline(context);
    console.log(colors.success(`Migration complete. Check ${context.runPath}/run.json for updated statuses.`));

}

main(cli.flags)
    .catch(ex => {
        console.error(colors.error`ERROR` + ` ` + chalk.red(ex));
        // cli.showHelp();
    });