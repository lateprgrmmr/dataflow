import Massive from "massive";
import dotenv from 'dotenv';
import massive from "massive";

dotenv.config();

declare module 'massive' {
    interface Database {
        // Add any custom methods or properties here
        trace: (on: boolean, reason: string) => void;
    }
}

const dbConfig: massive.ConnectionInfo = {
    host: process.env.POSTGRES_HOST,
    port: parseInt(process.env.POSTGRES_PORT || '5432'),
    database: process.env.POSTGRES_DB,
    user: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
};

let db: Massive.Database;

export type Connection = Massive.Database;

export const connectDatabase = async (connInfo: Partial<massive.ConnectionInfo> = dbConfig): Promise<massive.Database> => {
    if (db) {
        return db;
    }
    db = await massive({...dbConfig, ...connInfo}, {
        scripts: 'src/database/scripts',
    })
    return db;
}

export const getConnection = async (): Promise<Massive.Database> => {
    const connInfo: Partial<massive.ConnectionInfo> = dbConfig;
    return await connectDatabase(connInfo);
};

