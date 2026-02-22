import path from 'path';
import fs from 'fs/promises';
import { Run, Step } from '../shared/types';
import { Connection, getConnection } from '../database/database';


export class MigrationContext {
    run: Run;
    runPath: string;
    clientName: string;
    vendor: string;

    constructor(clientName: string, vendor: string, runPath: string, run: Run) {
        this.run = run;
        this.runPath = runPath;
        this.clientName = clientName;
        this.vendor = vendor;
    }

    async getConnection(): Promise<Connection> {
        return await getConnection();
    }

    // respective path builders
    inputPath(relativePath: string): string {
        return path.join(this.runPath, 'input', relativePath);
    }

    workingPath(relativePath: string): string {
        return path.join(this.runPath, 'working', relativePath);
    }

    outputPath(relativePath: string): string {
        return path.join(this.runPath, 'output', relativePath);
    }

    // this will be src/vendors/{vendor}
    vendorPath(relativePath: string): string {
        return path.join(path.dirname(__dirname), 'vendors', this.vendor, relativePath);
    }

    // helpers
    async startStep(stepName: string, artifacts?: string[], metrics?: Record<string, number>): Promise<void> {
        const step = this.getStep(stepName);
        step.status = 'in_progress';
        step.start_time = new Date().toISOString();
        step.error = undefined;
        if (artifacts) {
            step.artifacts = artifacts;
        }
        if (metrics) {
            step.metrics = metrics;
        }
        await this.saveRun();
    }

    async completeStep(stepName: string, artifacts?: string[], metrics?: Record<string, number>): Promise<void> {
        const step = this.getStep(stepName);
        step.status = 'completed';
        step.end_time = new Date().toISOString();
        if (artifacts) {
            step.artifacts = artifacts;
        }
        if (metrics) {
            step.metrics = metrics;
        }
        await this.saveRun();
    }

    async failStep(stepName: string, error: Error): Promise<void> {
        const step = this.getStep(stepName);
        step.status = 'failed';
        step.error = { name: error.name, message: error.message, stack: error.stack };
        await this.saveRun();
    }

    getStep(stepName: string): Step {
        const step = this.run.steps[stepName];
        if (!step) {
            throw new Error(`Step ${stepName} not found`);
        }
        return step;
    }

    isStepCompleted(stepName: string): boolean {
        const step = this.getStep(stepName);
        return step.status === 'completed';
    }

    async loadSqlFile(sqlFilePath: string): Promise<string> {
        return await fs.readFile(sqlFilePath, 'utf8');
    }

    async saveRun(): Promise<void> {
        const runFile = path.join(this.runPath, 'run.json');
        await fs.writeFile(runFile, JSON.stringify(this.run, null, 2));
    }
    
}