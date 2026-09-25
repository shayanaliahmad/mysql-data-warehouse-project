/*
    Script:  quality_checks_silver.sql
    Purpose: Validates the silver layer: primary key integrity, unwanted whitespace,
             date consistency, and derived-value accuracy across all six tables.
    Note:    Every check below should return no results, except the erp_cust_az12
             birthdate check and the DISTINCT standardization checks. Any other
             row returned is a problem to investigate.
*/

-- Checking silver.crm_cust_info
-- check for nulls or duplicates in the primary key
-- expectation: no results
SELECT
    cst_id,
    COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- check for unwanted spaces
-- expectation: no results
SELECT
    cst_key
FROM silver.crm_cust_info
WHERE cst_key != TRIM(cst_key);

-- data standardization & consistency
-- expectation: only Single, Married, n/a
SELECT DISTINCT
    cst_marital_status
FROM silver.crm_cust_info;

-- Checking silver.crm_prd_info
-- check for nulls or duplicates in the primary key
-- expectation: no results
SELECT
    prd_id,
    COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- check for unwanted spaces
-- expectation: no results
SELECT
    prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- check for nulls or negative values in cost
-- expectation: no results
SELECT
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- data standardization & consistency
-- expectation: only Mountain, Road, Other Sales, Touring, n/a
SELECT DISTINCT
    prd_line
FROM silver.crm_prd_info;

-- check for invalid date orders (start date > end date)
-- expectation: no results
SELECT
    *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- Checking silver.crm_sales_details
-- check for invalid dates
-- expectation: no invalid dates
SELECT
    NULLIF(sls_due_dt, 0) AS sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0
    OR CHAR_LENGTH(sls_due_dt) != 8
    OR sls_due_dt > 20500101
    OR sls_due_dt < 19000101;

-- check for invalid date orders (order date > shipping/due dates)
-- expectation: no results
SELECT
    *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
   OR sls_order_dt > sls_due_dt;

-- check data consistency: sales = quantity * price
-- expectation: no results
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales IS NULL
   OR sls_quantity IS NULL
   OR sls_price IS NULL
   OR sls_sales <= 0
   OR sls_quantity <= 0
   OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

-- Checking silver.erp_cust_az12
-- identify out-of-range dates
-- future dates were nulled during the silver load; pre-1924 dates are left as-is (bad source data)
-- expectation: only pre-1924 birthdates, if any
SELECT DISTINCT
    bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01'
   OR bdate > NOW();

-- data standardization & consistency
-- expectation: only Female, Male, n/a
SELECT DISTINCT
    gen
FROM silver.erp_cust_az12;

-- Checking silver.erp_loc_a101
-- data standardization & consistency
-- expectation: full country names (e.g. Germany, United States) or n/a, no raw codes, no blanks
SELECT DISTINCT
    cntry
FROM silver.erp_loc_a101
ORDER BY cntry;

-- Checking silver.erp_px_cat_g1v2
-- check for unwanted spaces
-- expectation: no results
SELECT
    *
FROM silver.erp_px_cat_g1v2
WHERE cat != TRIM(cat)
   OR subcat != TRIM(subcat)
   OR maintenance != TRIM(maintenance);

-- data standardization & consistency
-- expectation: only Yes, No
SELECT DISTINCT
    maintenance
FROM silver.erp_px_cat_g1v2;
