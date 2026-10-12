/*
    Intermediate model: Snapchat Ads details

    Purpose:
    - Select the latest version of each ad, ad group and campaign
    - Join the marketing hierarchy
    - Produce a clean, denormalised ad-level dimension

    Grain: one row per ad_id
*/

WITH latest_ads AS (

    SELECT *
    FROM {{ ref('stg_snapchat_ads') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY ad_id
        ORDER BY ad_detail_updated_at DESC
    ) = 1

),

latest_ad_groups AS (

    SELECT *
    FROM {{ ref('stg_snapchat_ads_adgroup') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY ad_group_id
        ORDER BY ad_group_updated_at DESC
    ) = 1

),

latest_campaigns AS (

    SELECT *
    FROM {{ ref('stg_snapchat_ads_campaign') }}
    -- No updated_at column in this table, so no QUALIFY needed

),

joined AS (

    SELECT
        a.ad_id,
        a.ad_group_id,
        ag.campaign_id,
        c.account_id,

        -- Names
        a.ad_name,
        ag.ad_group_name,
        c.campaign_name,

        -- Standard fields
        'Paid Social'                       AS channel_name,
        'snapchat'                          AS platform,
        'snapchat_ads'                      AS data_src,

        -- Metadata
        a.ad_detail_updated_at,
        ag.ad_group_updated_at

    FROM latest_ads a
    LEFT JOIN latest_ad_groups ag
        ON a.ad_group_id = ag.ad_group_id
    LEFT JOIN latest_campaigns c
        ON ag.campaign_id = c.campaign_id

)

SELECT * FROM joined