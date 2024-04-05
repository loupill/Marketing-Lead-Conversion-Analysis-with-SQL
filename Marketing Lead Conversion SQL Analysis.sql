-- Let's take a look at where each lead type is coming from
SELECT COUNT(cd.mql_id) as cnt_leads, lead_type, origin
FROM closed_deals_dataset cd
JOIN marketing_qualified_leads_dataset mql
ON cd.mql_id = mql.mql_id
GROUP BY lead_type, origin


-- Let's get a little clarity on the above. We will bucket the lead types based on similarity and then we will find the origin of each bucket value
-- First let's take a look at unique lead_type values so we can find similarities
SELECT DISTINCT(lead_type)
FROM closed_deals_dataset
-- Based on the above we will bucket the lead_types into three categoies: online, offline, other, and industry
WITH ProspectCounts AS (
	SELECT origin,
		CASE
			WHEN lead_type LIKE 'online%' THEN 'Online'
			ELSE lead_type
		END as bucketed_lead_type,
		COUNT(cd.mql_id) as cnt_prospects
	FROM closed_deals_dataset cd
	JOIN marketing_qualified_leads_dataset mql
	ON cd.mql_id = mql.mql_id
	GROUP BY 
		origin, 
		CASE
			WHEN lead_type LIKE 'online%' THEN 'Online'
			ELSE lead_type
		END 
)
SELECT origin, bucketed_lead_type, cnt_prospects
FROM ProspectCounts
ORDER BY origin, cnt_prospects DESC


-- What is the conversion rate from marketing-qualified leads (MQLs) to closed deals?
SELECT 
	(SELECT COUNT(DISTINCT(mql_id)) FROM closed_deals_dataset) * 100 /
	(SELECT COUNT(DISTINCT(mql_id)) FROM marketing_qualified_leads_dataset)
-- 10%

-- How long does it typically take for an MQL to convert into a closed deal?
SELECT AVG(DATEDIFF(DAY, mql.first_contact_date, cd.won_date))
FROM marketing_qualified_leads_dataset mql
JOIN closed_deals_dataset cd
ON mql.mql_id = cd.mql_id
-- Average of 48 days 


-- Which marketing origin generates the highest number of MQLs?
SELECT COUNT(mql_id) as mqls_generated, origin
FROM marketing_qualified_leads_dataset
GROUP BY origin
ORDER BY COUNT(mql_id) DESC
-- Organic search, paid search, and social are the top 3 respectively


-- Which origin has the highest conversion rate from MQL to closed deal?
WITH LandingPageCounts AS (
	SELECT mql.origin,
		COUNT(DISTINCT(mql.mql_id)) as LeadCnt,
		COUNT(DISTINCT(cd.mql_id)) as MQL_w_Closed_Deals
	FROM marketing_qualified_leads_dataset mql
	LEFT JOIN closed_deals_dataset cd
	ON mql.mql_id = cd.mql_id
	GROUP BY mql.origin)
SELECT origin,
	(MQL_w_Closed_Deals * 100)/LeadCnt as Conv_Rate
FROM LandingPageCounts
ORDER BY (MQL_w_Closed_Deals * 100)/LeadCnt DESC
-- NULL, unknown, paid search, and organic search are the top 4 origins respectively



-- Find the top 3 landing pages across each origin by lead count
SELECT * 
FROM
(SELECT origin, landing_page_id, COUNT(mql_id) as cnt,
RANK() OVER (PARTITION BY origin ORDER BY COUNT(mql_id) DESC) as rnk
FROM marketing_qualified_leads_dataset 
WHERE origin IS NOT NULL
GROUP BY origin, landing_page_id
) x
WHERE rnk <= 3



-- Is there a correlation between the business segment and the landing page/origin?
SELECT *, SUM(cnt_prospects) OVER (PARTITION BY landing_page_id) as Total_LP_prospects
FROM
(SELECT cd.business_segment, mql.landing_page_id, COUNT(mql.mql_id) as cnt_prospects
FROM marketing_qualified_leads_dataset mql
JOIN closed_deals_dataset cd
ON mql.mql_id = cd.mql_id
GROUP BY cd.business_segment, mql.landing_page_id) x
ORDER BY cnt_prospects DESC
-- Not much correlation. b76ef37428e6799c421989521c0e5077 and 22c29808c4f815213303f8933030604c are the two most popular overall


--Which lead type has the most conversions to closed deals?
SELECT lead_type, COUNT(DISTINCT(mql_id)) cnt_prospects,
RANK() OVER (ORDER BY COUNT(DISTINCT(mql_id)) DESC) rnk
FROM closed_deals_dataset
GROUP BY lead_type


-- Is there a relationship between the lead type and the monthly revenue generated?
SELECT *,
SUM(monthly_rev) OVER (PARTITION BY lead_type) as tot_rev_by_lead_type
FROM (
SELECT SUM(declared_monthly_revenue) monthly_rev, YEAR(won_date) yr, MONTH(won_date) mnth, lead_type
FROM closed_deals_dataset
GROUP BY YEAR(won_date), MONTH(won_date), lead_type
HAVING SUM(declared_monthly_revenue) > 0
) x
 

-- How does the time taken to close a deal vary across different business segments or lead types?
SELECT AVG(DATEDIFF(DAY, mql.first_contact_date, cd.won_date)) days_to_close, lead_type
FROM marketing_qualified_leads_dataset mql
JOIN closed_deals_dataset cd
ON cd.mql_id = mql.mql_id
GROUP BY lead_type


-- What is the average CLV for customers acquired through different origins?
WITH OriginStats AS (
SELECT origin, COUNT(origin) cnt_orig, SUM(declared_monthly_revenue) rev_orig
FROM closed_deals_dataset cd
JOIN marketing_qualified_leads_dataset mql
ON mql.mql_id = cd.mql_id
GROUP BY origin)
SELECT origin, rev_orig/NULLIF(cnt_orig, 0)
FROM OriginStats



-- Retrieve top 5 sellers by how much revenue they have generated
SELECT *
FROM
(SELECT seller_id, SUM(declared_monthly_revenue) seller_rev,
RANK() OVER (ORDER BY SUM(declared_monthly_revenue) DESC) rnk
FROM closed_deals_dataset
GROUP BY seller_id) x
WHERE rnk <= 5