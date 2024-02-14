# **365 Data Science Sign-Up Flow Optimization Case Study**

## Project Overview

We used MySQL to extract relevant data in the form of CSV files and Tableau to create a story-based [dashboard](https://public.tableau.com/app/profile/pricila.miguel/viz/365Sign-UpFlow/Sign_UpFlow) for our analysis.

As a data analyst, our task is to provide recommendations to help elevate the platform based off of data that was collected from the 365 Data Science website which include registration, sign-up, and log-in data.

## About the Company

365 Data Science is a free online education platform that started out using 3rd party sources to host their course content. However, due to constraints in the structure and obtaining limited customer insights from these platforms, the company made a strategic decision to develop its own Learning Management System (LMS) in 2020. Alongside its free educational resources, the platform introduced a paid subscription option, granting users full access to its comprehensive learning content.

## Thing to Know Before We Start

At the point of the data collection, the website’s registration screen featured social media options at the top with Google as the first and largest option, and LinkedIn and Facebook as alternative options. Below the social media options is the email option which include empty name, email address, and password fields.

<img width="623" alt="365_SignUp_Screen_V1" src="https://github.com/pricilamiguel/365_SignUp_Flow_Optimization_Case_Study/assets/131540339/46f7139d-c80a-4f48-bf79-5d40c062836a">

### Key Terms:
- **Visitor:** Those who are visiting the website for the first time and have not yet engaged with any of the content.
- **User or Student:** Those who have created an account by completing the registration form. Users can be free for paid.
- **Customer:** Those who have paid for the subscription to gain access to all features on the platform.

## Pre-Analysis

The first visualization, based on the collected data, contained the monthly sign-up conversion rates for both free registered users and all registered users, along with their preferred devices and operating systems.

- **Sign-Up Conversion Rate** = (number of registered users / number of all visitors) * 100
- **Visitor-to-Registered:** All successful registrations
- **Visitor-to-Free:** Of those who registered, are free users; excluding direct purchases.
  - **Direct Purchase:** Those who subscribed within 30 minutes of registering 

<img width="1350" alt="365_SignUp_Conversion_Rate_And_Devices" src="https://github.com/pricilamiguel/365_SignUp_Flow_Optimization_Case_Study/assets/131540339/e0125f91-2486-4532-963a-c01c5194219c">

To differentiate visitors from the data, we used a CTE, enabling us to reference it later on.
```sql
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
)
```

Next, we want to find the number of visitors *per day*.
```sql
count_visitors AS
(
  SELECT
    first_visit_date AS date_session,
    COUNT(*) AS count_total_visitors
  FROM total_visitors
  GROUP BY date_session
)
```

Then we want to find the number of registered users to use for our visitor-to-registered conversion rate...
```sql
count_registered AS
(
  SELECT
    first_visit_date AS date_session,
    COUNT(*) AS count_total_registered
  FROM total_visitors
  WHERE registration_date IS NOT NULL
  GROUP BY date_session
)
```

...along with the number of free users to use for our visitor-to-free conversion rate.
```sql
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
```

Finally, we want to obtain the relevant number of total visitors, as well as registered and free users by date.
```sql
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
```

The next visualization we created enabled us to explore the preferred methods for signing up on the platform, including device and operating systems, and to analyze the errors encountered by visitors when their registration fails.

<img width="1350" alt="365_SignUp_Types_And_Errors" src="https://github.com/pricilamiguel/365_SignUp_Flow_Optimization_Case_Study/assets/131540339/3de13bec-c76a-4330-99ac-d58949baa884">

To accomplish this, we will differentiate between the various sign-up options.
```sql
ANY_VALUE(CASE
  WHEN a.action_name LIKE '%google%'
  THEN 'google'
  WHEN a.action_name LIKE '%facebook%'
  THEN 'facebook'
  WHEN a.action_name LIKE '%linkedin%'
  THEN 'linkedin'
  ELSE 'email'
END) AS signup_method,
```

Next, we want to discern the outcomes of the sign-up attempts...
```sql
ANY_VALUE(CASE
  WHEN a.action_name LIKE '%success%'
    AND s.date_registered IS NOT NULL
    AND CAST(s.date_registered AS DATE) = CAST(a.action_date AS DATE)
  THEN 'direct success'
  WHEN a.action_name LIKE '%fail%'
    AND s.date_registered IS NULL
  THEN 'fail'
  WHEN a.action_name LIKE '%fail%'
    AND s.date_registered IS NOT NULL
    AND CAST(date_registered AS DATE) >= CAST(a.action_date AS DATE)
  THEN 'successful retry'
END) AS signup_attempt,
```

...and the relevant error messages when an attempt fails.
```sql
ANY_VALUE(IFNULL(e.error_text, '')) AS error_message,
```

Lastly, we will categorize the visitors based on the operating system they use...
```sql
ANY_VALUE(se.session_os) AS session_os,
```

...and the device they use.
```sql
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
```
The final visualization was made to visually represent users’ log-in capabilities after registration, along with any associated error messages.

<img width="1350" alt="365_LogIn_Types_And_Errors" src="https://github.com/pricilamiguel/365_SignUp_Flow_Optimization_Case_Study/assets/131540339/1a1bdeb6-2de8-49ce-a11e-c17bada49930">

We repeated the steps taken for the log-in types data, as we did for the sign-up types data.

## Current Sate of Affairs

After analyzing the current state of affairs, we discovered that visitors often experienced trouble when attempting to register on the platform when utilizing the email sign-up option on their mobile devices. This finding is particularly noteworthy as the email sign-up method ranks as the second most common, while at the same time exhibiting a significant number of unsuccessful sign-up attempts. Additionally, our findings reveal that Google, the most widely used alternative overall and demonstrates higher success rates compared to email when it comes to sign-up attempts.

