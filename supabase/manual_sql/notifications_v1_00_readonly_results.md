# Notifications v1 — Read-only check results

**Script:** [`notifications_v1_00_readonly_checks.sql`](notifications_v1_00_readonly_checks.sql)

**Captured:** Run this file in Supabase SQL Editor and paste key outputs below. (Automated MCP run was unavailable in agent session.)

## Expected exit criteria

- `evening_checkin_candidates`, `day_cutoff_check`, `invoke_edge_function`, `invoke_dispatch_notification` exist
- `send-evening-checkins` and `day-cutoff-check` crons **active**
- `send-daily-recap` cron **absent** until you run `notifications_v1_02_schedule_daily_recap.sql`
- If `lead_fn_has_scoring_mode` = **false**, run `notifications_v1_04_notify_lead_changed_scoring_mode.sql` after deploy

## Paste results here

| Check | Result |
|-------|--------|
| Cron: send-morning-checkins | |
| Cron: send-evening-checkins | |
| Cron: send-pending-reminders | |
| Cron: day-cutoff-check | |
| Cron: send-daily-recap | |
CRON Results : [
  {
    "jobid": 1,
    "jobname": "day-cutoff-check",
    "schedule": "5 * * * *",
    "active": true,
    "command_preview": " SELECT public.day_cutoff_check(); "
  },
  {
    "jobid": 10,
    "jobname": "send-evening-checkins",
    "schedule": "0 * * * *",
    "active": true,
    "command_preview": "SELECT private.invoke_edge_function('send-evening-checkins', '{}'::jsonb);"
  },
  {
    "jobid": 3,
    "jobname": "send-morning-checkins",
    "schedule": "0 13 * * *",
    "active": true,
    "command_preview": " SELECT private.invoke_edge_function('send-morning-checkins', '{}'::jsonb); "
  },
  {
    "jobid": 2,
    "jobname": "send-pending-reminders",
    "schedule": "15 16 * * *",
    "active": true,
    "command_preview": " SELECT private.invoke_edge_function('send-pending-reminders', '{}'::jsonb); "
  }
]


| lead_fn_has_scoring_mode | |
| Vault secrets (2 names) | |

#3 ) and reqjuired functions 
--
  'notify_lead_changed',
    'evening_checkin_candidates',
    'day_cutoff_check'
    ----
[
  {
    "schema": "private",
    "name": "invoke_dispatch_notification"
  },
  {
    "schema": "private",
    "name": "invoke_edge_function"
  },
  {
    "schema": "public",
    "name": "day_cutoff_check"
  },
  {
    "schema": "public",
    "name": "evening_checkin_candidates"
  },
  {
    "schema": "public",
    "name": "notify_lead_changed"
  }
]

4) true
5) | event_type           | status | n   |
| -------------------- | ------ | --- |
| live_activity_update | failed | 276 |
| live_activity_update | sent   | 36  |
| lead_changed         | sent   | 9   |
| challenge_received   | sent   | 3   |
| lead_changed         | failed | 2   |

6) sucesss no rows 


7) 
| match_id                             | state  | metric_type | scoring_mode | duration_days | day_number | day_status | calendar_date | user_id                              | metric_total | finalized_value | last_updated_at               |
| ------------------------------------ | ------ | ----------- | ------------ | ------------- | ---------- | ---------- | ------------- | ------------------------------------ | ------------ | --------------- | ----------------------------- |
| 60b55594-1b52-421d-93ff-4f87d4b9b0ed | active | steps       | raw          | 3             | 3          | pending    | 2026-05-21    | a5b6bfe5-5d65-424b-b8f6-ead6b07237cd | 516          | null            | 2026-05-21 12:56:30.734+00    |
| 60b55594-1b52-421d-93ff-4f87d4b9b0ed | active | steps       | raw          | 3             | 3          | pending    | 2026-05-21    | 229c25e5-2d7d-453e-a30e-c6dd37cf0ce2 | 455          | null            | 2026-05-21 12:08:06.897+00    |
| 60b55594-1b52-421d-93ff-4f87d4b9b0ed | active | steps       | raw          | 3             | 2          | pending    | 2026-05-20    | a5b6bfe5-5d65-424b-b8f6-ead6b07237cd | 1673         | null            | 2026-05-21 06:07:27.032+00    |
| 60b55594-1b52-421d-93ff-4f87d4b9b0ed | active | steps       | raw          | 3             | 2          | pending    | 2026-05-20    | 229c25e5-2d7d-453e-a30e-c6dd37cf0ce2 | 5197         | null            | 2026-05-20 22:41:11.524+00    |
| 60b55594-1b52-421d-93ff-4f87d4b9b0ed | active | steps       | raw          | 3             | 1          | finalized  | 2026-05-19    | 229c25e5-2d7d-453e-a30e-c6dd37cf0ce2 | 0            | 0               | 2026-05-20 15:05:00.192672+00 |
| 60b55594-1b52-421d-93ff-4f87d4b9b0ed | active | steps       | raw          | 3             | 1          | finalized  | 2026-05-19    | a5b6bfe5-5d65-424b-b8f6-ead6b07237cd | 2338         | 2338            | 2026-05-20 05:19:33.443+00    |
================
8) | with_apns | without_apns | total_profiles |
| --------- | ------------ | -------------- |
| 8         | 0            | 8              |

-=========-
9) | name                   |
| ---------------------- |
| fitup_project_url      |
| fitup_service_role_key |