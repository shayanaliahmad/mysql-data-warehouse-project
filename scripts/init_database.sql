/*
    Script:  init_database.sql
    Purpose: Creates the bronze, silver, and gold layers of the data warehouse.
    Note:    Drops any existing layer first, so all data in them is lost.
*/

DROP DATABASE IF EXISTS bronze;
DROP DATABASE IF EXISTS silver;
DROP DATABASE IF EXISTS gold;

CREATE DATABASE bronze;
CREATE DATABASE silver;
CREATE DATABASE gold;
