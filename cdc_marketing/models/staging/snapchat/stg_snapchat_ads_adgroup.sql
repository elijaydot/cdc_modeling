/*
    Staging model: Snapchat Ads ad groups

    Grain: one row per ad_group_id
    Note: source contains a surrogate key and updated_at for history handling
*/

WITH source_data AS (

    SELECT * 
    FROM {{ source('snapchat_ads', 'snapchat_ads_adgroup') }}

),

cleaned AS (

    SELECT
        CAST(ad_group_id AS STRING)         AS ad_group_id,
        CAST(campaign_id AS STRING)         AS campaign_id,
        CAST(ad_group_name AS STRING)       AS ad_group_name,
        CAST(ad_group_updated_at AS TIMESTAMP) AS ad_group_updated_at,

        -- Keep original surrogate key in case it is useful later
        CAST(_surrogate_key AS STRING)      AS _surrogate_key,

        'snapchat'                          AS platform

    FROM source_data

)

SELECT * FROM cleaned