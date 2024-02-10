--The SQL queries used for this analysis are attached below.
--User_id Aggregation for Funnel analysis

WITH user_accept AS
                (SELECT DISTINCT rr.user_id AS user_id FROM ride_requests rr WHERE accept_ts IS NOT NULL),
    user_complete AS
                (SELECT DISTINCT rr.user_id AS user_id FROM ride_requests rr WHERE dropoff_ts IS NOT NULL AND cancel_ts IS NULL),
    user_paid AS
                (SELECT DISTINCT rr.user_id AS user_id FROM ride_requests rr LEFT JOIN transactions t ON rr.ride_id = t.ride_id WHERE t.transaction_id IS NOT NULL),
    user_reviewd AS
                (SELECT DISTINCT user_id FROM reviews)
SELECT DISTINCT ad.app_download_key AS app_downloads,
        s.user_id AS signup,
        rr.user_id AS ride_requested,
        user_accept.user_id AS ride_accepted,
        user_complete.user_id AS ride_completed,
        user_paid.user_id AS paid_users,
        user_reviewd.user_id AS reviewed_user
FROM app_downloads ad
LEFT JOIN signups s
ON ad.app_download_key = s.session_id
LEFT JOIN ride_requests rr
ON s.user_id = rr.user_id
LEFT JOIN transactions tr
ON rr.ride_id = tr.ride_id
LEFT JOIN reviews rev
ON s.user_id = rev.user_id
LEFT JOIN user_accept
ON s.user_id = user_accept.user_id
LEFT JOIN user_complete
ON s.user_id = user_complete.user_id
LEFT JOIN user_paid
ON s.user_id = user_paid.user_id
LEFT JOIN user_reviewd
ON s.user_id = user_reviewd.user_id;

--Time Analysis: 

WITH ValidRequests AS (
                        SELECT USER_ID,
                                COUNT(*) AS Count_Request_Not_Null
                        FROM ride_requests
                        WHERE request_ts IS NOT NULL
                        GROUP BY USER_ID
                        ),
ValidCancellations AS (
                        SELECT USER_ID,
                                COUNT(*) AS Count_Cancel_Not_Null
                        FROM ride_requests
                        WHERE cancel_ts IS NOT NULL
                        GROUP BY USER_ID
                        ),
AvgReqAccept AS (
                        SELECT USER_ID,
                        AVG(EXTRACT(EPOCH FROM (accept_ts - request_ts)) / 60) AS Avg_Req_Accept_Minutes
                        FROM ride_requests
                        WHERE accept_ts IS NOT NULL
                        GROUP BY USER_ID ),
AvgReqAccept2Cancel AS (
                        SELECT USER_ID,
                        AVG(EXTRACT(EPOCH FROM (accept_ts - request_ts)) / 60) AS Avg_Req_Accept_Cancel_Minutes
                        FROM ride_requests
                        WHERE accept_ts IS NOT NULL AND cancel_ts IS NOT NULL
                        GROUP BY USER_ID
                        ),
AvgRegCancel AS (
                        SELECT USER_ID,
                        AVG(EXTRACT(EPOCH FROM (cancel_ts - request_ts)) / 60) AS Avg_Reg_Cancel_Minutes
                        FROM ride_requests
                        WHERE cancel_ts IS NOT NULL
                        GROUP BY USER_ID
                        ),
AvgReqPickup AS (
                SELECT USER_ID,
                AVG(EXTRACT(EPOCH FROM (pickup_ts - request_ts)) / 60) AS Avg_Req_pickup_Minutes
                FROM ride_requests
                WHERE pickup_ts IS NOT NULL
                GROUP BY USER_ID
                ),
AvgReqComplete AS (
                SELECT USER_ID,
                AVG(EXTRACT(EPOCH FROM (dropoff_ts - request_ts)) / 60) AS Avg_Req_Complete_Minutes
                FROM ride_requests
                WHERE accept_ts IS NOT NULL
                GROUP BY USER_ID)
SELECT  rr.USER_ID,
        VR.Count_Request_Not_Null,
        VC.Count_Cancel_Not_Null,
        ARA.Avg_Req_Accept_Minutes,
        ARAC.Avg_Req_Accept_Cancel_Minutes,
        ARC.Avg_Reg_Cancel_Minutes,
        ARP.Avg_Req_pickup_Minutes,
        ARCOM.Avg_Req_Complete_Minutes
FROM ride_requests rr
LEFT JOIN ValidRequests VR ON rr.USER_ID = VR.USER_ID
LEFT JOIN ValidCancellations VC ON rr.USER_ID = VC.USER_ID
LEFT JOIN AvgReqAccept ARA ON rr.USER_ID = ARA.USER_ID
LEFT JOIN AvgReqAccept2Cancel ARAC ON rr.USER_ID = ARAC.USER_ID
LEFT JOIN AvgRegCancel ARC ON rr.USER_ID = ARC.USER_ID
LEFT JOIN AvgReqPickup ARP ON rr.USER_ID = ARP.USER_ID
LEFT JOIN AvgReqComplete ARCOM ON rr.USER_ID = ARCOM.USER_ID
GROUP BY 1,2,3,4,5,6,7,8;

