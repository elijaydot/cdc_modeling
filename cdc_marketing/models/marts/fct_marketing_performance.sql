{{
    config(
        materialized='table'
    )
}}

/*
    Final analytical model: Marketing performance

    Purpose:
    - Single trusted table for analysts, BI tools and AI agents
    - Combines performance metrics with key descriptive attributes
    - Calculates standard marketing KPIs safely (CTR, CPC, CPM)

    Grain: one row per platform + ad_id + date
*/

WITH stats AS (

    SELECT * FROM {{ ref('int_marketing_ads_stats') }}

),

facebook_details AS (

    SELECT
        ad_id,
        platform,
        campaign_id,
        campaign_name,
        ad_group_id,
        ad_group_name,
        ad_name,
        account_id,
        account_name,
        channel_name
    FROM {{ ref('int_facebook_ads_details') }}

),

snapchat_details AS (

    SELECT
        ad_id,
        platform,
        campaign_id,
        campaign_name,
        ad_group_id,
        ad_group_name,
        ad_name,
        account_id,
        CAST(NULL AS STRING) AS account_name,
        channel_name
    FROM {{ ref('int_snapchat_ads_details') }}

),

details AS (

    SELECT * FROM facebook_details
    UNION ALL
    SELECT * FROM snapchat_details

),

joined AS (

    SELECT
        s.date_day,
        s.platform,
        s.ad_id,
        d.ad_name,
        d.ad_group_id,
        d.ad_group_name,
        d.campaign_id,
        d.campaign_name,
        d.account_id,
        d.account_name,
        d.channel_name,

        s.spend,
        s.impressions,
        s.clicks,

        -- Safe calculated metrics
        CASE
            WHEN s.impressions > 0 THEN s.clicks * 1.0 / s.impressions
            ELSE NULL
        END AS ctr,

        CASE
            WHEN s.clicks > 0 THEN s.spend / s.clicks
            ELSE NULL
        END AS cpc,

        CASE
            WHEN s.impressions > 0 THEN (s.spend / s.impressions) * 1000
            ELSE NULL
        END AS cpm

    FROM stats s
    LEFT JOIN details d
        ON  s.ad_id    = d.ad_id
        AND s.platform = d.platform

)

SELECT
    date_day,
    platform,
    ad_id,
    ad_name,
    ad_group_id,
    ad_group_name,
    campaign_id,
    campaign_name,
    account_id,
    account_name,
    channel_name,
    spend,
    impressions,
    clicks,
    ctr,
    cpc,
    cpm
FROM joined