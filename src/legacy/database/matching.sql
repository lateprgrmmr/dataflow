-- FIRST PASS
WITH dup AS(
    SELECT gc.id AS gather_case_id,
            gc.key1,
            COUNT(gc.id) OVER(PARTITION BY gc.key1) AS dups
        FROM dataload.internal_case AS gc
        WHERE gc.obit_scrape_id = ${obit_scrape_id} 
            AND gc.external_case_id IS NULL
)
UPDATE dataload.external_case AS obit SET
    gather_case_id = CASE WHEN dup.dups > 1 THEN NULL ELSE dup.gather_case_id END,
    matched = 1,
    problem = CASE WHEN dup.dups > 1 THEN 'AMBIGUOUS'::dataload.scrape_problem ELSE 'NONE'::dataload.scrape_problem END
FROM dup
WHERE
    obit.matched = 0
    AND dup.key1 = obit.key1
;

UPDATE dataload.internal_case AS ic
SET external_case_id = ex.id
FROM dataload.external_case AS ex
WHERE ic.obit_scrape_id = ${obit_scrape_id}
    AND ic.external_case_id IS NULL
    AND ex.obit_scrape_id = ic.obit_scrape_id
    AND ex.problem = 'AMBIGUOUS'
    AND ic.key1 = ex.key1
;

WITH canonical AS (
    SELECT MAX(id) AS external_case_id,
        gather_case_id
    FROM dataload.external_case
    WHERE gather_case_id IS NOT NULL
        AND matched = 1
        AND obit_scrape_id = ${obit_scrape_id} 
    GROUP BY gather_case_id
)
UPDATE dataload.internal_case AS internal
SET external_case_id = canonical.external_case_id
FROM canonical
WHERE canonical.gather_case_id = internal.id
    AND internal.external_case_id IS NULL
    AND obit_scrape_id = ${obit_scrape_id} 
;

-- SECOND PASS
WITH dup AS(
    SELECT gc.id AS gather_case_id,
            gc.key2,
            COUNT(gc.id) OVER(PARTITION BY gc.key2) AS dups
        FROM dataload.internal_case AS gc
        WHERE gc.obit_scrape_id = ${obit_scrape_id} 
            AND gc.external_case_id IS NULL
)
UPDATE dataload.external_case AS obit SET
    gather_case_id = CASE WHEN dup.dups > 1 THEN NULL ELSE dup.gather_case_id END,
    matched = 2,
    problem = CASE WHEN dup.dups > 1 THEN 'AMBIGUOUS'::dataload.scrape_problem ELSE 'NONE'::dataload.scrape_problem END
FROM dup
WHERE
    obit.matched = 0
    AND dup.key2 = obit.key2
;

UPDATE dataload.internal_case AS ic
SET external_case_id = ex.id
FROM dataload.external_case AS ex
WHERE ic.obit_scrape_id = ${obit_scrape_id}
    AND ic.external_case_id IS NULL
    AND ex.obit_scrape_id = ic.obit_scrape_id
    AND ex.problem = 'AMBIGUOUS'
    AND ic.key2 = ex.key2
;

WITH canonical AS (
    SELECT MAX(id) AS external_case_id,
        gather_case_id
    FROM dataload.external_case
    WHERE gather_case_id IS NOT NULL
        AND matched = 2
        AND obit_scrape_id = ${obit_scrape_id} 
    GROUP BY gather_case_id
)
UPDATE dataload.internal_case AS internal
SET external_case_id = canonical.external_case_id
FROM canonical
WHERE canonical.gather_case_id = internal.id
    AND obit_scrape_id = ${obit_scrape_id} 
    AND internal.external_case_id IS NULL
;

-- THIRD PASS
WITH dup AS(
    SELECT gc.id AS gather_case_id,
            gc.key3,
            COUNT(gc.id) OVER(PARTITION BY gc.key3) AS dups
        FROM dataload.internal_case AS gc
        WHERE gc.obit_scrape_id = ${obit_scrape_id} 
            AND gc.external_case_id IS NULL
)
UPDATE dataload.external_case AS obit SET
    gather_case_id = CASE WHEN dup.dups > 1 THEN NULL ELSE dup.gather_case_id END,
    matched  = 4,
    problem = CASE WHEN dup.dups > 1 THEN 'AMBIGUOUS'::dataload.scrape_problem ELSE 'NONE'::dataload.scrape_problem END
FROM dup
WHERE
    obit.matched = 0
    AND dup.key3 = obit.key3
;

UPDATE dataload.internal_case AS ic
SET external_case_id = ex.id
FROM dataload.external_case AS ex
WHERE ic.obit_scrape_id = ${obit_scrape_id}
    AND ic.external_case_id IS NULL
    AND ex.obit_scrape_id = ic.obit_scrape_id
    AND ex.problem = 'AMBIGUOUS'
    AND ic.key3 = ex.key3
;

WITH canonical AS (
    SELECT MAX(id) AS external_case_id,
        gather_case_id
    FROM dataload.external_case
    WHERE gather_case_id IS NOT NULL
        AND matched = 4 
        AND obit_scrape_id = ${obit_scrape_id} 
    GROUP BY gather_case_id
)
UPDATE dataload.internal_case AS internal
SET external_case_id = canonical.external_case_id
FROM canonical
WHERE canonical.gather_case_id = internal.id
    AND internal.external_case_id IS NULL
    AND obit_scrape_id = ${obit_scrape_id} 
;


