/*
    Staging model: Snapchat Ads (ad level)

    Grain: one row per ad_id
*/

WITH source_data AS (

    SELECT * 
    FROM {{ source('snapchat_ads', 'snapchat_ads') }}

),

cleaned AS (

    SELECT
        CAST(ad_id AS STRING)                   AS ad_id,
        CAST(ad_group_id AS STRING)             AS ad_group_id,
        CAST(ad_name AS STRING)                 AS ad_name,
        CAST(ad_detail_updated_at AS TIMESTAMP) AS ad_detail_updated_at,

        'snapchat'                              AS platform

    FROM source_data

)

SELECT * FROM cleaned