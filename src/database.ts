// Purpose: Database connection and configuration.
import massive, { Database } from "massive";
import { Pool } from "pg";
import dotenv from "dotenv";
dotenv.config();

const dbConfig = {
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT || '5432'),
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    ssl: false
};

let dbInstance: Database | null = null;

export const connectDb = async (): Promise<Database> => {
    if (!dbInstance) {
        const db = await massive(dbConfig);
        dbInstance = db;
    }
    return dbInstance;
};

export const queryDatabase = async (query: string, params: any[] = []) => {
    const db = await connectDb();
    return db.query(query, params);
};

export default connectDb;