import { queryDatabase } from './database';

export const createTable = async (tableName: string, columns: string[]) => {
    const columnDefs = columns.map((col) => `${col} TEXT`).join(', ');
    const query = `CREATE TABLE IF NOT EXISTS ${tableName} (${columnDefs})`;
    await queryDatabase(query);
};

export const insertData = async (tableName: string, data: any[]) => {
    if (data.length === 0) {
        return;
    }
    const columns = Object.keys(data[0]);
    const placeholders = columns.map((_, index) => `$${index + 1}`).join(', ');
    const query = `INSERT INTO ${tableName} (${columns.join(', ')}) VALUES (${placeholders})`;

    const promises = data.map((row) => {
        return queryDatabase(query, Object.values(row));
    });

    await Promise.all(promises);
};