--Unique Users in Each Stage:
/* User Count funnel*/
WITH Funnel AS ( SELECT ad.app_download_key AS app_download_key,
                        s.user_id AS signup_user_id,
                        rr.user_id AS request_user_id,
                        rr.accept_ts AS ride_accepted_ts,
                        rr.dropoff_ts AS ride_completed_ts,
                        tr.ride_id AS transcation_ride_id,
                        rev.user_id AS reviewed
                FROM app_downloads ad
                LEFT JOIN signups s ON ad.app_download_key = s.session_id
                LEFT JOIN ride_requests rr ON s.user_id = rr.user_id
                LEFT JOIN transactions tr ON rr.ride_id = tr.ride_id
                LEFT JOIN reviews rev ON s.user_id = rev.user_id
                )
SELECT  COUNT(DISTINCT app_download_key) AS app_downloads,
        COUNT(DISTINCT signup_user_id) AS signed_ups,
        COUNT(DISTINCT request_user_id) AS ride_requested,
        COUNT(DISTINCT CASE WHEN ride_accepted_ts IS NOT NULL THEN request_user_id END) AS driver_accepted,
        COUNT(DISTINCT CASE WHEN ride_completed_ts IS NOT NULL THEN request_user_id END) AS ride_completed,
        COUNT(DISTINCT CASE WHEN transcation_ride_id IS NOT NULL THEN signup_user_id END) AS Paid_users,
        COUNT(DISTINCT CASE WHEN reviewed IS NOT NULL THEN signup_user_id END) AS Reviewed_users
FROM Funnel;

--FUNNEL Usage percentage difference from top to bottom:
WITH Funnel AS (SELECT  ad.app_download_key AS app_download_key,
                        s.user_id AS signup_user_id,
                        rr.user_id AS request_user_id,
                        rr.accept_ts AS ride_accepted_ts,
                        rr.dropoff_ts AS ride_completed_ts,
                        tr.ride_id AS transcation_ride_id,
                        rev.user_id AS reviewed
                FROM app_downloads ad
                LEFT JOIN signups s ON ad.app_download_key = s.session_id
                LEFT JOIN ride_requests rr ON s.user_id = rr.user_id
                LEFT JOIN transactions tr ON rr.ride_id = tr.ride_id
                LEFT JOIN reviews rev ON s.user_id = rev.user_id
                )
SELECT  COUNT(DISTINCT app_download_key) AS app_downloads,
        ROUND(COUNT(DISTINCT signup_user_id) * 100.0 / COUNT(DISTINCT app_download_key),2) AS signed_ups,
        ROUND(COUNT(DISTINCT request_user_id) * 100.0 / COUNT(DISTINCT app_download_key),2) AS ride_requested,
        ROUND(COUNT(DISTINCT CASE WHEN ride_accepted_ts IS NOT NULL THEN request_user_id END) * 100.0 / COUNT(DISTINCT app_download_key),2) AS driver_accepted,
        ROUND(COUNT(DISTINCT CASE WHEN ride_completed_ts IS NOT NULL THEN request_user_id END) * 100.0 / COUNT(DISTINCT app_download_key),2) AS ride_completed,
        ROUND(COUNT(DISTINCT CASE WHEN transcation_ride_id IS NOT NULL THEN signup_user_id END) * 100.0 / COUNT(DISTINCT app_download_key),2) AS Paid_users,
        ROUND(COUNT(DISTINCT CASE WHEN reviewed IS NOT NULL THEN signup_user_id END) * 100.0 / COUNT(DISTINCT app_download_key),2) AS Reviewed_users
FROM Funnel;


--FUNNEL STEP-TO-STEP percentage difference:

WITH Funnel AS (SELECT  ad.app_download_key AS app_download_key,
                        s.user_id AS signup_user_id,
                        rr.user_id AS request_user_id,
                        rr.accept_ts AS ride_accepted_ts,
                        rr.dropoff_ts AS ride_completed_ts,
                        tr.ride_id AS transcation_ride_id,
                        rev.user_id AS reviewed
                FROM app_downloads ad
                LEFT JOIN signups s ON ad.app_download_key = s.session_id
                LEFT JOIN ride_requests rr ON s.user_id = rr.user_id
                LEFT JOIN transactions tr ON rr.ride_id = tr.ride_id
                LEFT JOIN reviews rev ON s.user_id = rev.user_id )
