WITH PaidClicks AS (
    SELECT
        s.visitor_id,
        s.visit_date,
        s.source,
        s.medium,
        s.campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    FROM
        sessions s
    LEFT JOIN
        leads l ON s.visitor_id = l.visitor_id
    WHERE
        l.lead_id IS NOT NULL
        AND s.medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),
RankedClicks AS (
    SELECT
        c.*,
        ROW_NUMBER() OVER(PARTITION BY c.visitor_id ORDER BY c.visit_date DESC) AS rn
    FROM
        PaidClicks c
)
SELECT
    visitor_id,
    visit_date,
    source AS utm_source,
    medium AS utm_medium,
    campaign AS utm_campaign,
    lead_id,
    created_at,
    amount,
    closing_reason,
    status_id
FROM
    RankedClicks
WHERE
    rn = 1
ORDER BY
    amount DESC NULLS LAST,
    visit_date ASC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC;