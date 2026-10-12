/*
    Staging model: Snapchat Ads campaigns

    Grain: one row per campaign_id
*/

WITH source_data AS (

    SELECT * 
    FROM {{ source('snapchat_ads', 'snapchat_ads_campaign') }}

),

cleaned AS (

    SELECT
        CAST(campaign_id AS STRING)     AS campaign_id,
        CAST(account_id AS STRING)      AS account_id,
        CAST(campaign_name AS STRING)   AS campaign_name,

        'snapchat'                      AS platform

    FROM source_data

)

SELECT * FROM cleaned