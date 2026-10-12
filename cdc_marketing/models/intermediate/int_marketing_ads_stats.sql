/*
    Intermediate model: Unified marketing ads stats

    Purpose:
    - Union Facebook and Snapchat daily stats
    - Standardise column names
    - Aggregate Snapchat from (ad + day + country) → (ad + day)
      so both platforms share the same grain

    Grain: one row per platform + ad_id + date
*/

WITH facebook_stats AS (

    SELECT
        ad_id,
        ad_date                         AS date_day,
        'facebook'                      AS platform,
        ad_spend                        AS spend,
        ad_impressions                  AS impressions,
        ad_clicks                       AS clicks
    FROM {{ ref('stg_facebook_ads_basic_all_levels') }}

),

snapchat_stats_raw AS (

    SELECT
        ad_detail_id                    AS ad_id,
        ad_date                         AS date_day,
        'snapchat'                      AS platform,
        ad_spend                        AS spend,
        ad_impressions                  AS impressions,
        ad_clicks                       AS clicks
    FROM {{ ref('stg_snapchat_ads_stats') }}

),

snapchat_stats AS (

    SELECT
        ad_id,
        date_day,
        platform,
        SUM(spend)                      AS spend,
        SUM(impressions)                AS impressions,
        SUM(clicks)                     AS clicks
    FROM snapchat_stats_raw
    GROUP BY 1, 2, 3

),

unioned AS (

    SELECT * FROM facebook_stats
    UNION ALL
    SELECT * FROM snapchat_stats

)

SELECT * FROM unioned