-- FOURTH PASS
WITH dup AS(
    SELECT gc.id AS gather_case_id,
            gc.key4,
            COUNT(gc.id) OVER(PARTITION BY gc.key4) AS dups
        FROM dataload.internal_case AS gc
        WHERE gc.obit_scrape_id = ${obit_scrape_id} 
            AND gc.external_case_id IS NULL
)
UPDATE dataload.external_case AS obit SET
    gather_case_id = CASE WHEN dup.dups > 1 THEN NULL ELSE dup.gather_case_id END,
    matched = 4,
    problem = CASE WHEN dup.dups > 1 THEN 'AMBIGUOUS'::dataload.scrape_problem ELSE 'NONE'::dataload.scrape_problem END
FROM dup
WHERE
    obit.matched = 0
    AND dup.key4 = obit.key4
;

UPDATE dataload.internal_case AS ic
SET external_case_id = ex.id
FROM dataload.external_case AS ex
WHERE ic.obit_scrape_id = ${obit_scrape_id}
    AND ic.external_case_id IS NULL
    AND ex.obit_scrape_id = ic.obit_scrape_id
    AND ex.problem = 'AMBIGUOUS'
    AND ic.key4 = ex.key4
;

WITH canonical AS (
    SELECT MAX(id) AS external_case_id,
        gather_case_id
    FROM dataload.external_case
    WHERE gather_case_id IS NOT NULL
        AND matched = 4
        AND obit_scrape_id = ${obit_scrape_id} 
    GROUP BY gather_case_id
)
UPDATE dataload.internal_case AS internal
SET external_case_id = canonical.external_case_id
FROM canonical
WHERE canonical.gather_case_id = internal.id
    AND obit_scrape_id = ${obit_scrape_id} 
    AND internal.external_case_id IS NULL
;


-- FIFTH PASS
WITH dup AS(
    SELECT gc.id AS gather_case_id,
            gc.key5,
            COUNT(gc.id) OVER(PARTITION BY gc.key5) AS dups
        FROM dataload.internal_case AS gc
        WHERE gc.obit_scrape_id = ${obit_scrape_id} 
            AND gc.external_case_id IS NULL
)
UPDATE dataload.external_case AS obit SET
    gather_case_id = CASE WHEN dup.dups > 1 THEN NULL ELSE dup.gather_case_id END,
    matched = 5,
    problem = CASE WHEN dup.dups > 1 THEN 'AMBIGUOUS'::dataload.scrape_problem ELSE 'NONE'::dataload.scrape_problem END
FROM dup
WHERE
    obit.matched = 0
    AND dup.key5 = obit.key5
;

UPDATE dataload.internal_case AS ic
SET external_case_id = ex.id
FROM dataload.external_case AS ex
WHERE ic.obit_scrape_id = ${obit_scrape_id}
    AND ic.external_case_id IS NULL
    AND ex.obit_scrape_id = ic.obit_scrape_id
    AND ex.problem = 'AMBIGUOUS'
    AND ic.key5 = ex.key5
;

WITH canonical AS (
    SELECT MAX(id) AS external_case_id,
        gather_case_id
    FROM dataload.external_case
    WHERE gather_case_id IS NOT NULL
        AND matched = 5
        AND obit_scrape_id = ${obit_scrape_id} 
    GROUP BY gather_case_id
)
UPDATE dataload.internal_case AS internal
SET external_case_id = canonical.external_case_id
FROM canonical
WHERE canonical.gather_case_id = internal.id
    AND obit_scrape_id = ${obit_scrape_id} 
    AND internal.external_case_id IS NULL
;

-- SIXTH PASS
WITH dup AS(
    SELECT gc.id AS gather_case_id,
            gc.key6,
            COUNT(gc.id) OVER(PARTITION BY gc.key6) AS dups
        FROM dataload.internal_case AS gc
        WHERE gc.obit_scrape_id = ${obit_scrape_id} 
            AND gc.external_case_id IS NULL
)
UPDATE dataload.external_case AS obit SET
    gather_case_id = CASE WHEN dup.dups > 1 THEN NULL ELSE dup.gather_case_id END,
    matched = 6,
    problem = CASE WHEN dup.dups > 1 THEN 'AMBIGUOUS'::dataload.scrape_problem ELSE 'NONE'::dataload.scrape_problem END
FROM dup
WHERE
    obit.matched = 0
    AND dup.key6 = obit.key6
;

UPDATE dataload.internal_case AS ic
SET external_case_id = ex.id
FROM dataload.external_case AS ex
WHERE ic.obit_scrape_id = ${obit_scrape_id}
    AND ic.external_case_id IS NULL
    AND ex.obit_scrape_id = ic.obit_scrape_id
    AND ex.problem = 'AMBIGUOUS'
    AND ic.key6 = ex.key6
;

WITH canonical AS (
    SELECT MAX(id) AS external_case_id,
        gather_case_id
    FROM dataload.external_case
    WHERE gather_case_id IS NOT NULL
        AND matched = 6
        AND obit_scrape_id = ${obit_scrape_id} 
    GROUP BY gather_case_id
)
UPDATE dataload.internal_case AS internal
SET external_case_id = canonical.external_case_id
FROM canonical
WHERE canonical.gather_case_id = internal.id
    AND obit_scrape_id = ${obit_scrape_id} 
    AND internal.external_case_id IS NULL
;

-- Mark duplicates; obits that point to a case that does not point back to that obit
UPDATE dataload.external_case AS obit
SET problem = 'DUPLICATE'::dataload.scrape_problem
FROM dataload.internal_case AS gc
    WHERE obit.gather_case_id = gc.id
        AND gc.external_case_id != obit.id
        AND gc.obit_scrape_id = ${obit_scrape_id} 
        AND obit.obit_scrape_id = gc.obit_scrape_id
;