SELECT  COUNT(DISTINCT app_download_key) AS app_downloads,
        ROUND(COUNT(DISTINCT signup_user_id) * 100.0 / COUNT(DISTINCT app_download_key),2) AS signed_ups,
        ROUND(COUNT(DISTINCT request_user_id) * 100.0 / COUNT(DISTINCT signup_user_id),2) AS ride_requested,
        ROUND(COUNT(DISTINCT CASE WHEN ride_accepted_ts IS NOT NULL THEN request_user_id END) * 100.0 / COUNT(DISTINCT request_user_id),2) AS driver_accepted,
        ROUND(COUNT(DISTINCT CASE WHEN ride_completed_ts IS NOT NULL THEN request_user_id END) * 100.0 / COUNT(DISTINCT request_user_id),2) AS ride_completed,
        ROUND(COUNT(DISTINCT CASE WHEN transcation_ride_id IS NOT NULL THEN signup_user_id END) * 100.0 / COUNT(DISTINCT request_user_id),2) AS Paid_users,
        ROUND(COUNT(DISTINCT CASE WHEN reviewed IS NOT NULL THEN signup_user_id END) * 100.0 / COUNT(DISTINCT signup_user_id),2) AS Reviewed_users
FROM Funnel;


/* Funnel Conversion rate by Platform */
WITH Funnel AS ( SELECT ad.platform AS platform,
                        ad.app_download_key AS app_download_key,
                        s.user_id AS signup_user_id,
                        rr.user_id AS request_user_id,
                        rr.accept_ts AS ride_accepted_ts,
                        rr.dropoff_ts AS ride_completed_ts,
                        tr.ride_id AS transaction_ride_id,
                        rev.user_id AS reviewed
                FROM app_downloads ad
                LEFT JOIN signups s ON ad.app_download_key = s.session_id
                LEFT JOIN ride_requests rr ON s.user_id = rr.user_id
                LEFT JOIN transactions tr ON rr.ride_id = tr.ride_id
                LEFT JOIN reviews rev ON s.user_id = rev.user_id
                )
SELECT  platform,
        COUNT(DISTINCT app_download_key) AS app_downloads,
        ROUND(COUNT(DISTINCT signup_user_id) * 100.0 / COUNT(DISTINCT app_download_key), 2) AS signed_ups,
        ROUND(COUNT(DISTINCT request_user_id) * 100.0 / COUNT(DISTINCT app_download_key), 2) AS ride_requested,
        ROUND(COUNT(DISTINCT CASE WHEN ride_accepted_ts IS NOT NULL THEN request_user_id END) * 100.0 / COUNT(DISTINCT app_download_key), 2) AS driver_accepted,
        ROUND(COUNT(DISTINCT CASE WHEN ride_completed_ts IS NOT NULL THEN request_user_id END) * 100.0 / COUNT(DISTINCT app_download_key), 2) AS ride_completed,
        ROUND(COUNT(DISTINCT CASE WHEN transaction_ride_id IS NOT NULL THEN signup_user_id END) * 100.0 / COUNT(DISTINCT app_download_key), 2) AS paid_users,
        ROUND(COUNT(DISTINCT CASE WHEN reviewed IS NOT NULL THEN signup_user_id END) * 100.0 / COUNT(DISTINCT app_download_key), 2) AS reviewed_users
FROM Funnel
GROUP BY platform
ORDER BY 2 DESC;

--User Analysis by Different Platforms

SELECT ap.platform, (COUNT(DISTINCT s.user_id)*100/(SELECT COUNT(DISTINCT user_id) FROM signups)) AS user_percentage
FROM app_downloads ap
LEFT JOIN signups s
ON ap.app_download_key = s.session_id
GROUP BY 1;

/* users by age range and analyze their progression through the funnel.*/

WITH Funnel AS (SELECT  s.age_range,
                        ad.app_download_key,
                        s.user_id AS signup_user_id,
                        rr.user_id AS request_user_id,
                        24
                        rr.accept_ts AS ride_accepted_ts,
                        rr.dropoff_ts AS ride_completed_ts,
                        t.ride_id AS transaction_ride_id,
                        rev.user_id AS reviewed
                FROM app_downloads ad
                LEFT JOIN signups s ON ad.app_download_key = s.session_id
                LEFT JOIN ride_requests rr ON s.user_id = rr.user_id
                LEFT JOIN transactions t ON rr.ride_id = t.ride_id
                LEFT JOIN reviews rev ON s.user_id = rev.user_id
                )
