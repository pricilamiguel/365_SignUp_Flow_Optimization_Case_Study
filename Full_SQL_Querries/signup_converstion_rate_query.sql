USE signup_flow;

WITH total_visitors AS
(
	SELECT
		v.visitor_id,
        v.first_visit_date,
        s.date_registered AS registration_date,
       MAX(p.purchase_date) most_recent_purchase_date
	FROM visitors v
    LEFT JOIN students s
		ON v.user_id = s.user_id
	LEFT JOIN student_purchases p
		ON v.user_id = p.user_id
	GROUP BY v.visitor_id
),

count_visitors AS
(
	SELECT
		first_visit_date AS date_session,
        COUNT(*) AS count_total_visitors
	FROM total_visitors
    GROUP BY date_session
),

count_registered AS
(
	SELECT
		first_visit_date AS date_session,
        COUNT(*) AS count_total_registered
	FROM total_visitors
    WHERE registration_date IS NOT NULL
    GROUP BY date_session
),
   
   count_registered_free AS
(
	SELECT
		first_visit_date AS date_session,
        COUNT(*) AS count_total_registered_free
	FROM total_visitors
    WHERE registration_date IS NOT NULL
		AND (most_recent_purchase_date IS NULL
			OR TIMESTAMPDIFF(minute, registration_date, most_recent_purchase_date) >30)
    GROUP BY date_session
)

SELECT
	cv.date_session AS date_session,
    cv.count_total_visitors,
    IFNULL(cr.count_total_registered, 0) AS count_registered,
    IFNULL(crf.count_total_registered_free, 0) AS free_registered_users
FROM count_visitors cv
LEFT JOIN count_registered cr
	ON cv.date_session = cr.date_session
LEFT JOIN count_registered_free crf
	ON cv.date_session = crf.date_session
WHERE cv.date_session < '2023-02-01'
ORDER BY cv.date_session;

/*
Without adding MAX() for the p.purchse_date, I recieved the error message: 
Error Code: 1055. Expression #4 of SELECT list is not in GROUP BY clause and contains nonaggregated column
'signup_flow.p.purchase_date' which is not functionally dependent on columns in GROUP BY clause; this is incompatible
with sql_mode=only_full_group_by
*/

/* In order to work around the error message, I either had to disable only_full_group_by mode or aggregate the 'purchase_date' column.
I did not want to disable only_full_group_by mode, so I used this query to figure out if there were more than one purchases being made
by a single user, which was preventing me from excluding the 'purchase_date' column in the GROUP BY clause.
*/
SELECT user_id, MAX(purchase_date), MIN(purchase_date)
FROM student_purchases
GROUP BY user_id;
-- The reason why I decided to used MAX() was because if a user made more than one purchase, it would at least show the most recent purchase.
-- If any user only made one purchse, using the MAX() function will still retrieve that purchase date since it is their most recent purchase.