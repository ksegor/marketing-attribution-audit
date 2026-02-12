WITH 
-- 1. Сбор данных о расходах из разных источников
Costs AS (
    SELECT campaign_date, utm_source, utm_medium, utm_campaign, daily_spent FROM vk_ads
    UNION ALL
    SELECT campaign_date, utm_source, utm_medium, utm_campaign, daily_spent FROM ya_ads
),
-- 2. Определение последнего платного клика (LPC) и привязка лидов
LPC AS (
    SELECT
        s.visitor_id,
        CAST(s.visit_date AS DATE) AS visit_date,
        s.source,
        s.medium,
        s.campaign,
        l.lead_id,
        l.amount,
        l.closing_reason,
        l.status_id,
        ROW_NUMBER() OVER(PARTITION BY s.visitor_id ORDER BY s.visit_date DESC) AS rn
    FROM sessions s
    LEFT JOIN leads l ON s.visitor_id = l.visitor_id
    WHERE s.medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),
-- 3. Фильтрация только последних платных сессий
AttributedSessions AS (
    SELECT * FROM LPC WHERE rn = 1
),
-- 4. Агрегация данных по датам и каналам
AggregatedData AS (
    SELECT
        a.visit_date,
        a.source AS utm_source,
        a.medium AS utm_medium,
        a.campaign AS utm_campaign,
        COUNT(a.visitor_id) AS visitors_count,
        COUNT(a.lead_id) AS leads_count,
        COUNT(CASE WHEN a.closing_reason = 'Успешно реализовано' OR a.status_id = 142 THEN 1 END) AS purchases_count,
        SUM(CASE WHEN a.closing_reason = 'Успешно реализовано' OR a.status_id = 142 THEN a.amount ELSE 0 END) AS revenue,
        COALESCE(c.total_cost, 0) AS total_cost
    FROM AttributedSessions a
    LEFT JOIN (
        SELECT campaign_date, utm_source, utm_medium, utm_campaign, SUM(daily_spent) AS total_cost
        FROM Costs
        GROUP BY 1, 2, 3, 4
    ) c ON a.visit_date = c.campaign_date 
        AND a.source = c.utm_source 
        AND a.medium = c.utm_medium 
        AND a.campaign = c.utm_campaign
    GROUP BY 1, 2, 3, 4, c.total_cost
)
-- 5. Финальный расчет маркетинговых метрик
SELECT 
    *,
    -- CR % (Конверсия из посетителя в покупателя)
    CASE 
        WHEN visitors_count > 0 THEN ROUND((purchases_count::float / visitors_count) * 100, 2) 
        ELSE 0 
    END AS cr_pct,
    -- ROI % (Окупаемость инвестиций)
    CASE 
        WHEN total_cost > 0 THEN ROUND(((revenue - total_cost) / total_cost) * 100, 2) 
        ELSE NULL 
    END AS roi_pct,
    -- CPL (Стоимость одного лида)
    CASE 
        WHEN leads_count > 0 THEN ROUND(total_cost / leads_count, 2) 
        ELSE NULL 
    END AS cpl,
    -- CPP (Стоимость одной покупки)
    CASE 
        WHEN purchases_count > 0 THEN ROUND(total_cost / purchases_count, 2) 
        ELSE NULL 
    END AS cpp
FROM AggregatedData
ORDER BY revenue DESC NULLS LAST;