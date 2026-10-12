{{
    config(
        event_time='ad_date'
    )
}}

/*
    Staging model: Snapchat Ads daily performance stats

    Grain: one row per ad_detail_id + ad_date + ad_country
    Purpose: clean raw stats, standardise types, handle dirty values
*/

WITH source_data AS (

    SELECT * 
    FROM {{ source('snapchat_ads', 'snapchat_ads_stats') }}

),

cleaned AS (

    SELECT
        -- Identifiers
        CAST(ad_detail_id AS STRING)                        AS ad_detail_id,
        CAST(ad_currency_code AS STRING)                    AS ad_currency_code,
        CAST(ad_country AS STRING)                          AS ad_country,

        -- Metrics (robust casting)
        TRY_CAST(ad_spend AS DOUBLE)                        AS ad_spend,
        TRY_CAST(ad_impressions AS BIGINT)                  AS ad_impressions,
        TRY_CAST(ad_clicks AS BIGINT)                       AS ad_clicks,

        -- Date
        CAST(ad_date AS DATE)                               AS ad_date,

        -- Original source marker
        CAST(data_src AS STRING)                            AS data_src,

        -- Platform
        'snapchat'                                          AS platform

    FROM source_data

)

SELECT * FROM cleaned