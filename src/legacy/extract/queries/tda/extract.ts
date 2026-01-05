import * as dfd from "danfojs-node";

const pathName = '/Users/kevinbratt/Downloads/sql_runner_wwnsq8fntvn5hy_2023-12-12_22-57-45.csv';

dfd.readCSV(pathName) //assumes file is in CWD
    .then(df => {

        df.head().print()
        console.log(df.columns);

    }).catch(err => {
        console.log(err);
    })