/*
    Script:  quality_checks_gold.sql
    Purpose: Validates the gold layer: uniqueness of surrogate keys and
             referential integrity between fact_sales and the dimension tables.
    Note:    Every check below should return no results; any row returned is a problem to investigate.
*/

-- Checking gold.dim_customers
-- check for uniqueness of customer key
-- expectation: no results
SELECT
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- Checking gold.dim_products
-- check for uniqueness of product key
-- expectation: no results
SELECT
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- Checking gold.fact_sales
-- check the data model connectivity between fact and dimensions
-- expectation: no results
SELECT *
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
WHERE p.product_key IS NULL OR c.customer_key IS NULL;
