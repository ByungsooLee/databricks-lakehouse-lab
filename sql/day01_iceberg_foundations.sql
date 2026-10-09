-- Day 1: Apache Iceberg foundations on Databricks Free Edition.
-- Run top to bottom once in a fresh workspace. This script intentionally does
-- not drop or overwrite an existing table.
-- Re-running the INSERT appends another 10,000 rows. Do not use VERSION AS OF 1
-- as the original pre-delete state after another write; history versions can
-- differ once the table has additional commits. DELETE can be re-run; after all
-- cancelled rows have been removed, a repeat affects zero rows (though it may
-- still appear as a new history operation in this environment).

CREATE SCHEMA IF NOT EXISTS workspace.iceberg_lab;

CREATE TABLE IF NOT EXISTS workspace.iceberg_lab.orders_iceberg (
  order_id BIGINT,
  customer_id BIGINT,
  order_date DATE,
  amount DECIMAL(10,2),
  status STRING
)
USING ICEBERG;

-- Append exactly 10,000 synthetic rows. Running this INSERT more than once
-- appends duplicate test data; inspect table/history before re-running.
INSERT INTO workspace.iceberg_lab.orders_iceberg
SELECT
  id AS order_id,
  id % 1000 AS customer_id,
  DATE_ADD(DATE '2026-10-01', CAST(id % 7 AS INT)) AS order_date,
  CAST(100 + id % 500 AS DECIMAL(10,2)) AS amount,
  CASE WHEN id % 10 = 0 THEN 'cancelled' ELSE 'paid' END AS status
FROM range(10000);

-- Validate total rows and status distribution before DELETE.
SELECT COUNT(*) AS total_orders
FROM workspace.iceberg_lab.orders_iceberg;

SELECT status, COUNT(*) AS order_count
FROM workspace.iceberg_lab.orders_iceberg
GROUP BY status
ORDER BY status;

-- Confirm the catalog reports the table format as Iceberg.
DESCRIBE DETAIL workspace.iceberg_lab.orders_iceberg;

-- First run should remove the 1,000 cancelled rows.
DELETE FROM workspace.iceberg_lab.orders_iceberg
WHERE status = 'cancelled';

-- Repeat the same DELETE to reproduce the no-op result (zero affected rows).
-- On a fresh one-time run, the history is expected to record this operation too.
DELETE FROM workspace.iceberg_lab.orders_iceberg
WHERE status = 'cancelled';

-- Review history after both DELETE statements. On a fresh one-time run the
-- expected sequence is Version 0 CREATE TABLE, 1 WRITE, 2 DELETE, 3 DELETE.
-- These Databricks history versions are not Iceberg Snapshot IDs.
DESCRIBE HISTORY workspace.iceberg_lab.orders_iceberg;

-- Compare current state with Version 1 from the original one-time run, when
-- the INSERT was the Version 1 WRITE. If this script has been rerun, inspect
-- DESCRIBE HISTORY and substitute the version that represents the intended
-- pre-delete snapshot; do not assume Version 1 still has the original content.
SELECT 'current' AS state, COUNT(*) AS order_count
FROM workspace.iceberg_lab.orders_iceberg
UNION ALL
SELECT 'version_1' AS state, COUNT(*) AS order_count
FROM workspace.iceberg_lab.orders_iceberg VERSION AS OF 1;

-- Inspect the physical plan for scan columns and scan-level filters.
EXPLAIN FORMATTED
SELECT customer_id, COUNT(*) AS order_count, SUM(amount) AS total_amount
FROM workspace.iceberg_lab.orders_iceberg
WHERE order_date >= DATE '2026-10-04'
GROUP BY customer_id;
