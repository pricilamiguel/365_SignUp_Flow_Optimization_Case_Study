USE signup_flow;

SELECT
	a.visitor_id,
	s.user_id,
    ANY_VALUE(CAST(s.date_registered AS DATE)) AS registration_date,
    ANY_VALUE(CAST(a.action_date AS DATE )) AS signup_date,
    ANY_VALUE(CASE
		WHEN a.action_name LIKE '%google%'
        THEN 'google'
        WHEN a.action_name LIKE '%facebook%'
        THEN 'facebook'
        WHEN a.action_name LIKE '%linkedin%'
        THEN 'linkedin'
        ELSE 'email'
	END) AS signup_method,
	ANY_VALUE(CASE
		WHEN a.action_name LIKE '%success%'
			AND s.date_registered IS NOT NULL
            AND CAST(s.date_registered AS DATE)  = CAST(a.action_date AS DATE)
		THEN 'direct success'
        WHEN a.action_name LIKE '%fail%'
			AND s.date_registered IS NULL
		THEN 'fail'
        WHEN a.action_name LIKE '%fail%'
			AND s.date_registered IS NOT NULL
            AND CAST(date_registered AS DATE) >= CAST(a.action_date AS DATE)
		THEN 'successful retry'
	END) AS signup_attempt,
    ANY_VALUE(IFNULL(e.error_text, '')) AS error_message,
    ANY_VALUE(se.session_os) AS session_os,
    ANY_VALUE(CASE
		WHEN se.session_os LIKE '%Android%'
			OR se.session_os LIKE '%iOS%'
        THEN 'mobile'
        WHEN se.session_os LIKE '%Windows%'
			OR se.session_os LIKE '%Linux%'
            OR se.session_os LIKE 'OS%'
            OR se.session_os LIKE '%Ubuntu%'
            OR se.session_os LIKE '%Chrome%'
        THEN 'desktop'
        ELSE 'other'
	END) AS device
FROM actions a
LEFT JOIN visitors v
	ON a.visitor_id = v.visitor_id
LEFT JOIN students s
	ON v.user_id = s.user_id
LEFT JOIN error_messages e
	ON a.error_id = e.error_id
LEFT JOIN sessions se
	ON a.visitor_id = se.visitor_id
WHERE a.action_name LIKE '%sign%'
	AND a.action_name LIKE '%click%'
	AND (a.action_name LIKE '%success%'
		OR a.action_name LIKE '%fail%')
	AND v.first_visit_date >= '2022-07-01'
    AND a.action_date BETWEEN '2022-07-01' AND '2023-02-01'
GROUP BY visitor_id
HAVING signup_attempt IS NOT NULL
ORDER BY signup_date;

/*
Without inlcluding the ANY_VALUE() function for the selected columns, I recieved the error message: 
Error Code: 1055. Expression #4 of SELECT list is not in GROUP BY clause and contains nonaggregated column
'signup_flow.p.purchase_date' which is not functionally dependent on columns in GROUP BY clause; this is incompatible
with sql_mode=only_full_group_by
*/