SELECT  age_range,
        COUNT(DISTINCT app_download_key) AS Appdownloaded_Signedup_users,
        ROUND(COUNT(DISTINCT request_user_id) * 100.0 / COUNT(DISTINCT app_download_key), 2) AS ride_requested,
        ROUND(COUNT(DISTINCT CASE WHEN ride_accepted_ts IS NOT NULL THEN request_user_id END) * 100.0 / COUNT(DISTINCT app_download_key), 2) AS driver_accepted,
        ROUND(COUNT(DISTINCT CASE WHEN ride_completed_ts IS NOT NULL THEN request_user_id END) * 100.0 / COUNT(DISTINCT app_download_key), 2) AS ride_completed,
        ROUND(COUNT(DISTINCT CASE WHEN transaction_ride_id IS NOT NULL THEN signup_user_id END) * 100.0 / COUNT(DISTINCT app_download_key), 2) AS paid_users,
        ROUND(COUNT(DISTINCT CASE WHEN reviewed IS NOT NULL THEN signup_user_id END) * 100.0 / COUNT(DISTINCT app_download_key), 2) AS reviewed_users
FROM Funnel
WHERE age_range IS NOT NULL
GROUP BY age_range
ORDER BY 2 DESC;

-- Assess ride request patterns and determine peak demand times.

WITH RequestTimestamps AS ( SELECT
                            EXTRACT(HOUR FROM request_ts) AS request_hour,
                            COUNT(*) AS request_count
                            FROM ride_requests
                            WHERE request_ts IS NOT NULL
                            GROUP BY EXTRACT(HOUR FROM request_ts)
                            ORDER BY EXTRACT(HOUR FROM request_ts)
                            )
SELECT  request_hour,
        request_count
FROM RequestTimestamps
ORDER BY 2 DESC;

--Analyse monthly ride request patterns:

SELECT DATE_TRUNC('month', request_ts) AS month, COUNT(*) AS Ride_request_count
FROM ride_requests
GROUP BY month
ORDER BY 2 DESC;

--Analyse the average Request to cancel timing:

SELECT (SELECT AVG(EXTRACT(EPOCH FROM (accept_ts - request_ts)) / 60) AS Avg_Req_Accept_Minutes
FROM ride_requests
WHERE accept_ts IS NOT NULL)AS AvgReqAccept,
(SELECT AVG(EXTRACT(EPOCH FROM (accept_ts - request_ts)) / 60) AS Avg_Req_Accept_Cancel_Minutes
FROM ride_requests
WHERE accept_ts IS NOT NULL AND cancel_ts IS NOT NULL) AS AvgReqAccept_LaterCancelled,
(SELECT AVG(EXTRACT(EPOCH FROM (cancel_ts - request_ts)) / 60) AS Avg_Reg_Cancel_Minutes
FROM ride_requests
WHERE cancel_ts IS NOT NULL) AS AvgRegCancelled,
(SELECT AVG(EXTRACT(EPOCH FROM (pickup_ts - request_ts)) / 60) AS Avg_Req_pickup_Minutes
FROM ride_requests
WHERE pickup_ts IS NOT NULL) AS AvgRequest_Pickedup
FROM
app_downloads ad
LEFT JOIN
signups s
ON ad.app_download_key = s.session_id
LEFT JOIN
ride_requests rr
ON s.user_id = rr.user_id
LEFT JOIN transactions tr
ON rr.ride_id = tr.ride_id
LEFT JOIN reviews rev
ON s.user_id = rev.user_id
LIMIT 1
;

--Total Revenue:

SELECT SUM(purchase_amount_usd) AS total_revenue
FROM transactions;

--Revenue: Platform wise
SELECT platform, ROUND(CAST(SUM(purchase_amount_usd) AS INTEGER),2) AS platform_revenue
FROM app_downloads ad
JOIN signups s ON ad.app_download_key = s.session_id
JOIN ride_requests rr ON s.user_id = rr.user_id
JOIN transactions tr ON rr.ride_id = tr.ride_id
GROUP BY platform;

--Monthly Revenue:
SELECT DATE_TRUNC('month', transaction_ts) AS transaction_month, SUM(purchase_amount_usd) AS monthly_revenue
FROM transactions
GROUP BY transaction_month
ORDER BY transaction_month;

--Average Revenue per user:

SELECT ROUND(CAST(AVG(total_revenue)AS INTEGER),2) AS average_revenue_per_user
FROM (
SELECT rr.user_id, SUM(t.purchase_amount_usd) AS total_revenue
FROM transactions t
LEFT JOIN ride_requests rr
ON t.ride_id = rr.ride_id
GROUP BY user_id ) AS user_revenue;
Age Group Revenue:
Output :
Query Used:
SELECT s.age_range, ROUND(CAST(SUM(tr.purchase_amount_usd)AS INTEGER),2) AS age_group_revenue
FROM transactions tr
LEFT JOIN ride_requests rr
ON tr.ride_id = rr.ride_id
LEFT JOIN signups s
ON s.user_id = rr.user_id
GROUP BY 1
ORDER BY 2 DESC;

/* queries by Deepthi Binu*/