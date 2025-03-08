

export const EXCLUDED_FILES = [
    // FrontRunner
    /^CompanyInfo.*/,
    /^ContractConfiguration.*/,
    /^Employees.*/,
    /^FinancialTransactions.*/,
    /^Inventory.*/,
    /^Obituaries.*/,
    /^Products.*/,
    /^SetupData.*/,
    /^Timesheets.*/,
    /^Vendors.*/,
];

export const shouldExcludeFile = (filename: string) => {
    return EXCLUDED_FILES.some(pattern => {
        return typeof pattern === 'string' ? pattern === filename : pattern.test(filename);
    });
};

export const tableNameMap = {
    // FrontRunner
    'CompanyInfo.csv': 'company_info',
    'ContractConfiguration.csv': 'contract_configuration',
    'Employees.csv': 'employees',
    'FinancialTransactions.csv': 'financial_transactions',
    'Inventory.csv': 'inventory',
    'Products.csv': 'products',
    'SetupData.csv': 'setup_data',
    'Timesheets.csv': 'timesheets',

    // Passare
}
