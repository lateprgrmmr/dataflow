import path from 'path';
import fs from 'fs/promises';
import { Run } from '../shared/types';

export const generateRunFile = (xtothez: string) => {
    return {
        name: xtothez
    }
}

export const loadRun = async (runPath: string): Promise<Run> => {
    const runFile = path.join(runPath, 'run.json');
    const raw = await fs.readFile(runFile, 'utf8');
    return JSON.parse(raw);
}

export const saveRun = async (runPath: string, run: Run) => {
    const runFile = path.join(runPath, 'run.json');
    await fs.writeFile(runFile, JSON.stringify(run, null, 2));
}