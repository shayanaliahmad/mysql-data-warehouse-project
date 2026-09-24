/*
    Script:  proc_load_silver.sql
    Purpose: Creates a stored procedure that loads the CRM and ERP source data
             from bronze into the silver tables.
    Note:    Truncates each table first, so re-running replaces the data.
             Run CALL silver.load_silver(); to execute it.
*/

DROP PROCEDURE IF EXISTS silver.load_silver;

DELIMITER //

CREATE PROCEDURE silver.load_silver()
BEGIN
    DECLARE v_start_time      DATETIME;
    DECLARE v_end_time        DATETIME;
    DECLARE v_batch_start_time DATETIME;
    DECLARE v_batch_end_time   DATETIME;
    DECLARE v_errno INT;
    DECLARE v_errmsg TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_errmsg = MESSAGE_TEXT;
        SELECT CONCAT('error ', v_errno, ' during silver load: ', v_errmsg) AS msg;
    END;

    SET v_batch_start_time = NOW();

    -- CRM tables

    -- silver.crm_cust_info
    SET v_start_time = NOW();
    TRUNCATE TABLE silver.crm_cust_info;
    INSERT INTO silver.crm_cust_info (
        cst_id,
        cst_key,
        cst_firstname,
        cst_lastname,
        cst_marital_status,
        cst_gndr,
        cst_create_date
    )
    SELECT
        cst_id,
        cst_key,
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname) AS cst_lastname,
        CASE
            WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
            WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
            ELSE 'n/a'
        END AS cst_marital_status, -- normalize marital status values to readable format
        CASE
            WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
            WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
            ELSE 'n/a'
        END AS cst_gndr, -- normalize gender values to readable format
        cst_create_date
    FROM (
        SELECT
            t.*,
            ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
        FROM bronze.crm_cust_info t
        WHERE cst_id IS NOT NULL AND cst_id != 0 -- bronze stores missing ids as 0, not NULL
    ) ranked
    WHERE flag_last = 1; -- keep the most recent record per customer
    SET v_end_time = NOW();
    SELECT 'crm_cust_info' AS table_name, TIMESTAMPDIFF(SECOND, v_start_time, v_end_time) AS load_duration_seconds;

    -- silver.crm_prd_info
    SET v_start_time = NOW();
    TRUNCATE TABLE silver.crm_prd_info;
    INSERT INTO silver.crm_prd_info (
        prd_id,
        cat_id,
        prd_key,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt
    )
    SELECT
        prd_id,
        REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,   -- extract category id
        SUBSTRING(prd_key, 7)                       AS prd_key, -- extract product key
        prd_nm,
        IFNULL(prd_cost, 0) AS prd_cost,
        CASE
            WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
            WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
            WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
            WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
            ELSE 'n/a'
        END AS prd_line, -- map product line codes to descriptive values
        prd_start_dt,
        DATE_SUB(
            LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt),
            INTERVAL 1 DAY
        ) AS prd_end_dt -- end date is one day before the next start date
    FROM bronze.crm_prd_info;
    SET v_end_time = NOW();
    SELECT 'crm_prd_info' AS table_name, TIMESTAMPDIFF(SECOND, v_start_time, v_end_time) AS load_duration_seconds;

    -- silver.crm_sales_details
    SET v_start_time = NOW();
    TRUNCATE TABLE silver.crm_sales_details;
    INSERT INTO silver.crm_sales_details (
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        sls_order_dt,
        sls_ship_dt,
        sls_due_dt,
        sls_sales,
        sls_quantity,
        sls_price
    )
    SELECT
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        CASE
            WHEN sls_order_dt = 0 OR CHAR_LENGTH(sls_order_dt) != 8 THEN NULL
            ELSE STR_TO_DATE(CAST(sls_order_dt AS CHAR), '%Y%m%d')
        END AS sls_order_dt,
        CASE
            WHEN sls_ship_dt = 0 OR CHAR_LENGTH(sls_ship_dt) != 8 THEN NULL
            ELSE STR_TO_DATE(CAST(sls_ship_dt AS CHAR), '%Y%m%d')
        END AS sls_ship_dt,
        CASE
            WHEN sls_due_dt = 0 OR CHAR_LENGTH(sls_due_dt) != 8 THEN NULL
            ELSE STR_TO_DATE(CAST(sls_due_dt AS CHAR), '%Y%m%d')
        END AS sls_due_dt,
        CASE
            WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
                THEN sls_quantity * ABS(sls_price)
            ELSE sls_sales
        END AS sls_sales, -- recalculate sales if the original value is missing or incorrect
        sls_quantity,
        CASE
            WHEN sls_price IS NULL OR sls_price <= 0
                THEN sls_sales / NULLIF(sls_quantity, 0)
            ELSE sls_price -- derive price if the original value is invalid
        END AS sls_price
    FROM bronze.crm_sales_details;
    SET v_end_time = NOW();
    SELECT 'crm_sales_details' AS table_name, TIMESTAMPDIFF(SECOND, v_start_time, v_end_time) AS load_duration_seconds;

    -- ERP tables

    -- silver.erp_cust_az12
    SET v_start_time = NOW();
    TRUNCATE TABLE silver.erp_cust_az12;
    INSERT INTO silver.erp_cust_az12 (
        cid,
        bdate,
        gen
    )
    SELECT
        CASE
            WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4) -- remove 'NAS' prefix if present
            ELSE cid
        END AS cid,
        CASE
            WHEN bdate > NOW() THEN NULL
            ELSE bdate
        END AS bdate, -- set future birthdates to NULL
        CASE
            WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
            ELSE 'n/a'
        END AS gen -- normalize gender values and handle unknown cases
    FROM bronze.erp_cust_az12;
    SET v_end_time = NOW();
    SELECT 'erp_cust_az12' AS table_name, TIMESTAMPDIFF(SECOND, v_start_time, v_end_time) AS load_duration_seconds;

    -- silver.erp_loc_a101
    SET v_start_time = NOW();
    TRUNCATE TABLE silver.erp_loc_a101;
    INSERT INTO silver.erp_loc_a101 (
        cid,
        cntry
    )
    SELECT
        REPLACE(cid, '-', '') AS cid,
        CASE
            WHEN TRIM(cntry) = 'DE' THEN 'Germany'
            WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
            WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
            ELSE TRIM(cntry)
        END AS cntry -- normalize and handle missing or blank country codes
    FROM bronze.erp_loc_a101;
    SET v_end_time = NOW();
    SELECT 'erp_loc_a101' AS table_name, TIMESTAMPDIFF(SECOND, v_start_time, v_end_time) AS load_duration_seconds;

    -- silver.erp_px_cat_g1v2
    SET v_start_time = NOW();
    TRUNCATE TABLE silver.erp_px_cat_g1v2;
    INSERT INTO silver.erp_px_cat_g1v2 (
        id,
        cat,
        subcat,
        maintenance
    )
    SELECT
        id,
        cat,
        subcat,
        maintenance
    FROM bronze.erp_px_cat_g1v2;
    SET v_end_time = NOW();
    SELECT 'erp_px_cat_g1v2' AS table_name, TIMESTAMPDIFF(SECOND, v_start_time, v_end_time) AS load_duration_seconds;

    SET v_batch_end_time = NOW();
    SELECT 'TOTAL' AS table_name, TIMESTAMPDIFF(SECOND, v_batch_start_time, v_batch_end_time) AS load_duration_seconds;

END //

DELIMITER ;
