/* ============================================================
   RETAIL SALES DATA WAREHOUSE
   A Snowflake Cloud Data Warehouse Project
   Prepared by: Roshan Kamat
   Tools Used: Snowflake · SQL · Power BI
   ============================================================
   Dataset: Snowflake Sample Database - TPC-H
   (SNOWFLAKE_SAMPLE_DATA.TPCH_SF1)
   ============================================================ */


/* ------------------------------------------------------------
   1. DATABASE & SCHEMA SETUP
   ------------------------------------------------------------
   A dedicated database and schema are created to simulate a
   real-world data warehousing environment, rather than
   querying the raw sample tables directly.
   ------------------------------------------------------------ */

CREATE DATABASE IF NOT EXISTS RETAIL_ANALYTICS;
CREATE SCHEMA IF NOT EXISTS RETAIL_ANALYTICS.SALES;

USE DATABASE RETAIL_ANALYTICS;
USE SCHEMA SALES;


/* ------------------------------------------------------------
   2. CUSTOMER SUMMARY TABLE
   ------------------------------------------------------------
   Built by joining CUSTOMER, ORDERS, and NATION tables,
   aggregating order history per customer into a
   business-ready reporting layer.
   ------------------------------------------------------------ */

CREATE OR REPLACE TABLE CUSTOMER_SUMMARY AS
SELECT
    c.c_custkey                     AS customer_id,
    c.c_name                        AS customer_name,
    n.n_name                        AS nation,
    COUNT(o.o_orderkey)             AS total_orders,
    SUM(o.o_totalprice)             AS total_spent,
    ROUND(AVG(o.o_totalprice), 2)   AS avg_order_value
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER c
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS o
    ON c.c_custkey = o.o_custkey
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION n
    ON c.c_nationkey = n.n_nationkey
GROUP BY c.c_custkey, c.c_name, n.n_name;


/* ------------------------------------------------------------
   3. ANALYTICAL QUERIES
   ------------------------------------------------------------ */

/* 3.1 Top 10 Customers by Total Spend */
SELECT customer_name, nation, total_orders, total_spent
FROM CUSTOMER_SUMMARY
ORDER BY total_spent DESC
LIMIT 10;


/* 3.2 Monthly Order Trends */
SELECT
    DATE_TRUNC('month', o_orderdate) AS order_month,
    COUNT(o_orderkey)                AS num_orders,
    SUM(o_totalprice)                AS monthly_revenue
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS
GROUP BY order_month
ORDER BY order_month;


/* 3.3 Customer Segmentation (High / Medium / Low Value) */
CREATE OR REPLACE TABLE CUSTOMER_SEGMENTED AS
SELECT
    customer_id, customer_name, nation, total_spent,
    CASE
        WHEN total_spent >= 500000 THEN 'High Value'
        WHEN total_spent >= 200000 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS customer_segment
FROM CUSTOMER_SUMMARY;


/* 3.4 Running Total of Revenue (Window Function) */
SELECT
    order_month,
    monthly_revenue,
    SUM(monthly_revenue) OVER (ORDER BY order_month) AS running_total_revenue
FROM (
    SELECT
        DATE_TRUNC('month', o_orderdate) AS order_month,
        SUM(o_totalprice)                AS monthly_revenue
    FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS
    GROUP BY order_month
)
ORDER BY order_month;


/* 3.5 Year-over-Year Growth (LAG Function) */
WITH yearly_revenue AS (
    SELECT
        YEAR(o_orderdate)   AS order_year,
        SUM(o_totalprice)   AS total_revenue
    FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS
    GROUP BY order_year
)
SELECT
    order_year,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY order_year) AS prev_year_revenue,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY order_year))
        * 100.0 / LAG(total_revenue) OVER (ORDER BY order_year), 2
    ) AS yoy_growth_pct
FROM yearly_revenue
ORDER BY order_year;


/* ============================================================
   END OF SCRIPT

   Key Findings:
   - Identified the top 10 highest-spending customers for
     retention strategy.
   - Segmented all customers into High, Medium, and Low value
     tiers.
   - Built a running revenue total to visualize cumulative
     growth trends.
   - Calculated year-over-year growth percentages to identify
     periods of acceleration or decline in revenue.

   The CUSTOMER_SEGMENTED table can be directly connected to
   Power BI or Tableau for interactive dashboard reporting.
   ============================================================ */
