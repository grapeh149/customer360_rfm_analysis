/*
    RFM Analysis
    
    ===========================

    Author: Hoang Thai Huy
    Email: hthuy1409@gmail.com

    ===========================
*/


DECLARE @analysis_date DATE = '2022-09-01';

WITH customer_statistic AS (
    SELECT
        ct.CustomerID,
        cr.created_date,

        -- Recency
        DATEDIFF(DAY, MAX(ct.Purchase_Date), @analysis_date) AS Recency,

        -- Frequency (per year)
        ROUND(
            CAST(COUNT(DISTINCT ct.Purchase_Date) AS FLOAT) /
            NULLIF(DATEDIFF(YEAR, cr.created_date, @analysis_date),0)
        ,2) AS Frequency,

        -- Monetary (per year)
        ROUND(
            SUM(ct.GMV) /
            NULLIF(DATEDIFF(YEAR, cr.created_date, @analysis_date),0)
        ,2) AS Monetary

    FROM Customer_Transaction ct
    JOIN Customer_Registered cr
        ON ct.CustomerID = cr.ID
    WHERE ct.Purchase_Date IS NOT NULL
      AND cr.created_date IS NOT NULL
    GROUP BY ct.CustomerID, cr.created_date
),

customer_rn AS (
    SELECT
        cs.*,

        ROW_NUMBER() OVER (ORDER BY cs.Recency ASC) AS Recency_rn,
        ROW_NUMBER() OVER (ORDER BY cs.Frequency ASC) AS Frequency_rn,
        ROW_NUMBER() OVER (ORDER BY cs.Monetary ASC) AS Monetary_rn
    FROM customer_statistic cs
    WHERE (cs.Frequency IS NOT NULL AND cs.Frequency > 0)
        AND (cs.Monetary IS NOT NULL AND cs.Monetary > 0)
),

customer_rfm AS (
SELECT
    CustomerID,
    Recency,
    Frequency,
    Monetary,

-- R score
CASE
    WHEN Recency < (SELECT Recency FROM customer_rn WHERE Recency_rn = (SELECT ROUND(MAX(Recency_rn)*0.25,0) FROM customer_rn)) THEN 4
    WHEN Recency < (SELECT Recency FROM customer_rn WHERE Recency_rn = (SELECT ROUND(MAX(Recency_rn)*0.5,0) FROM customer_rn)) THEN 3
    WHEN Recency < (SELECT Recency FROM customer_rn WHERE Recency_rn = (SELECT ROUND(MAX(Recency_rn)*0.75,0) FROM customer_rn)) THEN 2
    ELSE 1
END AS R,

-- F score
CASE
    WHEN Frequency < (SELECT Frequency FROM customer_rn WHERE Frequency_rn = (SELECT ROUND(MAX(Frequency_rn)*0.25,0) FROM customer_rn)) THEN 1
    WHEN Frequency < (SELECT Frequency FROM customer_rn WHERE Frequency_rn = (SELECT ROUND(MAX(Frequency_rn)*0.5,0) FROM customer_rn)) THEN 2
    WHEN Frequency < (SELECT Frequency FROM customer_rn WHERE Frequency_rn = (SELECT ROUND(MAX(Frequency_rn)*0.75,0) FROM customer_rn)) THEN 3
    ELSE 4
END AS F,

-- M score
CASE
    WHEN Monetary < (SELECT Monetary FROM customer_rn WHERE Monetary_rn = (SELECT ROUND(MAX(Monetary_rn)*0.25,0) FROM customer_rn)) THEN 1
    WHEN Monetary < (SELECT Monetary FROM customer_rn WHERE Monetary_rn = (SELECT ROUND(MAX(Monetary_rn)*0.5,0) FROM customer_rn)) THEN 2
    WHEN Monetary < (SELECT Monetary FROM customer_rn WHERE Monetary_rn = (SELECT ROUND(MAX(Monetary_rn)*0.75,0) FROM customer_rn)) THEN 3
    ELSE 4
END AS M

FROM customer_rn
)

SELECT *,
    CONCAT(R,F,M) AS RFM,
    CASE
        WHEN R >= 3 AND F >= 3 AND M >= 3 THEN 'Champions'
        WHEN F >= 3 AND M >= 3 THEN 'Loyal'
        WHEN R >= 3 THEN 'New'
        ELSE 'Lost'
    END AS Segmentation
FROM customer_rfm
ORDER BY Frequency DESC;





