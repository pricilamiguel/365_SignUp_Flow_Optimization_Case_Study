USE signup_flow;

SELECT
    ANY_VALUE(a.visitor_id) AS visitor_id,
    ANY_VALUE(v.first_visit_date) AS first_visit_date,
    ANY_VALUE(s.user_id) AS user_id,
	ANY_VALUE(CAST(s.date_registered AS DATE)) AS registration_date,
    ANY_VALUE(CAST(a.action_date AS DATE)) AS login_date,
    ANY_VALUE(CASE
		WHEN a.action_name LIKE '%google%'
        THEN 'google'
        WHEN a.action_name LIKE '%linkedin%'
        THEN 'linkedin'
        WHEN a.action_name LIKE '%facebook%'
        THEN 'facebook'
        ELSE 'email'
        END) AS login_method,
	ANY_VALUE(CASE
		WHEN a.action_name LIKE '%success%'
		THEN 'success'
        WHEN a.action_name LIKE '%fail%'
        THEN 'fail'
        END) AS login_attempt,
	ANY_VALUE(IFNULL(e.error_text, '')) AS error_message,
	ANY_VALUE(se.session_os) AS session_os,
	ANY_VALUE(CASE
		WHEN se.session_os LIKE 'iOS%'
			OR se.session_os LIKE 'Android%'
		THEN 'mobile'
		WHEN se.session_os LIKE 'Windows%'
			OR se.session_os LIKE 'OS%'
			OR se.session_os LIKE 'Linux%'
			OR se.session_os LIKE 'Chrome%'
			OR se.session_os LIKE '%Ubuntu%'
		THEN 'desktop'
		ELSE 'other'
		END) AS device_type
FROM actions a
LEFT JOIN visitors v
	ON v.visitor_id = a.visitor_id
LEFT JOIN students s
	ON s.user_id = v.user_id
LEFT JOIN error_messages e
	ON e.error_id = a.error_id
LEFT JOIN sessions se
	ON se.visitor_id = a.visitor_id
WHERE
	v.first_visit_date >= '2022-07-01'
		AND a.action_name LIKE '%log%'
		AND a.action_name LIKE '%click%'
		AND (a.action_name LIKE '%success%'
		OR a.action_name LIKE '%fail%')
GROUP BY
	se.session_id
HAVING login_attempt IS NOT NULL
	AND registration_date <= login_date
ORDER BY login_date;

/* I recieve the same error messages I recieved from the 'signup_types_errors_query' if I did not inlcude the ANY_VALUE()
function on the selected columns. */