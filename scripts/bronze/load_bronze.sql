/*
    Script: load_bronze.sql
    Purpose: Loads the CRM and ERP source CSVs into the bronze tables.
    Note:    Truncates each table first, so re-running replaces the data.
             Replace '/path/to/sql-data-warehouse-project' with the location of your clone.
*/

SET @batch_start_time = NOW(0);

-- CRM tables
SET @start_time = NOW(0);
TRUNCATE TABLE bronze.crm_cust_info;
LOAD DATA LOCAL INFILE '/path/to/sql-data-warehouse-project/datasets/source_crm/cust_info.csv'
INTO TABLE bronze.crm_cust_info
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
SET @end_time = NOW(0);
-- each table's load time (in seconds) is shown as its own result after the load
SELECT TIMESTAMPDIFF(SECOND, @start_time, @end_time) AS crm_cust_info_time;

SET @start_time = NOW(0);
TRUNCATE TABLE bronze.crm_prd_info;
LOAD DATA LOCAL INFILE '/path/to/sql-data-warehouse-project/datasets/source_crm/prd_info.csv'
INTO TABLE bronze.crm_prd_info
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
SET @end_time = NOW(0);
SELECT TIMESTAMPDIFF(SECOND, @start_time, @end_time) AS crm_prd_info_time;

SET @start_time = NOW(0);
TRUNCATE TABLE bronze.crm_sales_details;
LOAD DATA LOCAL INFILE '/path/to/sql-data-warehouse-project/datasets/source_crm/sales_details.csv'
INTO TABLE bronze.crm_sales_details
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
SET @end_time = NOW(0);
SELECT TIMESTAMPDIFF(SECOND, @start_time, @end_time) AS crm_sales_details_time;

-- ERP tables
SET @start_time = NOW(0);
TRUNCATE TABLE bronze.erp_loc_a101;
LOAD DATA LOCAL INFILE '/path/to/sql-data-warehouse-project/datasets/source_erp/loc_a101.csv'
INTO TABLE bronze.erp_loc_a101
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
SET @end_time = NOW(0);
SELECT TIMESTAMPDIFF(SECOND, @start_time, @end_time) AS erp_loc_a101_time;

SET @start_time = NOW(0);
TRUNCATE TABLE bronze.erp_cust_az12;
LOAD DATA LOCAL INFILE '/path/to/sql-data-warehouse-project/datasets/source_erp/cust_az12.csv'
INTO TABLE bronze.erp_cust_az12
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
SET @end_time = NOW(0);
SELECT TIMESTAMPDIFF(SECOND, @start_time, @end_time) AS erp_cust_az12_time;

SET @start_time = NOW(0);
TRUNCATE TABLE bronze.erp_px_cat_g1v2;
LOAD DATA LOCAL INFILE '/path/to/sql-data-warehouse-project/datasets/source_erp/px_cat_g1v2.csv'
INTO TABLE bronze.erp_px_cat_g1v2
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
SET @end_time = NOW(0);
SELECT TIMESTAMPDIFF(SECOND, @start_time, @end_time) AS erp_px_cat_g1v2_time;

-- total time for the whole bronze layer (in seconds)
SET @batch_end_time = NOW(0);
SELECT TIMESTAMPDIFF(SECOND, @batch_start_time, @batch_end_time) AS bronze_total_time;
