-- ============================================================================
-- 00_unity_catalog_governance.sql
-- Purpose: Infrastructure-as-Code (DDL) reference for Unity Catalog security,
--          External Locations, Volumes, and RBAC permissions on Azure ADLS Gen2.
-- ============================================================================

-- 1. Create Catalog & Medallion Schemas
CREATE CATALOG IF NOT EXISTS dubai_realestate_prod
COMMENT 'Production catalog for Dubai Land Department (DLD) Lakehouse';

USE CATALOG dubai_realestate_prod;

CREATE SCHEMA IF NOT EXISTS bronze COMMENT 'Raw landing zone metadata & volumes';
CREATE SCHEMA IF NOT EXISTS silver COMMENT 'Cleaned, deduplicated, ANSI-typed Delta tables';
CREATE SCHEMA IF NOT EXISTS gold   COMMENT 'Business-level KPI aggregates for AI/BI & Power BI';

-- ----------------------------------------------------------------------------
-- 2. Storage Credential (Backed by Azure Databricks Access Connector)
-- Note: Managed Identity assigned 'Storage Blob Data Contributor' on ADLS Gen2
-- ----------------------------------------------------------------------------
CREATE STORAGE CREDENTIAL IF NOT EXISTS cred_dubai_adls
WITH (
  AZURE_MANAGED_IDENTITY = '/subscriptions/<YOUR_SUBSCRIPTION_ID>/resourceGroups/rg-dubai-realestate/providers/Microsoft.Databricks/accessConnectors/ac-dubai-realestate'
)
COMMENT 'System-assigned Managed Identity connector for adlsdubairvm97';

-- ----------------------------------------------------------------------------
-- 3. External Locations (Zero-Secret abfss:// Access for Medallion Containers)
-- ----------------------------------------------------------------------------
CREATE EXTERNAL LOCATION IF NOT EXISTS ext_bronze
URL 'abfss://bronze@adlsdubairvm97.dfs.core.windows.net/'
WITH (STORAGE CREDENTIAL cred_dubai_adls)
COMMENT 'External location governing raw CSV landing files in Bronze container';

CREATE EXTERNAL LOCATION IF NOT EXISTS ext_silver
URL 'abfss://silver@adlsdubairvm97.dfs.core.windows.net/'
WITH (STORAGE CREDENTIAL cred_dubai_adls)
COMMENT 'External location governing cleaned Delta tables in Silver container';

CREATE EXTERNAL LOCATION IF NOT EXISTS ext_gold
URL 'abfss://gold@adlsdubairvm97.dfs.core.windows.net/'
WITH (STORAGE CREDENTIAL cred_dubai_adls)
COMMENT 'External location governing aggregated Gold marts for BI consumption';

-- ----------------------------------------------------------------------------
-- 4. Unity Catalog External Volume (Modern Governance for Non-Tabular Files)
-- Replaces legacy DBFS mounts (/mnt/...) for raw CSV & Auto Loader checkpoints
-- ----------------------------------------------------------------------------
CREATE EXTERNAL VOLUME IF NOT EXISTS dubai_realestate_prod.bronze.dld_landing_vol
LOCATION 'abfss://bronze@adlsdubairvm97.dfs.core.windows.net/'
COMMENT 'Governed volume path (/Volumes/dubai_realestate_prod/bronze/dld_landing_vol/...) for Auto Loader';

-- ----------------------------------------------------------------------------
-- 5. Least-Privilege Access Control (RBAC Grants)
-- ----------------------------------------------------------------------------
GRANT READ FILES, WRITE FILES ON EXTERNAL LOCATION ext_bronze TO `data_engineers`;
GRANT READ FILES, WRITE FILES ON EXTERNAL LOCATION ext_silver TO `data_engineers`;
GRANT READ FILES, WRITE FILES ON EXTERNAL LOCATION ext_gold   TO `data_engineers`;

GRANT READ VOLUME, WRITE VOLUME ON VOLUME dubai_realestate_prod.bronze.dld_landing_vol TO `data_engineers`;
GRANT USE CATALOG ON CATALOG dubai_realestate_prod TO `bi_analysts`;
GRANT USE SCHEMA  ON SCHEMA dubai_realestate_prod.gold TO `bi_analysts`;
GRANT SELECT      ON SCHEMA dubai_realestate_prod.gold TO `bi_analysts`;
