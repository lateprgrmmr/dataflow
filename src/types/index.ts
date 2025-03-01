export enum VendorEnum {
    arranger_adv = 'arranger_adv',
    aurora = 'aurora',
    batesville = 'batesville',
    crakn = 'crakn',
    directors_asst = 'directors_asst',
    funeralone = 'funeralone',
    frontrunner = 'frontrunner',
    fdm = 'fdm',
    funeraltech = 'funeraltech',
    halcyon = 'halcyon',
    last_writes = 'last_writes',
    mims = 'mims',
    mortware = 'mortware',
    none = 'none',
    osiris = 'osiris',
    parting_pro = 'parting_pro',
    passare = 'passare',
    salesforce = 'salesforce',
    srs = 'srs',
}

export enum VendorFileType {
    csv = 'csv', // Passare, FrontRunner, FuneralOne
    json = 'json', // Crakn
    xlsx = 'xlsx', // Osiris
    sql = 'sql', // Batesville, TDA, Mims, Mortware, Halcyon, SRS
    XXXX = 'XXXX', // FuneralTech
}

export enum VendorBatchType {
    batesville = 'sql',
    crakn = 'json',
    funeralone = 'csv',
    frontrunner = 'csv',
    funeraltech = 'XXXX',
    halcyon = 'sql',
    mims = 'sql',
    mortware = 'sql',
    osiris = 'xlsx',
    passare = 'csv',
    srs = 'sql',
    tda = 'sql',
}

export interface VendorBatch {
    [key: string]: VendorFileType;
};


export enum DataXformPart {
    dc = 'dc',
    help = 'help',
    finance = 'finance',
    docs = 'docs',
}

export interface TableData {
    id: number;
    data: any;
}

// Vendor-specific types
export enum PassareTableNames {
    DC1 = 'dc1',
    DC2 = 'dc2',
    Vet = 'vet',
    Help = 'help',
    GandS = 'gands',
    Payments = 'payments',
    Dash = 'dash',
    Docs = 'docs',
}

export const PassareTableNameMap = (fileName: string): string => {
    if (fileName.match(/.*cases_information.*/)) {
        return PassareTableNames.DC1;
    } else if (fileName.match(/.*DashboardCasesReport.*/)) {
        return PassareTableNames.DC2;
    } else if (fileName.match(/.*acquaintances_information.*/)) {
        return PassareTableNames.Help;
    } else if (fileName.match(/.*veterans_information.*/)) {
        return PassareTableNames.Vet;
    } else if (fileName.match(/.*goods_and_services.*/)) {
        return PassareTableNames.GandS;
    } else if (fileName.match(/.*payments_information.*/)) {
        return PassareTableNames.Payments;
    } else if (fileName.match(/.*DashboardContractsReport.*/)) {
        return PassareTableNames.Dash;
    } else {
        return 'SKIP';
    }
};

export enum FrontRunnerTableNames {
    AN_ClientInfo = 'AN_ClientInfo',
    PN_ClientInfo = 'PN_ClientInfo',
    ClientContacts = 'ClientContacts',
    ANContractValues = 'ANContractValues',
    ANContractAddlData = 'ANContractAddlData',
    PNContractValues = 'PNContractValues',
    PNContractAddlData = 'PNContractAddlData',
    ContractAddOnValues = 'ContractAddOnValues',
    ContractAddlAddOnData = 'ContractAddlAddOnData',
    Payments = 'Payments',
    Funding = 'Funding',
}

export const FrontRunnerTableNameMap = (fileName: string): string => {
    if (fileName.match(/.*AtNeed-ClientInfo.*/)) {
        // 'AtNeed-ClientInfo-Peaceful Rest Funeral Chapel-08-16-2023.csv',
        return FrontRunnerTableNames.AN_ClientInfo;
    } else if (fileName.match(/.*Preneed-ClientInfo.*/)) {
        // 'PreNeed-ClientInfo-Peaceful Rest Funeral Chapel-08-16-2023.csv',
        return FrontRunnerTableNames.PN_ClientInfo;
    } else if (fileName.match(/.*ClientContacts.*/)) {
        // 'ClientContacts-Peaceful Rest Funeral Chapel-08-16-2023.csv',
        return FrontRunnerTableNames.ClientContacts;
    } else if (fileName.match(/.*ANContractValues.*/)) {
        // 'ANContractValues-Peaceful Rest Funeral Chapel-08-16-2023.csv',
        return FrontRunnerTableNames.ANContractValues;
    } else if (fileName.match(/.*ANContractAddlData.*/)) {
        // 'ANContractAddlData-Peaceful Rest Funeral Chapel-08-16-2023.csv',
        return FrontRunnerTableNames.ANContractAddlData;
    } else if (fileName.match(/.*PNContractValues.*/)) {
        // 'PNContractValues-Peaceful Rest Funeral Chapel-08-16-2023.csv',
        return FrontRunnerTableNames.PNContractValues;
    } else if (fileName.match(/.*PNContractAddlData.*/)) {
        // 'PNContractAddlData-Peaceful Rest Funeral Chapel-08-16-2023.csv',
        return FrontRunnerTableNames.PNContractAddlData;
    } else if (fileName.match(/.*ContractAddOnValues.*/)) {
        // 'ContractAddOnValues-Peaceful Rest Funeral Chapel-08-16-2023.csv',
        return FrontRunnerTableNames.ContractAddOnValues;
    } else if (fileName.match(/.*ContractAddlAddOnData.*/)) {
        // 'ContractAddlAddOnData-Peaceful Rest Funeral Chapel-08-16-2023.csv',
        return FrontRunnerTableNames.ContractAddlAddOnData;
    } else if (fileName.match(/.*Payments.*/)) {
        // 'Payments-Peaceful Rest Funeral Chapel-08-16-2023.csv',
        return FrontRunnerTableNames.Payments;
    } else if (fileName.match(/.*Funding.*/)) {
        // 'Funding-Peaceful Rest Funeral Chapel-08-16-2023.csv',
        return FrontRunnerTableNames.Funding;
    } else {
        return 'SKIP';
    }
};

export const OsirisTableNameMap = (sheetName: string): string => {
    if (sheetName.match(/.*FuneralHomeData.*/)) {
        return 'FuneralHomeData';
    } else if (sheetName.match(/.*Vitals.*/)) {
        return 'Vitals';
    } else if (sheetName.match(/.*VAGeneralInfo.*/)) {
        return 'VAGeneralInfo';
    } else if (sheetName.match(/.*CaseContacts.*/)) {
        return 'CaseContacts';
    } else {
        return 'SKIP';
    }
};
