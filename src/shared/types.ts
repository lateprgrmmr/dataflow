import chalk from "chalk";

export const colors = {
    error: chalk.bgRedBright.black,
    warning: chalk.yellow,
    success: chalk.green,
    info: chalk.blue,
};

export type ISODateTime = string;
export type Status = 'pending' | 'in_progress' | 'completed' | 'failed' | 'skipped';
export interface StepError {
    name: string;
    message: string;
    stack?: string;
}

export interface Step {
    status: Status;
    start_time?: ISODateTime;
    end_time?: ISODateTime;
    artifacts?: string[];
    metrics?: Record<string, number>;
    error?: StepError;
    notes?: string[];
}

export type Steps = Record<string, Step>;

export interface InputSource {
    adapter: string;
    type: string;
    path: string;
    checksum?: string;
    details?: Record<string, unknown>;
}

export interface Inputs {
    source: InputSource;
    config: {
        client: string;
        mappings?: string;
        checksum?: string;
    };
}

export interface Environment {
    orchestrator_version: string;
    host: string;
    timezone: string;
    docker_compose_hash?: string;
}

export interface RunError {
    message: string;
    occurred_at: ISODateTime;
    step?: string;
}

export interface Run {
    run_id: string;
    client_id: string;
    status: Status;
    created_time: ISODateTime;
    updated_time: ISODateTime;
    inputs: Inputs;
    environment: Environment;
    steps: Steps;
    errors?: RunError[];
    notes?: string[];
}