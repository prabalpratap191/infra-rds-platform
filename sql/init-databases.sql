-- Database Initialization Script for RDS PostgreSQL
-- This script creates databases and users for all microservices
-- Execute this script as the master user (postgres)

-- ============================================================================
-- CUSTOMER SERVICE DATABASE
-- ============================================================================

-- Create customer database
CREATE DATABASE customer_db
    WITH 
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TEMPLATE = template0;

-- Create customer user
CREATE USER customer_user WITH ENCRYPTED PASSWORD 'REPLACE_WITH_SECRET_VALUE';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE customer_db TO customer_user;

-- Connect to customer_db and grant schema privileges
\c customer_db;
GRANT ALL ON SCHEMA public TO customer_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO customer_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO customer_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO customer_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO customer_user;

-- ============================================================================
-- ORDER SERVICE DATABASE
-- ============================================================================

-- Connect back to postgres database
\c postgres;

-- Create order database
CREATE DATABASE order_db
    WITH 
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TEMPLATE = template0;

-- Create order user
CREATE USER order_user WITH ENCRYPTED PASSWORD 'REPLACE_WITH_SECRET_VALUE';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE order_db TO order_user;

-- Connect to order_db and grant schema privileges
\c order_db;
GRANT ALL ON SCHEMA public TO order_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO order_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO order_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO order_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO order_user;

-- ============================================================================
-- CATALOG SERVICE DATABASE
-- ============================================================================

-- Connect back to postgres database
\c postgres;

-- Create catalog database
CREATE DATABASE catalog_db
    WITH 
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TEMPLATE = template0;

-- Create catalog user
CREATE USER catalog_user WITH ENCRYPTED PASSWORD 'REPLACE_WITH_SECRET_VALUE';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE catalog_db TO catalog_user;

-- Connect to catalog_db and grant schema privileges
\c catalog_db;
GRANT ALL ON SCHEMA public TO catalog_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO catalog_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO catalog_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO catalog_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO catalog_user;

-- ============================================================================
-- ORDER HISTORY SERVICE DATABASE
-- ============================================================================

-- Connect back to postgres database
\c postgres;

-- Create order_history database
CREATE DATABASE order_history_db
    WITH 
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TEMPLATE = template0;

-- Create order_history user
CREATE USER order_history_user WITH ENCRYPTED PASSWORD 'REPLACE_WITH_SECRET_VALUE';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE order_history_db TO order_history_user;

-- Connect to order_history_db and grant schema privileges
\c order_history_db;
GRANT ALL ON SCHEMA public TO order_history_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO order_history_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO order_history_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO order_history_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO order_history_user;

-- ============================================================================
-- NOTIFICATION SERVICE DATABASE
-- ============================================================================

-- Connect back to postgres database
\c postgres;

-- Create notification database
CREATE DATABASE notification_db
    WITH 
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TEMPLATE = template0;

-- Create notification user
CREATE USER notification_user WITH ENCRYPTED PASSWORD 'REPLACE_WITH_SECRET_VALUE';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE notification_db TO notification_user;

-- Connect to notification_db and grant schema privileges
\c notification_db;
GRANT ALL ON SCHEMA public TO notification_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO notification_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO notification_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO notification_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO notification_user;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Connect back to postgres database
\c postgres;

-- List all databases
SELECT datname FROM pg_database WHERE datistemplate = false;

-- List all users
SELECT usename FROM pg_user;

-- Show database sizes
SELECT 
    pg_database.datname,
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
WHERE datistemplate = false
ORDER BY pg_database_size(pg_database.datname) DESC;

ECHO 'Database initialization completed successfully!';
