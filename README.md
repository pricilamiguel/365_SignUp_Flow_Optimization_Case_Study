# **365 Data Science Sign-Up Flow Optimization Case Study**

## Table of Contents
- [Project Overview](#project-overview)
- [About the Company](#about-the-company)
- [Things to Know Before We Start](#things-to-know-before-we-start)
- [Pre-Analysis](#pre-analysis)
- [Current State of Affairs](#current-state-of-affairs)
- [Business Objective](#business-objective)
- [Hypothesis](#hypothesis)
- [Actionable Insights Based on our Analysis](#actionable-insights-based-on-our-analysis)
- [A/B Testing and Conclusion](a/b-testing-and-conclusion)
- [Contact Information](#contact-information)

## Project Overview

We used MySQL to extract relevant data in the form of CSV files and Tableau to create a story-based [dashboard](https://public.tableau.com/app/profile/pricila.miguel/viz/365Sign-UpFlow/Sign_UpFlow) for our analysis.

As a data analyst, our task is to provide recommendations to help elevate the platform based off of data that was collected from the 365 Data Science website which include registration, sign-up, and log-in data.

## About the Company

365 Data Science is a free online education platform that started out using 3rd party sources to host their course content. However, due to constraints in the structure and obtaining limited customer insights from these platforms, the company made a strategic decision to develop its own Learning Management System (LMS) in 2020. Alongside its free educational resources, the platform introduced a paid subscription option, granting users full access to its comprehensive learning content.

Learn more on the [365 Data Science](https://365datascience.com/) website.

## Things to Know Before We Start

At the point of the data collection, the website’s registration screen featured social media options at the top with Google as the first and largest option, and LinkedIn and Facebook as alternative options. Below the social media options is the email option which include empty name, email address, and password fields.

<img width="623" alt="365_SignUp_Screen_V1" src="https://github.com/pricilamiguel/365_SignUp_Flow_Optimization_Case_Study/assets/131540339/46f7139d-c80a-4f48-bf79-5d40c062836a">

### Key Terms:
- **Visitor:** Those who are visiting the website for the first time and have not yet engaged with any of the content.
- **User or Student:** Those who have created an account by completing the registration form. Users can be free for paid.
- **Customer:** Those who have paid for the subscription to gain access to all features on the platform.

## Pre-Analysis

The first visualization on our story-based [dashboard](https://public.tableau.com/app/profile/pricila.miguel/viz/365Sign-UpFlow/Sign_UpFlow), based on the collected data, contained the monthly sign-up conversion rates for both free registered users and all registered users, along with their preferred devices and operating systems.

- **Sign-Up Conversion Rate** = (number of registered users / number of all visitors) * 100
- **Visitor-to-Registered:** All successful registrations
- **Visitor-to-Free:** Of those who registered, are free users; excluding direct purchases.
  - **Direct Purchase:** Those who subscribed within **30 minutes** of registering 

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
> [!NOTE]
> Full sign-up converision rate SQL query [here](Full_SQL_Querries/signup_converstion_rate_query.sql)

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

> [!NOTE]
> Full sign-up types and errors SQL query [here](Full_SQL_Querries/signup_types_errors_query.sql)

The final visualization was made to visually represent users’ log-in capabilities after registration, along with any associated error messages.

<img width="1350" alt="365_LogIn_Types_And_Errors" src="https://github.com/pricilamiguel/365_SignUp_Flow_Optimization_Case_Study/assets/131540339/1a1bdeb6-2de8-49ce-a11e-c17bada49930">

We repeated the steps taken for the log-in types data, as we did for the sign-up types data.

> [!NOTE]
> Full log-in types and errors SQL query [here](Full_SQL_Querries/login_types_query.sql)

## Current State of Affairs

After analyzing the current state of affairs, we found that visitors frequently encountered issues while trying to register on the platform via email on mobile devices. This finding is notable because email sign-up, although the second most common method, registers a substantial number of unsuccessful attempts. Additionally, our findings reveal that Google, the most popular alternative, exhibits higher success rates compared to email for sign-up attempts overall.

> [!NOTE]
> To find the corresponding data findings, refer to the ‘Current State of Affairs’ section in the [365 Sign-Up Flow Optimization Analysis Report](365_Analysis_Report.docx)

## Business Objective

Our main goal is to achieve ongoing business growth by increasing our registered user base. By increasing the visitors-to-free users conversion rate, we anticipate a subsequent rise in paid subscriptions. A high visitor-to-free conversion rate reflects our ability to capture our target audience's interest and encourage them to explore our offerings for free. This, in turn, is expected to result in a gradual increase in paid subscription, leading to an overall increase in revenue.

## Hypothesis

We suspect that the email sign-up section appears to small on mobile devices, causing a majority of the errors. To address this issue, we suggest modifying the email sign-up process to emulate the efficiency and success of Google's mobile registration method. This involves having users input their information on a separate window after initially selecting the email option, following the mirroring method.

Our hypothesis is that by highlighting the more effective social media sign-up options, such as Google, users will be encouraged to choose them, potentially increasing the visitor-to-free conversion rate. By highlighting the social media sign-up options and aim for a 10% lift in our average visitor-to-free conversion rate, we anticipate an increase in our average visitor-to-free conversion rate from 3.2% to approximately 3.54%.

With the free-to-paid conversion rate staying consistent at 3.9%, we can expect a proportional increase in users converting from free to paid. Assuming a consistent visitor volume, for every 10,000 visitors, an additional 14 free users should convert to paid subscriptions, generating an extra $420 in revenue. Ultimately, this strategic adjustment is poised to contribute significantly to the overall growth of the business's revenue.

> [!NOTE]
> For a detailed explanation of how this hypothesis was developed, refer to the ‘Hypothesis’ and ‘Opportunity Sizing’ section in the [365 Sign-Up Flow Optimization Analysis Report](365_Analysis_Report.docx)

## Actionable Insights Based on our Analysis

To enhance the sign-up process, we recommend prioritizing social media sign-up options, particularly Google, which has shown high success rates. This involves restructuring the sign-up screen to highlight efficient alternatives and simplifying the email sign-up option, which currently present empty input fields. Utilizing single-click sign-up methods can enhance mobile user experience and increase the sign-up success rate.

Additionally, to address the email log-in errors, we suggest reducing minimum password requirements, improving the forgotten password sequence, including a “remember me” option, and/or implement an automatically generated strong password feature.

We also recommend conducting a test registration and login via Google on an Android operating system to troubleshoot any issues with pop-up windows. Potential solutions include reminder messages prompting users to switch browsers or disable ad-blockers if needed.

Lastly, we advise collaborating with the relevant department to investigate and resolve unknown errors associated with Facebook sign-up.

These measures aim to ensure a seamless sign-up experience and improve the visitor-to-registered conversion rate. Continuous monitoring and data analysis will facilitate ongoing optimization to meet user preferences.

<img width="1431" alt="365_SignUp_Screen_V2" src="https://github.com/pricilamiguel/365_SignUp_Flow_Optimization_Case_Study/assets/131540339/a9b9a3aa-ba7f-4d65-81ef-6005c463bb9a">

## A/B Testing and Conclusion

We conducted an A/B test to evaluate the effectiveness of restructuring the sign-up screen in boosting the visitor-to-free conversion rate. Over a month, we evenly split more than 300,000 visitors into two groups. In addition to tracking the visitor-to-free conversion rate, we tracked metrics such as sign-up window open conversion rate and average sign-up time.

Key metrics we monitored included site crashes, significant drops in sign-ups, and errors from specific sign-up methods to prevent negative impacts on users and the business. For instance, if a large number of visitors found the new sign-up screen unappealing, successful registrations through version H<sub>1</sub> would substantially decrease compared to the original version, prompting suspension of the test to avoid losing potential customers.

Results confirmed our hypothesis with statistical significance (82.61% power, p-value of 0.0343 at 95% confidence). The modified screen (version H<sub>1</sub>) exhibited a 4.5% higher visitor-to-free conversion rate compared to the original (version H<sub>0</sub>). Additionally, visitors spent less time signing up on the modified screen.

We are confident that the enhanced sign-up screen will attract a larger user base, leading to increased paid users and revenue.

> [!NOTE]
> For a detailed breakdown of the A/B test, refer to the ‘A/B Testing’ section in the [365 Sign-Up Flow Optimization Analysis Report](365_Analysis_Report.docx)

## Contact Information

**Email:** [miguel.pricila98@gmail.com](miguel.pricila98@gmail.com)

**LinkedIn:** [linkedin.com/pricila-miguel](http://www.linkedin.com/in/pricila-miguel-686ab2250)

**Tableau:** [public.tableau.com/pricila.miguel](https://public.tableau.com/app/profile/pricila.miguel/vizzes)
