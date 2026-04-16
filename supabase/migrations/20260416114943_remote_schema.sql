create extension if not exists "pg_cron" with schema "pg_catalog";

drop extension if exists "pg_net";

create schema if not exists "private";

create extension if not exists "pg_net" with schema "public";


  create table "public"."all_time_bests" (
    "user_id" uuid not null,
    "steps_best_day" numeric,
    "steps_best_week" numeric,
    "cals_best_day" numeric,
    "cals_best_week" numeric,
    "best_win_streak_days" integer,
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."all_time_bests" enable row level security;


  create table "public"."app_logs" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid,
    "category" text not null,
    "level" text not null default 'info'::text,
    "message" text not null,
    "metadata" jsonb,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."app_logs" enable row level security;


  create table "public"."direct_challenges" (
    "id" uuid not null default gen_random_uuid(),
    "challenger_id" uuid not null,
    "recipient_id" uuid not null,
    "match_id" uuid,
    "status" text not null default 'pending'::text,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."direct_challenges" enable row level security;


  create table "public"."leaderboard_entries" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "week_start" date not null,
    "points" integer not null default 0,
    "wins" integer not null default 0,
    "losses" integer not null default 0,
    "streak" integer not null default 0,
    "rank" integer,
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."leaderboard_entries" enable row level security;


  create table "public"."match_day_participants" (
    "id" uuid not null default gen_random_uuid(),
    "match_day_id" uuid not null,
    "user_id" uuid not null,
    "metric_total" numeric not null default 0,
    "finalized_value" numeric,
    "data_status" text not null default 'pending'::text,
    "last_updated_at" timestamp with time zone not null default now()
      );


alter table "public"."match_day_participants" enable row level security;


  create table "public"."match_days" (
    "id" uuid not null default gen_random_uuid(),
    "match_id" uuid not null,
    "day_number" integer not null,
    "calendar_date" date not null,
    "status" text not null default 'pending'::text,
    "winner_user_id" uuid,
    "is_void" boolean not null default false,
    "finalized_at" timestamp with time zone,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."match_days" enable row level security;


  create table "public"."match_participants" (
    "id" uuid not null default gen_random_uuid(),
    "match_id" uuid not null,
    "user_id" uuid not null,
    "role" text not null,
    "joined_via" text not null,
    "accepted_at" timestamp with time zone,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."match_participants" enable row level security;


  create table "public"."match_search_requests" (
    "id" uuid not null default gen_random_uuid(),
    "creator_id" uuid not null,
    "metric_type" text not null,
    "duration_days" integer not null,
    "start_mode" text not null default 'today'::text,
    "status" text not null default 'searching'::text,
    "creator_baseline" numeric,
    "matched_match_id" uuid,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."match_search_requests" enable row level security;


  create table "public"."matches" (
    "id" uuid not null default gen_random_uuid(),
    "match_type" text not null,
    "metric_type" text not null,
    "duration_days" integer not null,
    "start_mode" text not null default 'today'::text,
    "state" text not null default 'pending'::text,
    "match_timezone" text not null default 'America/Chicago'::text,
    "starts_at" timestamp with time zone,
    "ends_at" timestamp with time zone,
    "created_at" timestamp with time zone not null default now(),
    "completed_at" timestamp with time zone
      );


alter table "public"."matches" enable row level security;


  create table "public"."metric_snapshots" (
    "id" uuid not null default gen_random_uuid(),
    "match_id" uuid not null,
    "user_id" uuid not null,
    "metric_type" text not null,
    "value" numeric not null,
    "source_date" date not null,
    "synced_at" timestamp with time zone not null default now(),
    "flagged" boolean not null default false,
    "metadata" jsonb
      );


alter table "public"."metric_snapshots" enable row level security;


  create table "public"."notification_events" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "event_type" text not null,
    "status" text not null default 'pending'::text,
    "payload" jsonb,
    "sent_at" timestamp with time zone,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."notification_events" enable row level security;


  create table "public"."profiles" (
    "id" uuid not null default gen_random_uuid(),
    "auth_user_id" uuid not null,
    "display_name" text not null,
    "initials" text not null,
    "avatar_url" text,
    "subscription_tier" text not null default 'free'::text,
    "apns_token" text,
    "timezone" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now(),
    "notifications_enabled" boolean not null default true,
    "live_activity_push_token" text
      );


alter table "public"."profiles" enable row level security;


  create table "public"."user_health_baselines" (
    "user_id" uuid not null,
    "rolling_avg_7d_steps" numeric,
    "rolling_avg_7d_calories" numeric,
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."user_health_baselines" enable row level security;

CREATE INDEX al_level ON public.app_logs USING btree (level);

CREATE INDEX al_user_created ON public.app_logs USING btree (user_id, created_at DESC);

CREATE UNIQUE INDEX all_time_bests_pkey ON public.all_time_bests USING btree (user_id);

CREATE UNIQUE INDEX app_logs_pkey ON public.app_logs USING btree (id);

CREATE INDEX dc_challenger ON public.direct_challenges USING btree (challenger_id);

CREATE INDEX dc_recipient ON public.direct_challenges USING btree (recipient_id, status);

CREATE UNIQUE INDEX direct_challenges_pkey ON public.direct_challenges USING btree (id);

CREATE INDEX le_week ON public.leaderboard_entries USING btree (week_start, points DESC);

CREATE UNIQUE INDEX leaderboard_entries_pkey ON public.leaderboard_entries USING btree (id);

CREATE UNIQUE INDEX leaderboard_entries_user_id_week_start_key ON public.leaderboard_entries USING btree (user_id, week_start);

CREATE UNIQUE INDEX match_day_participants_match_day_id_user_id_key ON public.match_day_participants USING btree (match_day_id, user_id);

CREATE UNIQUE INDEX match_day_participants_pkey ON public.match_day_participants USING btree (id);

CREATE UNIQUE INDEX match_days_match_id_day_number_key ON public.match_days USING btree (match_id, day_number);

CREATE UNIQUE INDEX match_days_pkey ON public.match_days USING btree (id);

CREATE UNIQUE INDEX match_participants_match_id_user_id_key ON public.match_participants USING btree (match_id, user_id);

CREATE UNIQUE INDEX match_participants_pkey ON public.match_participants USING btree (id);

CREATE UNIQUE INDEX match_search_requests_pkey ON public.match_search_requests USING btree (id);

CREATE UNIQUE INDEX matches_pkey ON public.matches USING btree (id);

CREATE INDEX matches_state ON public.matches USING btree (state);

CREATE INDEX md_match ON public.match_days USING btree (match_id);

CREATE INDEX md_status ON public.match_days USING btree (status);

CREATE INDEX mdp_match_day ON public.match_day_participants USING btree (match_day_id);

CREATE INDEX mdp_user ON public.match_day_participants USING btree (user_id);

CREATE UNIQUE INDEX metric_snapshots_pkey ON public.metric_snapshots USING btree (id);

CREATE INDEX mp_match ON public.match_participants USING btree (match_id);

CREATE INDEX mp_user_match ON public.match_participants USING btree (user_id, match_id);

CREATE INDEX ms_match ON public.metric_snapshots USING btree (match_id);

CREATE INDEX ms_user_date ON public.metric_snapshots USING btree (user_id, source_date DESC);

CREATE INDEX msq_creator_status ON public.match_search_requests USING btree (creator_id, status);

CREATE INDEX msq_status_metric ON public.match_search_requests USING btree (status, metric_type, duration_days, start_mode);

CREATE INDEX ne_status ON public.notification_events USING btree (status);

CREATE INDEX ne_user_created ON public.notification_events USING btree (user_id, created_at DESC);

CREATE UNIQUE INDEX notification_events_pkey ON public.notification_events USING btree (id);

CREATE INDEX profiles_auth_user ON public.profiles USING btree (auth_user_id);

CREATE UNIQUE INDEX profiles_auth_user_id_key ON public.profiles USING btree (auth_user_id);

CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id);

CREATE UNIQUE INDEX user_health_baselines_pkey ON public.user_health_baselines USING btree (user_id);

alter table "public"."all_time_bests" add constraint "all_time_bests_pkey" PRIMARY KEY using index "all_time_bests_pkey";

alter table "public"."app_logs" add constraint "app_logs_pkey" PRIMARY KEY using index "app_logs_pkey";

alter table "public"."direct_challenges" add constraint "direct_challenges_pkey" PRIMARY KEY using index "direct_challenges_pkey";

alter table "public"."leaderboard_entries" add constraint "leaderboard_entries_pkey" PRIMARY KEY using index "leaderboard_entries_pkey";

alter table "public"."match_day_participants" add constraint "match_day_participants_pkey" PRIMARY KEY using index "match_day_participants_pkey";

alter table "public"."match_days" add constraint "match_days_pkey" PRIMARY KEY using index "match_days_pkey";

alter table "public"."match_participants" add constraint "match_participants_pkey" PRIMARY KEY using index "match_participants_pkey";

alter table "public"."match_search_requests" add constraint "match_search_requests_pkey" PRIMARY KEY using index "match_search_requests_pkey";

alter table "public"."matches" add constraint "matches_pkey" PRIMARY KEY using index "matches_pkey";

alter table "public"."metric_snapshots" add constraint "metric_snapshots_pkey" PRIMARY KEY using index "metric_snapshots_pkey";

alter table "public"."notification_events" add constraint "notification_events_pkey" PRIMARY KEY using index "notification_events_pkey";

alter table "public"."profiles" add constraint "profiles_pkey" PRIMARY KEY using index "profiles_pkey";

alter table "public"."user_health_baselines" add constraint "user_health_baselines_pkey" PRIMARY KEY using index "user_health_baselines_pkey";

alter table "public"."all_time_bests" add constraint "all_time_bests_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."all_time_bests" validate constraint "all_time_bests_user_id_fkey";

alter table "public"."app_logs" add constraint "app_logs_level_check" CHECK ((level = ANY (ARRAY['debug'::text, 'info'::text, 'warning'::text, 'error'::text]))) not valid;

alter table "public"."app_logs" validate constraint "app_logs_level_check";

alter table "public"."app_logs" add constraint "app_logs_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE SET NULL not valid;

alter table "public"."app_logs" validate constraint "app_logs_user_id_fkey";

alter table "public"."direct_challenges" add constraint "direct_challenges_challenger_id_fkey" FOREIGN KEY (challenger_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."direct_challenges" validate constraint "direct_challenges_challenger_id_fkey";

alter table "public"."direct_challenges" add constraint "direct_challenges_match_id_fkey" FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE SET NULL not valid;

alter table "public"."direct_challenges" validate constraint "direct_challenges_match_id_fkey";

alter table "public"."direct_challenges" add constraint "direct_challenges_recipient_id_fkey" FOREIGN KEY (recipient_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."direct_challenges" validate constraint "direct_challenges_recipient_id_fkey";

alter table "public"."direct_challenges" add constraint "direct_challenges_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text]))) not valid;

alter table "public"."direct_challenges" validate constraint "direct_challenges_status_check";

alter table "public"."leaderboard_entries" add constraint "leaderboard_entries_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."leaderboard_entries" validate constraint "leaderboard_entries_user_id_fkey";

alter table "public"."leaderboard_entries" add constraint "leaderboard_entries_user_id_week_start_key" UNIQUE using index "leaderboard_entries_user_id_week_start_key";

alter table "public"."match_day_participants" add constraint "match_day_participants_data_status_check" CHECK ((data_status = ANY (ARRAY['pending'::text, 'confirmed'::text]))) not valid;

alter table "public"."match_day_participants" validate constraint "match_day_participants_data_status_check";

alter table "public"."match_day_participants" add constraint "match_day_participants_match_day_id_fkey" FOREIGN KEY (match_day_id) REFERENCES public.match_days(id) ON DELETE CASCADE not valid;

alter table "public"."match_day_participants" validate constraint "match_day_participants_match_day_id_fkey";

alter table "public"."match_day_participants" add constraint "match_day_participants_match_day_id_user_id_key" UNIQUE using index "match_day_participants_match_day_id_user_id_key";

alter table "public"."match_day_participants" add constraint "match_day_participants_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."match_day_participants" validate constraint "match_day_participants_user_id_fkey";

alter table "public"."match_days" add constraint "match_days_day_number_check" CHECK ((day_number >= 1)) not valid;

alter table "public"."match_days" validate constraint "match_days_day_number_check";

alter table "public"."match_days" add constraint "match_days_match_id_day_number_key" UNIQUE using index "match_days_match_id_day_number_key";

alter table "public"."match_days" add constraint "match_days_match_id_fkey" FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE not valid;

alter table "public"."match_days" validate constraint "match_days_match_id_fkey";

alter table "public"."match_days" add constraint "match_days_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'provisional'::text, 'finalized'::text]))) not valid;

alter table "public"."match_days" validate constraint "match_days_status_check";

alter table "public"."match_days" add constraint "match_days_winner_user_id_fkey" FOREIGN KEY (winner_user_id) REFERENCES public.profiles(id) ON DELETE SET NULL not valid;

alter table "public"."match_days" validate constraint "match_days_winner_user_id_fkey";

alter table "public"."match_participants" add constraint "match_participants_joined_via_check" CHECK ((joined_via = ANY (ARRAY['matchmaking'::text, 'direct_challenge'::text]))) not valid;

alter table "public"."match_participants" validate constraint "match_participants_joined_via_check";

alter table "public"."match_participants" add constraint "match_participants_match_id_fkey" FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE not valid;

alter table "public"."match_participants" validate constraint "match_participants_match_id_fkey";

alter table "public"."match_participants" add constraint "match_participants_match_id_user_id_key" UNIQUE using index "match_participants_match_id_user_id_key";

alter table "public"."match_participants" add constraint "match_participants_role_check" CHECK ((role = ANY (ARRAY['challenger'::text, 'opponent'::text]))) not valid;

alter table "public"."match_participants" validate constraint "match_participants_role_check";

alter table "public"."match_participants" add constraint "match_participants_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."match_participants" validate constraint "match_participants_user_id_fkey";

alter table "public"."match_search_requests" add constraint "fk_msq_matched_match" FOREIGN KEY (matched_match_id) REFERENCES public.matches(id) ON DELETE SET NULL not valid;

alter table "public"."match_search_requests" validate constraint "fk_msq_matched_match";

alter table "public"."match_search_requests" add constraint "match_search_requests_creator_id_fkey" FOREIGN KEY (creator_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."match_search_requests" validate constraint "match_search_requests_creator_id_fkey";

alter table "public"."match_search_requests" add constraint "match_search_requests_duration_days_check" CHECK ((duration_days = ANY (ARRAY[1, 3, 5, 7]))) not valid;

alter table "public"."match_search_requests" validate constraint "match_search_requests_duration_days_check";

alter table "public"."match_search_requests" add constraint "match_search_requests_metric_type_check" CHECK ((metric_type = ANY (ARRAY['steps'::text, 'active_calories'::text]))) not valid;

alter table "public"."match_search_requests" validate constraint "match_search_requests_metric_type_check";

alter table "public"."match_search_requests" add constraint "match_search_requests_start_mode_check" CHECK ((start_mode = ANY (ARRAY['today'::text, 'tomorrow'::text]))) not valid;

alter table "public"."match_search_requests" validate constraint "match_search_requests_start_mode_check";

alter table "public"."match_search_requests" add constraint "match_search_requests_status_check" CHECK ((status = ANY (ARRAY['searching'::text, 'matched'::text, 'cancelled'::text]))) not valid;

alter table "public"."match_search_requests" validate constraint "match_search_requests_status_check";

alter table "public"."matches" add constraint "matches_duration_days_check" CHECK ((duration_days = ANY (ARRAY[1, 3, 5, 7]))) not valid;

alter table "public"."matches" validate constraint "matches_duration_days_check";

alter table "public"."matches" add constraint "matches_match_type_check" CHECK ((match_type = ANY (ARRAY['public_matchmaking'::text, 'direct_challenge'::text]))) not valid;

alter table "public"."matches" validate constraint "matches_match_type_check";

alter table "public"."matches" add constraint "matches_metric_type_check" CHECK ((metric_type = ANY (ARRAY['steps'::text, 'active_calories'::text]))) not valid;

alter table "public"."matches" validate constraint "matches_metric_type_check";

alter table "public"."matches" add constraint "matches_start_mode_check" CHECK ((start_mode = ANY (ARRAY['today'::text, 'tomorrow'::text]))) not valid;

alter table "public"."matches" validate constraint "matches_start_mode_check";

alter table "public"."matches" add constraint "matches_state_check" CHECK ((state = ANY (ARRAY['searching'::text, 'pending'::text, 'active'::text, 'completed'::text, 'cancelled'::text]))) not valid;

alter table "public"."matches" validate constraint "matches_state_check";

alter table "public"."metric_snapshots" add constraint "metric_snapshots_match_id_fkey" FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE not valid;

alter table "public"."metric_snapshots" validate constraint "metric_snapshots_match_id_fkey";

alter table "public"."metric_snapshots" add constraint "metric_snapshots_metric_type_check" CHECK ((metric_type = ANY (ARRAY['steps'::text, 'active_calories'::text]))) not valid;

alter table "public"."metric_snapshots" validate constraint "metric_snapshots_metric_type_check";

alter table "public"."metric_snapshots" add constraint "metric_snapshots_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."metric_snapshots" validate constraint "metric_snapshots_user_id_fkey";

alter table "public"."notification_events" add constraint "notification_events_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'sent'::text, 'failed'::text]))) not valid;

alter table "public"."notification_events" validate constraint "notification_events_status_check";

alter table "public"."notification_events" add constraint "notification_events_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."notification_events" validate constraint "notification_events_user_id_fkey";

alter table "public"."profiles" add constraint "profiles_auth_user_id_key" UNIQUE using index "profiles_auth_user_id_key";

alter table "public"."user_health_baselines" add constraint "user_health_baselines_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."user_health_baselines" validate constraint "user_health_baselines_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.invoke_dispatch_notification(p_user_ids uuid[], p_event_type text, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_user_ids text[];
BEGIN
  IF p_user_ids IS NULL OR array_length(p_user_ids, 1) IS NULL THEN
    RETURN;
  END IF;

  SELECT ARRAY_AGG(value::text)
  INTO v_user_ids
  FROM unnest(p_user_ids) AS value;

  PERFORM private.invoke_edge_function(
    'dispatch-notification',
    jsonb_build_object(
      'user_ids', to_jsonb(v_user_ids),
      'event_type', p_event_type,
      'payload', COALESCE(p_payload, '{}'::jsonb)
    )
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION private.invoke_edge_function(p_function_name text, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_project_url text;
  v_service_role_key text;
BEGIN
  SELECT decrypted_secret
  INTO v_project_url
  FROM vault.decrypted_secrets
  WHERE name = 'fitup_project_url'
  LIMIT 1;

  SELECT decrypted_secret
  INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'fitup_service_role_key'
  LIMIT 1;

  IF v_project_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE EXCEPTION 'Missing vault secrets fitup_project_url or fitup_service_role_key.';
  END IF;

  PERFORM net.http_post(
    url := v_project_url || '/functions/v1/' || p_function_name,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key,
      'apikey', v_service_role_key
    ),
    body := p_payload
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION private.invoke_finalize_match_day(p_match_day_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_project_url text;
  v_service_role_key text;
BEGIN
  SELECT decrypted_secret
  INTO v_project_url
  FROM vault.decrypted_secrets
  WHERE name = 'fitup_project_url'
  LIMIT 1;

  SELECT decrypted_secret
  INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'fitup_service_role_key'
  LIMIT 1;

  IF v_project_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE EXCEPTION 'Missing vault secrets fitup_project_url or fitup_service_role_key.';
  END IF;

  PERFORM net.http_post(
    url := v_project_url || '/functions/v1/finalize-match-day',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key,
      'apikey', v_service_role_key
    ),
    body := jsonb_build_object('match_day_id', p_match_day_id::text),
    timeout_milliseconds := 60000
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION private.invoke_matchmaking_pairing(p_request_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_project_url text;
  v_service_role_key text;
BEGIN
  SELECT decrypted_secret
  INTO v_project_url
  FROM vault.decrypted_secrets
  WHERE name = 'fitup_project_url'
  LIMIT 1;

  SELECT decrypted_secret
  INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'fitup_service_role_key'
  LIMIT 1;

  IF v_project_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE EXCEPTION 'Missing vault secrets fitup_project_url or fitup_service_role_key.';
  END IF;

  PERFORM net.http_post(
    url := v_project_url || '/functions/v1/matchmaking-pairing',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key,
      'apikey', v_service_role_key
    ),
    body := jsonb_build_object('match_search_request_id', p_request_id::text)
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION private.invoke_on_all_accepted(p_match_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_project_url text;
  v_service_role_key text;
BEGIN
  SELECT decrypted_secret
  INTO v_project_url
  FROM vault.decrypted_secrets
  WHERE name = 'fitup_project_url'
  LIMIT 1;

  SELECT decrypted_secret
  INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'fitup_service_role_key'
  LIMIT 1;

  IF v_project_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE EXCEPTION 'Missing vault secrets fitup_project_url or fitup_service_role_key.';
  END IF;

  PERFORM net.http_post(
    url := v_project_url || '/functions/v1/on-all-accepted',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key,
      'apikey', v_service_role_key
    ),
    body := jsonb_build_object('match_id', p_match_id::text)
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION private.notification_sent_today(p_user_id uuid, p_event_type text, p_match_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM notification_events ne
    WHERE ne.user_id = p_user_id
      AND ne.event_type = p_event_type
      AND COALESCE(ne.payload ->> 'match_id', '') = p_match_id::text
      AND ne.created_at >= date_trunc('day', now())
  );
$function$
;

CREATE OR REPLACE FUNCTION private.resolve_leader_user(p_my_value numeric, p_other_value numeric, p_my_user_id uuid, p_other_user_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  IF COALESCE(p_my_value, 0) = COALESCE(p_other_value, 0) THEN
    RETURN NULL;
  END IF;
  IF COALESCE(p_my_value, 0) > COALESCE(p_other_value, 0) THEN
    RETURN p_my_user_id;
  END IF;
  RETURN p_other_user_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.activate_match_with_days(p_match_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_state text;
  v_duration int;
  v_starts_at timestamptz;
  v_tz text;
  v_total int;
  v_accepted int;
  v_rowcount int;
  v_base_date date;
  v_day int;
  v_match_day_id uuid;
  r_participant record;
BEGIN
  SELECT state, duration_days, starts_at, match_timezone
  INTO v_state, v_duration, v_starts_at, v_tz
  FROM matches
  WHERE id = p_match_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_state <> 'pending' THEN
    RETURN false;
  END IF;

  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE accepted_at IS NOT NULL)::int
  INTO v_total, v_accepted
  FROM match_participants
  WHERE match_id = p_match_id;

  IF v_total = 0 OR v_total <> v_accepted THEN
    RETURN false;
  END IF;

  -- Match start = 00:00 local on Day 1 in match_timezone (proper timestamptz; server-TZ independent).
  v_tz := COALESCE(NULLIF(trim(v_tz), ''), 'America/New_York');

  UPDATE matches
  SET state = 'active',
      starts_at = (((timezone(v_tz, clock_timestamp()))::date)::timestamp) AT TIME ZONE v_tz
  WHERE id = p_match_id
    AND state = 'pending';

  GET DIAGNOSTICS v_rowcount = ROW_COUNT;
  IF v_rowcount = 0 THEN
    RETURN false;
  END IF;

  SELECT starts_at, match_timezone, duration_days
  INTO v_starts_at, v_tz, v_duration
  FROM matches
  WHERE id = p_match_id;

  IF v_tz IS NULL OR length(trim(v_tz)) = 0 THEN
    v_tz := 'America/New_York';
  END IF;

  v_base_date := (timezone(v_tz, v_starts_at))::date;

  FOR v_day IN 1..v_duration LOOP
    INSERT INTO match_days (match_id, day_number, calendar_date, status)
    VALUES (p_match_id, v_day, v_base_date + (v_day - 1), 'pending')
    ON CONFLICT (match_id, day_number) DO NOTHING;

    SELECT id
    INTO v_match_day_id
    FROM match_days
    WHERE match_id = p_match_id
      AND day_number = v_day
    LIMIT 1;

    IF v_match_day_id IS NULL THEN
      CONTINUE;
    END IF;

    FOR r_participant IN
      SELECT user_id FROM match_participants WHERE match_id = p_match_id
    LOOP
      INSERT INTO match_day_participants (match_day_id, user_id, metric_total, data_status)
      VALUES (v_match_day_id, r_participant.user_id, 0, 'pending')
      ON CONFLICT (match_day_id, user_id) DO NOTHING;
    END LOOP;
  END LOOP;

  RETURN true;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_direct_challenge(p_recipient_id uuid, p_metric_type text, p_duration_days integer, p_start_mode text, p_match_timezone text, p_starts_at timestamp with time zone)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_challenger uuid;
  v_match_id uuid;
  v_challenge_id uuid;
  v_now timestamptz := now();
  v_tz text;
BEGIN
  v_challenger := (
    SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1
  );

  IF v_challenger IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  IF p_recipient_id = v_challenger THEN
    RAISE EXCEPTION 'cannot challenge self';
  END IF;

  IF p_metric_type NOT IN ('steps', 'active_calories') THEN
    RAISE EXCEPTION 'invalid metric_type';
  END IF;

  IF p_duration_days NOT IN (1, 3, 5, 7) THEN
    RAISE EXCEPTION 'invalid duration_days';
  END IF;

  IF p_start_mode NOT IN ('today', 'tomorrow') THEN
    RAISE EXCEPTION 'invalid start_mode';
  END IF;

  v_tz := COALESCE(NULLIF(trim(p_match_timezone), ''), 'America/New_York');

  INSERT INTO public.matches (
    match_type,
    metric_type,
    duration_days,
    start_mode,
    state,
    match_timezone,
    starts_at
  )
  VALUES (
    'direct_challenge',
    p_metric_type,
    p_duration_days,
    p_start_mode,
    'pending',
    v_tz,
    p_starts_at
  )
  RETURNING id INTO v_match_id;

  INSERT INTO public.match_participants (match_id, user_id, role, joined_via, accepted_at)
  VALUES
    (v_match_id, v_challenger, 'challenger', 'direct_challenge', v_now),
    (v_match_id, p_recipient_id, 'opponent', 'direct_challenge', NULL);

  INSERT INTO public.direct_challenges (challenger_id, recipient_id, match_id, status)
  VALUES (v_challenger, p_recipient_id, v_match_id, 'pending')
  RETURNING id INTO v_challenge_id;

  RETURN json_build_object(
    'match_id', v_match_id,
    'challenge_id', v_challenge_id
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.current_user_match_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT mp.match_id
  FROM match_participants mp
  WHERE mp.user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid());
$function$
;

CREATE OR REPLACE FUNCTION public.day_cutoff_check()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_match_day_id uuid;
BEGIN
  -- Phase 1: pending participants past local cutoff → confirmed (existing behavior)
  FOR v_match_day_id IN
    WITH pending_cutoff_rows AS (
      SELECT mdp.id, mdp.match_day_id
      FROM match_day_participants mdp
      JOIN match_days md
        ON md.id = mdp.match_day_id
      JOIN profiles p
        ON p.id = mdp.user_id
      WHERE md.status <> 'finalized'
        AND mdp.data_status = 'pending'
        AND timezone(COALESCE(p.timezone, 'UTC'), now())
          >= ((md.calendar_date + 1)::timestamp + time '10:00')
    ),
    force_confirmed AS (
      UPDATE match_day_participants mdp
      SET data_status = 'confirmed',
          last_updated_at = now()
      FROM pending_cutoff_rows pending
      WHERE mdp.id = pending.id
      RETURNING pending.match_day_id
    )
    SELECT DISTINCT match_day_id
    FROM force_confirmed
  LOOP
    PERFORM private.invoke_finalize_match_day(v_match_day_id);
  END LOOP;

  -- Phase 2: all participants already confirmed, day not finalized, cutoff passed for
  -- every participant — re-invoke finalize (e.g. after pg_net timeout or edge hiccup)
  FOR v_match_day_id IN
    SELECT md.id
    FROM match_days md
    WHERE md.status <> 'finalized'
      AND NOT EXISTS (
        SELECT 1
        FROM match_day_participants mdp
        WHERE mdp.match_day_id = md.id
          AND mdp.data_status <> 'confirmed'
      )
      AND EXISTS (
        SELECT 1
        FROM match_day_participants mdp
        WHERE mdp.match_day_id = md.id
      )
      AND NOT EXISTS (
        SELECT 1
        FROM match_day_participants mdp
        JOIN profiles p ON p.id = mdp.user_id
        WHERE mdp.match_day_id = md.id
          AND timezone(COALESCE(p.timezone, 'UTC'), now())
            < ((md.calendar_date + 1)::timestamp + time '10:00')
      )
  LOOP
    PERFORM private.invoke_finalize_match_day(v_match_day_id);
  END LOOP;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.decline_pending_match(p_match_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_profile_id uuid;
  v_state text;
  v_match_type text;
  v_updated int;
BEGIN
  v_profile_id := (
    SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1
  );

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT m.state, m.match_type
  INTO v_state, v_match_type
  FROM public.matches m
  WHERE m.id = p_match_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'reason', 'match_not_found');
  END IF;

  IF v_state <> 'pending' THEN
    RETURN json_build_object('ok', true, 'reason', 'already_resolved');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.match_participants mp
    WHERE mp.match_id = p_match_id
      AND mp.user_id = v_profile_id
  ) THEN
    RAISE EXCEPTION 'not a participant';
  END IF;

  IF v_match_type = 'direct_challenge' THEN
    UPDATE public.direct_challenges
    SET status = 'declined'
    WHERE match_id = p_match_id
      AND status = 'pending';
  END IF;

  PERFORM set_config('app.decline_user_id', v_profile_id::text, true);

  UPDATE public.matches
  SET state = 'cancelled'
  WHERE id = p_match_id
    AND state = 'pending';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    RETURN json_build_object('ok', true, 'reason', 'already_resolved');
  END IF;

  RETURN json_build_object('ok', true, 'reason', 'declined');
END;
$function$
;

CREATE OR REPLACE FUNCTION public.finalize_when_all_confirmed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_total_count int;
  v_confirmed_count int;
  v_day_status text;
BEGIN
  IF NEW.data_status <> 'confirmed' THEN
    RETURN NEW;
  END IF;

  SELECT status
  INTO v_day_status
  FROM match_days
  WHERE id = NEW.match_day_id
  LIMIT 1;

  IF v_day_status = 'finalized' THEN
    RETURN NEW;
  END IF;

  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE data_status = 'confirmed')::int
  INTO v_total_count, v_confirmed_count
  FROM match_day_participants
  WHERE match_day_id = NEW.match_day_id;

  IF v_total_count > 0 AND v_total_count = v_confirmed_count THEN
    PERFORM private.invoke_finalize_match_day(NEW.match_day_id);
  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.head_to_head_stats(p_opponent_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  v_viewer uuid;
  v_total int;
  v_vwins int;
  v_owins int;
  v_ties int;
BEGIN
  SELECT id
  INTO v_viewer
  FROM public.profiles
  WHERE auth_user_id = auth.uid()
  LIMIT 1;

  IF v_viewer IS NULL OR p_opponent_id IS NULL OR v_viewer = p_opponent_id THEN
    RETURN jsonb_build_object(
      'total_completed', 0,
      'viewer_wins', 0,
      'opponent_wins', 0,
      'series_ties', 0
    );
  END IF;

  WITH mutual_matches AS (
    SELECT DISTINCT m.id AS match_id
    FROM public.matches m
    INNER JOIN public.match_participants mp1
      ON mp1.match_id = m.id AND mp1.user_id = v_viewer
    INNER JOIN public.match_participants mp2
      ON mp2.match_id = m.id AND mp2.user_id = p_opponent_id
    WHERE m.state = 'completed'
  ),
  day_wins AS (
    SELECT
      md.match_id,
      md.winner_user_id
    FROM public.match_days md
    INNER JOIN mutual_matches mm ON mm.match_id = md.match_id
    WHERE md.status = 'finalized'
      AND md.is_void = false
      AND md.winner_user_id IS NOT NULL
  ),
  per_match AS (
    SELECT
      mm.match_id,
      COALESCE(
        SUM(CASE WHEN dw.winner_user_id = v_viewer THEN 1 ELSE 0 END),
        0
      )::int AS viewer_day_wins,
      COALESCE(
        SUM(CASE WHEN dw.winner_user_id = p_opponent_id THEN 1 ELSE 0 END),
        0
      )::int AS opponent_day_wins
    FROM mutual_matches mm
    LEFT JOIN day_wins dw ON dw.match_id = mm.match_id
    GROUP BY mm.match_id
  ),
  outcomes AS (
    SELECT
      CASE
        WHEN viewer_day_wins > opponent_day_wins THEN 1
        ELSE 0
      END AS win_viewer,
      CASE
        WHEN opponent_day_wins > viewer_day_wins THEN 1
        ELSE 0
      END AS win_opponent,
      CASE
        WHEN viewer_day_wins = opponent_day_wins THEN 1
        ELSE 0
      END AS tie_series
    FROM per_match
  )
  SELECT
    COALESCE(COUNT(*)::int, 0),
    COALESCE(SUM(win_viewer)::int, 0),
    COALESCE(SUM(win_opponent)::int, 0),
    COALESCE(SUM(tie_series)::int, 0)
  INTO v_total, v_vwins, v_owins, v_ties
  FROM outcomes;

  RETURN jsonb_build_object(
    'total_completed', COALESCE(v_total, 0),
    'viewer_wins', COALESCE(v_vwins, 0),
    'opponent_wins', COALESCE(v_owins, 0),
    'series_ties', COALESCE(v_ties, 0)
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.matchmaking_pair_atomic(p_request_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_incoming match_search_requests%ROWTYPE;
  v_partner match_search_requests%ROWTYPE;
  v_match_id uuid;
  v_tz text;
  v_challenger uuid;
  v_opponent uuid;
  v_rowcount int;
BEGIN
  SELECT *
  INTO v_incoming
  FROM match_search_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF v_incoming.status <> 'searching' OR v_incoming.matched_match_id IS NOT NULL THEN
    RETURN NULL;
  END IF;

  SELECT msr.*
  INTO v_partner
  FROM match_search_requests msr
  WHERE msr.status = 'searching'
    AND msr.id <> v_incoming.id
    AND msr.creator_id <> v_incoming.creator_id
    AND msr.metric_type = v_incoming.metric_type
    AND msr.duration_days = v_incoming.duration_days
    AND msr.start_mode = v_incoming.start_mode
  ORDER BY
    abs(msr.creator_baseline - v_incoming.creator_baseline) ASC NULLS LAST,
    msr.created_at ASC,
    msr.id ASC
  FOR UPDATE SKIP LOCKED
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF v_incoming.created_at < v_partner.created_at
    OR (
      v_incoming.created_at = v_partner.created_at
      AND v_incoming.id < v_partner.id
    )
  THEN
    v_challenger := v_incoming.creator_id;
    v_opponent := v_partner.creator_id;
  ELSE
    v_challenger := v_partner.creator_id;
    v_opponent := v_incoming.creator_id;
  END IF;

  SELECT COALESCE(p.timezone, 'America/New_York')
  INTO v_tz
  FROM profiles p
  WHERE p.id = v_challenger
  LIMIT 1;

  IF v_tz IS NULL OR length(trim(v_tz)) = 0 THEN
    v_tz := 'America/New_York';
  END IF;

  INSERT INTO matches (
    match_type,
    metric_type,
    duration_days,
    start_mode,
    state,
    match_timezone,
    starts_at
  )
  VALUES (
    'public_matchmaking',
    v_incoming.metric_type,
    v_incoming.duration_days,
    v_incoming.start_mode,
    'pending',
    v_tz,
    NULL
  )
  RETURNING id INTO v_match_id;

  INSERT INTO match_participants (match_id, user_id, role, joined_via, accepted_at)
  VALUES
    (v_match_id, v_challenger, 'challenger', 'matchmaking', NULL),
    (v_match_id, v_opponent, 'opponent', 'matchmaking', NULL);

  UPDATE match_search_requests
  SET status = 'matched',
      matched_match_id = v_match_id
  WHERE id IN (v_incoming.id, v_partner.id)
    AND status = 'searching';

  GET DIAGNOSTICS v_rowcount = ROW_COUNT;
  IF v_rowcount <> 2 THEN
    RAISE EXCEPTION 'matchmaking_pair_atomic: expected 2 updated search rows, got %', v_rowcount;
  END IF;

  RETURN v_match_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.matchmaking_retry_stale_searches(p_min_age_seconds integer DEFAULT 5, p_max_invocations integer DEFAULT 30)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  n int := 0;
  r record;
BEGIN
  IF p_min_age_seconds < 0 OR p_max_invocations < 1 THEN
    RAISE EXCEPTION 'matchmaking_retry_stale_searches: invalid parameters';
  END IF;

  FOR r IN
    SELECT id
    FROM match_search_requests
    WHERE status = 'searching'
      AND created_at <= now() - make_interval(secs => p_min_age_seconds)
    ORDER BY created_at ASC
    LIMIT p_max_invocations
  LOOP
    PERFORM private.invoke_matchmaking_pairing(r.id);
    n := n + 1;
  END LOOP;

  RETURN n;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_challenge_declined()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_metric_type text;
  v_decliner_name text;
BEGIN
  IF NEW.status <> 'declined' OR OLD.status = 'declined' THEN
    RETURN NEW;
  END IF;

  SELECT metric_type
  INTO v_metric_type
  FROM matches
  WHERE id = NEW.match_id
  LIMIT 1;

  SELECT COALESCE(display_name, 'Opponent')
  INTO v_decliner_name
  FROM profiles
  WHERE id = NEW.recipient_id
  LIMIT 1;

  PERFORM private.invoke_dispatch_notification(
    ARRAY[NEW.challenger_id],
    'challenge_declined',
    jsonb_build_object(
      'match_id', NEW.match_id::text,
      'metric_type', COALESCE(v_metric_type, 'steps'),
      'opponent_display_name', v_decliner_name,
      'deep_link_target', 'home'
    )
  );

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_challenge_received()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_metric_type text;
  v_challenger_name text;
BEGIN
  SELECT metric_type
  INTO v_metric_type
  FROM matches
  WHERE id = NEW.match_id
  LIMIT 1;

  SELECT COALESCE(display_name, 'Opponent')
  INTO v_challenger_name
  FROM profiles
  WHERE id = NEW.challenger_id
  LIMIT 1;

  IF private.notification_sent_today(NEW.recipient_id, 'challenge_received', NEW.match_id) THEN
    RETURN NEW;
  END IF;

  PERFORM private.invoke_dispatch_notification(
    ARRAY[NEW.recipient_id],
    'challenge_received',
    jsonb_build_object(
      'match_id', NEW.match_id::text,
      'metric_type', COALESCE(v_metric_type, 'steps'),
      'opponent_display_name', v_challenger_name,
      'deep_link_target', 'home'
    )
  );

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_lead_changed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_match_id uuid;
  v_match_state text;
  v_metric_type text;
  v_opponent_user_id uuid;
  v_opponent_total numeric;
  v_prev_leader uuid;
  v_new_leader uuid;
  v_trailing_user_id uuid;
  v_leader_name text;
  v_lead_delta int;
BEGIN
  IF COALESCE(NEW.metric_total, 0) = COALESCE(OLD.metric_total, 0) THEN
    RETURN NEW;
  END IF;

  SELECT m.id, m.state, m.metric_type
  INTO v_match_id, v_match_state, v_metric_type
  FROM match_days md
  JOIN matches m
    ON m.id = md.match_id
  WHERE md.id = NEW.match_day_id
    AND md.status <> 'finalized'
  LIMIT 1;

  IF v_match_id IS NULL OR v_match_state <> 'active' THEN
    RETURN NEW;
  END IF;

  SELECT user_id, metric_total
  INTO v_opponent_user_id, v_opponent_total
  FROM match_day_participants
  WHERE match_day_id = NEW.match_day_id
    AND user_id <> NEW.user_id
  LIMIT 1;

  IF v_opponent_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_prev_leader := private.resolve_leader_user(OLD.metric_total, v_opponent_total, NEW.user_id, v_opponent_user_id);
  v_new_leader := private.resolve_leader_user(NEW.metric_total, v_opponent_total, NEW.user_id, v_opponent_user_id);

  IF v_prev_leader IS NULL OR v_new_leader IS NULL OR v_prev_leader = v_new_leader THEN
    RETURN NEW;
  END IF;

  IF v_new_leader = NEW.user_id THEN
    v_trailing_user_id := v_opponent_user_id;
  ELSE
    v_trailing_user_id := NEW.user_id;
  END IF;

  SELECT COALESCE(display_name, 'Opponent')
  INTO v_leader_name
  FROM profiles
  WHERE id = v_new_leader
  LIMIT 1;

  v_lead_delta := ABS(COALESCE(NEW.metric_total, 0)::int - COALESCE(v_opponent_total, 0)::int);

  PERFORM private.invoke_dispatch_notification(
    ARRAY[v_trailing_user_id],
    'lead_changed',
    jsonb_build_object(
      'match_id', v_match_id::text,
      'metric_type', COALESCE(v_metric_type, 'steps'),
      'opponent_display_name', v_leader_name,
      'lead_delta', v_lead_delta,
      'deep_link_target', 'match_details'
    )
  );

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_public_matchmaking_declined()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_decliner_id uuid;
  v_other_id uuid;
  v_metric_type text;
  v_decliner_name text;
  v_setting text;
BEGIN
  -- Trigger WHEN clause already limits to pending→cancelled, public_matchmaking.
  v_setting := current_setting('app.decline_user_id', true);
  IF v_setting IS NULL OR length(trim(v_setting)) = 0 THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_decliner_id := trim(v_setting)::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN NEW;
  END;

  SELECT user_id
  INTO v_other_id
  FROM match_participants
  WHERE match_id = NEW.id
    AND user_id <> v_decliner_id
  LIMIT 1;

  IF v_other_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT metric_type
  INTO v_metric_type
  FROM matches
  WHERE id = NEW.id
  LIMIT 1;

  SELECT COALESCE(display_name, 'Opponent')
  INTO v_decliner_name
  FROM profiles
  WHERE id = v_decliner_id
  LIMIT 1;

  PERFORM private.invoke_dispatch_notification(
    ARRAY[v_other_id],
    'challenge_declined',
    jsonb_build_object(
      'match_id', NEW.id::text,
      'metric_type', COALESCE(v_metric_type, 'steps'),
      'opponent_display_name', v_decliner_name,
      'deep_link_target', 'home'
    )
  );

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.push_live_activity_updates()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_match_id uuid;
  v_metric_type text;
  v_day_number int;
  v_participant_ids uuid[];
BEGIN
  SELECT m.id, m.metric_type, md.day_number
  INTO v_match_id, v_metric_type, v_day_number
  FROM match_days md
  JOIN matches m
    ON m.id = md.match_id
  WHERE md.id = NEW.match_day_id
    AND m.state = 'active'
  LIMIT 1;

  IF v_match_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT ARRAY_AGG(user_id)
  INTO v_participant_ids
  FROM match_participants
  WHERE match_id = v_match_id;

  PERFORM private.invoke_dispatch_notification(
    v_participant_ids,
    'live_activity_update',
    jsonb_build_object(
      'match_id', v_match_id::text,
      'match_day_id', NEW.match_day_id::text,
      'metric_type', COALESCE(v_metric_type, 'steps'),
      'day_number', COALESCE(v_day_number, 1),
      'deep_link_target', 'match_details'
    )
  );

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.tr_matchmaking_pairing_after_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.status = 'searching' THEN
    PERFORM private.invoke_matchmaking_pairing(NEW.id);
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.tr_on_all_accepted_after_participant()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.accepted_at IS NOT NULL THEN
    PERFORM private.invoke_on_all_accepted(NEW.match_id);
  END IF;
  RETURN NEW;
END;
$function$
;

grant delete on table "public"."all_time_bests" to "anon";

grant insert on table "public"."all_time_bests" to "anon";

grant references on table "public"."all_time_bests" to "anon";

grant select on table "public"."all_time_bests" to "anon";

grant trigger on table "public"."all_time_bests" to "anon";

grant truncate on table "public"."all_time_bests" to "anon";

grant update on table "public"."all_time_bests" to "anon";

grant delete on table "public"."all_time_bests" to "authenticated";

grant insert on table "public"."all_time_bests" to "authenticated";

grant references on table "public"."all_time_bests" to "authenticated";

grant select on table "public"."all_time_bests" to "authenticated";

grant trigger on table "public"."all_time_bests" to "authenticated";

grant truncate on table "public"."all_time_bests" to "authenticated";

grant update on table "public"."all_time_bests" to "authenticated";

grant delete on table "public"."all_time_bests" to "service_role";

grant insert on table "public"."all_time_bests" to "service_role";

grant references on table "public"."all_time_bests" to "service_role";

grant select on table "public"."all_time_bests" to "service_role";

grant trigger on table "public"."all_time_bests" to "service_role";

grant truncate on table "public"."all_time_bests" to "service_role";

grant update on table "public"."all_time_bests" to "service_role";

grant delete on table "public"."app_logs" to "anon";

grant insert on table "public"."app_logs" to "anon";

grant references on table "public"."app_logs" to "anon";

grant select on table "public"."app_logs" to "anon";

grant trigger on table "public"."app_logs" to "anon";

grant truncate on table "public"."app_logs" to "anon";

grant update on table "public"."app_logs" to "anon";

grant delete on table "public"."app_logs" to "authenticated";

grant insert on table "public"."app_logs" to "authenticated";

grant references on table "public"."app_logs" to "authenticated";

grant select on table "public"."app_logs" to "authenticated";

grant trigger on table "public"."app_logs" to "authenticated";

grant truncate on table "public"."app_logs" to "authenticated";

grant update on table "public"."app_logs" to "authenticated";

grant delete on table "public"."app_logs" to "service_role";

grant insert on table "public"."app_logs" to "service_role";

grant references on table "public"."app_logs" to "service_role";

grant select on table "public"."app_logs" to "service_role";

grant trigger on table "public"."app_logs" to "service_role";

grant truncate on table "public"."app_logs" to "service_role";

grant update on table "public"."app_logs" to "service_role";

grant delete on table "public"."direct_challenges" to "anon";

grant insert on table "public"."direct_challenges" to "anon";

grant references on table "public"."direct_challenges" to "anon";

grant select on table "public"."direct_challenges" to "anon";

grant trigger on table "public"."direct_challenges" to "anon";

grant truncate on table "public"."direct_challenges" to "anon";

grant update on table "public"."direct_challenges" to "anon";

grant delete on table "public"."direct_challenges" to "authenticated";

grant insert on table "public"."direct_challenges" to "authenticated";

grant references on table "public"."direct_challenges" to "authenticated";

grant select on table "public"."direct_challenges" to "authenticated";

grant trigger on table "public"."direct_challenges" to "authenticated";

grant truncate on table "public"."direct_challenges" to "authenticated";

grant update on table "public"."direct_challenges" to "authenticated";

grant delete on table "public"."direct_challenges" to "service_role";

grant insert on table "public"."direct_challenges" to "service_role";

grant references on table "public"."direct_challenges" to "service_role";

grant select on table "public"."direct_challenges" to "service_role";

grant trigger on table "public"."direct_challenges" to "service_role";

grant truncate on table "public"."direct_challenges" to "service_role";

grant update on table "public"."direct_challenges" to "service_role";

grant delete on table "public"."leaderboard_entries" to "anon";

grant insert on table "public"."leaderboard_entries" to "anon";

grant references on table "public"."leaderboard_entries" to "anon";

grant select on table "public"."leaderboard_entries" to "anon";

grant trigger on table "public"."leaderboard_entries" to "anon";

grant truncate on table "public"."leaderboard_entries" to "anon";

grant update on table "public"."leaderboard_entries" to "anon";

grant delete on table "public"."leaderboard_entries" to "authenticated";

grant insert on table "public"."leaderboard_entries" to "authenticated";

grant references on table "public"."leaderboard_entries" to "authenticated";

grant select on table "public"."leaderboard_entries" to "authenticated";

grant trigger on table "public"."leaderboard_entries" to "authenticated";

grant truncate on table "public"."leaderboard_entries" to "authenticated";

grant update on table "public"."leaderboard_entries" to "authenticated";

grant delete on table "public"."leaderboard_entries" to "service_role";

grant insert on table "public"."leaderboard_entries" to "service_role";

grant references on table "public"."leaderboard_entries" to "service_role";

grant select on table "public"."leaderboard_entries" to "service_role";

grant trigger on table "public"."leaderboard_entries" to "service_role";

grant truncate on table "public"."leaderboard_entries" to "service_role";

grant update on table "public"."leaderboard_entries" to "service_role";

grant delete on table "public"."match_day_participants" to "anon";

grant insert on table "public"."match_day_participants" to "anon";

grant references on table "public"."match_day_participants" to "anon";

grant select on table "public"."match_day_participants" to "anon";

grant trigger on table "public"."match_day_participants" to "anon";

grant truncate on table "public"."match_day_participants" to "anon";

grant update on table "public"."match_day_participants" to "anon";

grant delete on table "public"."match_day_participants" to "authenticated";

grant insert on table "public"."match_day_participants" to "authenticated";

grant references on table "public"."match_day_participants" to "authenticated";

grant select on table "public"."match_day_participants" to "authenticated";

grant trigger on table "public"."match_day_participants" to "authenticated";

grant truncate on table "public"."match_day_participants" to "authenticated";

grant update on table "public"."match_day_participants" to "authenticated";

grant delete on table "public"."match_day_participants" to "service_role";

grant insert on table "public"."match_day_participants" to "service_role";

grant references on table "public"."match_day_participants" to "service_role";

grant select on table "public"."match_day_participants" to "service_role";

grant trigger on table "public"."match_day_participants" to "service_role";

grant truncate on table "public"."match_day_participants" to "service_role";

grant update on table "public"."match_day_participants" to "service_role";

grant delete on table "public"."match_days" to "anon";

grant insert on table "public"."match_days" to "anon";

grant references on table "public"."match_days" to "anon";

grant select on table "public"."match_days" to "anon";

grant trigger on table "public"."match_days" to "anon";

grant truncate on table "public"."match_days" to "anon";

grant update on table "public"."match_days" to "anon";

grant delete on table "public"."match_days" to "authenticated";

grant insert on table "public"."match_days" to "authenticated";

grant references on table "public"."match_days" to "authenticated";

grant select on table "public"."match_days" to "authenticated";

grant trigger on table "public"."match_days" to "authenticated";

grant truncate on table "public"."match_days" to "authenticated";

grant update on table "public"."match_days" to "authenticated";

grant delete on table "public"."match_days" to "service_role";

grant insert on table "public"."match_days" to "service_role";

grant references on table "public"."match_days" to "service_role";

grant select on table "public"."match_days" to "service_role";

grant trigger on table "public"."match_days" to "service_role";

grant truncate on table "public"."match_days" to "service_role";

grant update on table "public"."match_days" to "service_role";

grant delete on table "public"."match_participants" to "anon";

grant insert on table "public"."match_participants" to "anon";

grant references on table "public"."match_participants" to "anon";

grant select on table "public"."match_participants" to "anon";

grant trigger on table "public"."match_participants" to "anon";

grant truncate on table "public"."match_participants" to "anon";

grant update on table "public"."match_participants" to "anon";

grant delete on table "public"."match_participants" to "authenticated";

grant insert on table "public"."match_participants" to "authenticated";

grant references on table "public"."match_participants" to "authenticated";

grant select on table "public"."match_participants" to "authenticated";

grant trigger on table "public"."match_participants" to "authenticated";

grant truncate on table "public"."match_participants" to "authenticated";

grant update on table "public"."match_participants" to "authenticated";

grant delete on table "public"."match_participants" to "service_role";

grant insert on table "public"."match_participants" to "service_role";

grant references on table "public"."match_participants" to "service_role";

grant select on table "public"."match_participants" to "service_role";

grant trigger on table "public"."match_participants" to "service_role";

grant truncate on table "public"."match_participants" to "service_role";

grant update on table "public"."match_participants" to "service_role";

grant delete on table "public"."match_search_requests" to "anon";

grant insert on table "public"."match_search_requests" to "anon";

grant references on table "public"."match_search_requests" to "anon";

grant select on table "public"."match_search_requests" to "anon";

grant trigger on table "public"."match_search_requests" to "anon";

grant truncate on table "public"."match_search_requests" to "anon";

grant update on table "public"."match_search_requests" to "anon";

grant delete on table "public"."match_search_requests" to "authenticated";

grant insert on table "public"."match_search_requests" to "authenticated";

grant references on table "public"."match_search_requests" to "authenticated";

grant select on table "public"."match_search_requests" to "authenticated";

grant trigger on table "public"."match_search_requests" to "authenticated";

grant truncate on table "public"."match_search_requests" to "authenticated";

grant update on table "public"."match_search_requests" to "authenticated";

grant delete on table "public"."match_search_requests" to "service_role";

grant insert on table "public"."match_search_requests" to "service_role";

grant references on table "public"."match_search_requests" to "service_role";

grant select on table "public"."match_search_requests" to "service_role";

grant trigger on table "public"."match_search_requests" to "service_role";

grant truncate on table "public"."match_search_requests" to "service_role";

grant update on table "public"."match_search_requests" to "service_role";

grant delete on table "public"."matches" to "anon";

grant insert on table "public"."matches" to "anon";

grant references on table "public"."matches" to "anon";

grant select on table "public"."matches" to "anon";

grant trigger on table "public"."matches" to "anon";

grant truncate on table "public"."matches" to "anon";

grant update on table "public"."matches" to "anon";

grant delete on table "public"."matches" to "authenticated";

grant insert on table "public"."matches" to "authenticated";

grant references on table "public"."matches" to "authenticated";

grant select on table "public"."matches" to "authenticated";

grant trigger on table "public"."matches" to "authenticated";

grant truncate on table "public"."matches" to "authenticated";

grant update on table "public"."matches" to "authenticated";

grant delete on table "public"."matches" to "service_role";

grant insert on table "public"."matches" to "service_role";

grant references on table "public"."matches" to "service_role";

grant select on table "public"."matches" to "service_role";

grant trigger on table "public"."matches" to "service_role";

grant truncate on table "public"."matches" to "service_role";

grant update on table "public"."matches" to "service_role";

grant delete on table "public"."metric_snapshots" to "anon";

grant insert on table "public"."metric_snapshots" to "anon";

grant references on table "public"."metric_snapshots" to "anon";

grant select on table "public"."metric_snapshots" to "anon";

grant trigger on table "public"."metric_snapshots" to "anon";

grant truncate on table "public"."metric_snapshots" to "anon";

grant update on table "public"."metric_snapshots" to "anon";

grant delete on table "public"."metric_snapshots" to "authenticated";

grant insert on table "public"."metric_snapshots" to "authenticated";

grant references on table "public"."metric_snapshots" to "authenticated";

grant select on table "public"."metric_snapshots" to "authenticated";

grant trigger on table "public"."metric_snapshots" to "authenticated";

grant truncate on table "public"."metric_snapshots" to "authenticated";

grant update on table "public"."metric_snapshots" to "authenticated";

grant delete on table "public"."metric_snapshots" to "service_role";

grant insert on table "public"."metric_snapshots" to "service_role";

grant references on table "public"."metric_snapshots" to "service_role";

grant select on table "public"."metric_snapshots" to "service_role";

grant trigger on table "public"."metric_snapshots" to "service_role";

grant truncate on table "public"."metric_snapshots" to "service_role";

grant update on table "public"."metric_snapshots" to "service_role";

grant delete on table "public"."notification_events" to "anon";

grant insert on table "public"."notification_events" to "anon";

grant references on table "public"."notification_events" to "anon";

grant select on table "public"."notification_events" to "anon";

grant trigger on table "public"."notification_events" to "anon";

grant truncate on table "public"."notification_events" to "anon";

grant update on table "public"."notification_events" to "anon";

grant delete on table "public"."notification_events" to "authenticated";

grant insert on table "public"."notification_events" to "authenticated";

grant references on table "public"."notification_events" to "authenticated";

grant select on table "public"."notification_events" to "authenticated";

grant trigger on table "public"."notification_events" to "authenticated";

grant truncate on table "public"."notification_events" to "authenticated";

grant update on table "public"."notification_events" to "authenticated";

grant delete on table "public"."notification_events" to "service_role";

grant insert on table "public"."notification_events" to "service_role";

grant references on table "public"."notification_events" to "service_role";

grant select on table "public"."notification_events" to "service_role";

grant trigger on table "public"."notification_events" to "service_role";

grant truncate on table "public"."notification_events" to "service_role";

grant update on table "public"."notification_events" to "service_role";

grant delete on table "public"."profiles" to "anon";

grant insert on table "public"."profiles" to "anon";

grant references on table "public"."profiles" to "anon";

grant select on table "public"."profiles" to "anon";

grant trigger on table "public"."profiles" to "anon";

grant truncate on table "public"."profiles" to "anon";

grant update on table "public"."profiles" to "anon";

grant delete on table "public"."profiles" to "authenticated";

grant insert on table "public"."profiles" to "authenticated";

grant references on table "public"."profiles" to "authenticated";

grant select on table "public"."profiles" to "authenticated";

grant trigger on table "public"."profiles" to "authenticated";

grant truncate on table "public"."profiles" to "authenticated";

grant update on table "public"."profiles" to "authenticated";

grant delete on table "public"."profiles" to "service_role";

grant insert on table "public"."profiles" to "service_role";

grant references on table "public"."profiles" to "service_role";

grant select on table "public"."profiles" to "service_role";

grant trigger on table "public"."profiles" to "service_role";

grant truncate on table "public"."profiles" to "service_role";

grant update on table "public"."profiles" to "service_role";

grant delete on table "public"."user_health_baselines" to "anon";

grant insert on table "public"."user_health_baselines" to "anon";

grant references on table "public"."user_health_baselines" to "anon";

grant select on table "public"."user_health_baselines" to "anon";

grant trigger on table "public"."user_health_baselines" to "anon";

grant truncate on table "public"."user_health_baselines" to "anon";

grant update on table "public"."user_health_baselines" to "anon";

grant delete on table "public"."user_health_baselines" to "authenticated";

grant insert on table "public"."user_health_baselines" to "authenticated";

grant references on table "public"."user_health_baselines" to "authenticated";

grant select on table "public"."user_health_baselines" to "authenticated";

grant trigger on table "public"."user_health_baselines" to "authenticated";

grant truncate on table "public"."user_health_baselines" to "authenticated";

grant update on table "public"."user_health_baselines" to "authenticated";

grant delete on table "public"."user_health_baselines" to "service_role";

grant insert on table "public"."user_health_baselines" to "service_role";

grant references on table "public"."user_health_baselines" to "service_role";

grant select on table "public"."user_health_baselines" to "service_role";

grant trigger on table "public"."user_health_baselines" to "service_role";

grant truncate on table "public"."user_health_baselines" to "service_role";

grant update on table "public"."user_health_baselines" to "service_role";


  create policy "atb: public read"
  on "public"."all_time_bests"
  as permissive
  for select
  to public
using (true);



  create policy "app_logs: own insert"
  on "public"."app_logs"
  as permissive
  for insert
  to public
with check (((user_id IS NULL) OR (user_id = ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.auth_user_id = auth.uid())))));



  create policy "app_logs: own read"
  on "public"."app_logs"
  as permissive
  for select
  to public
using ((user_id = ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.auth_user_id = auth.uid()))));



  create policy "dc: own insert"
  on "public"."direct_challenges"
  as permissive
  for insert
  to public
with check ((challenger_id = ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.auth_user_id = auth.uid()))));



  create policy "dc: party read"
  on "public"."direct_challenges"
  as permissive
  for select
  to public
using (((challenger_id = ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.auth_user_id = auth.uid()))) OR (recipient_id = ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.auth_user_id = auth.uid())))));



  create policy "dc: recipient update"
  on "public"."direct_challenges"
  as permissive
  for update
  to public
using ((recipient_id = ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.auth_user_id = auth.uid()))));



  create policy "le: public read"
  on "public"."leaderboard_entries"
  as permissive
  for select
  to public
using (true);



  create policy "mdp: own update"
  on "public"."match_day_participants"
  as permissive
  for update
  to public
using ((user_id = ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.auth_user_id = auth.uid()))));



  create policy "mdp: participant read"
  on "public"."match_day_participants"
  as permissive
  for select
  to public
using ((EXISTS ( SELECT 1
   FROM public.match_days md
  WHERE ((md.id = match_day_participants.match_day_id) AND (md.match_id IN ( SELECT public.current_user_match_ids() AS current_user_match_ids))))));



  create policy "md: participant read"
  on "public"."match_days"
  as permissive
  for select
  to public
using ((match_id IN ( SELECT public.current_user_match_ids() AS current_user_match_ids)));



  create policy "mp: insert challenger direct challenge"
  on "public"."match_participants"
  as permissive
  for insert
  to public
with check (((role = 'challenger'::text) AND (joined_via = 'direct_challenge'::text) AND (user_id = ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.auth_user_id = auth.uid()))) AND (EXISTS ( SELECT 1
   FROM public.matches m
  WHERE ((m.id = match_participants.match_id) AND (m.match_type = 'direct_challenge'::text) AND (m.state = 'pending'::text))))));



  create policy "mp: insert opponent direct challenge"
  on "public"."match_participants"
  as permissive
  for insert
  to public
with check (((role = 'opponent'::text) AND (joined_via = 'direct_challenge'::text) AND (accepted_at IS NULL) AND (EXISTS ( SELECT 1
   FROM public.matches m
  WHERE ((m.id = match_participants.match_id) AND (m.match_type = 'direct_challenge'::text) AND (m.state = 'pending'::text)))) AND (EXISTS ( SELECT 1
   FROM public.match_participants mp
  WHERE ((mp.match_id = match_participants.match_id) AND (mp.user_id = ( SELECT profiles.id
           FROM public.profiles
          WHERE (profiles.auth_user_id = auth.uid()))) AND (mp.role = 'challenger'::text) AND (mp.joined_via = 'direct_challenge'::text))))));



  create policy "mp: own update"
  on "public"."match_participants"
  as permissive
  for update
  to public
using ((user_id = ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.auth_user_id = auth.uid()))));



  create policy "mp: participant read"
  on "public"."match_participants"
  as permissive
  for select
  to public
using ((match_id IN ( SELECT public.current_user_match_ids() AS current_user_match_ids)));



  create policy "msr: own insert"
  on "public"."match_search_requests"
  as permissive
  for insert
  to public
with check ((creator_id = ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.auth_user_id = auth.uid()))));



  create policy "msr: own read"
  on "public"."match_search_requests"
  as permissive
  for select
  to public
using ((creator_id = ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.auth_user_id = auth.uid()))));



  create policy "msr: own update"
  on "public"."match_search_requests"
  as permissive
  for update
  to public
using ((creator_id = ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.auth_user_id = auth.uid()))));



  create policy "matches: insert direct challenge"
  on "public"."matches"
  as permissive
  for insert
  to public
with check (((match_type = 'direct_challenge'::text) AND (state = 'pending'::text) AND (auth.uid() IS NOT NULL)));



  create policy "matches: participant read"
  on "public"."matches"
  as permissive
  for select
  to public
using ((id IN ( SELECT public.current_user_match_ids() AS current_user_match_ids)));



  create policy "ms: own insert"
  on "public"."metric_snapshots"
  as permissive
  for insert
  to public
with check ((user_id = ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.auth_user_id = auth.uid()))));



  create policy "ms: participant read"
  on "public"."metric_snapshots"
  as permissive
  for select
  to public
using ((match_id IN ( SELECT public.current_user_match_ids() AS current_user_match_ids)));



  create policy "profiles: own insert"
  on "public"."profiles"
  as permissive
  for insert
  to public
with check ((auth.uid() = auth_user_id));



  create policy "profiles: own read"
  on "public"."profiles"
  as permissive
  for select
  to public
using ((auth.uid() = auth_user_id));



  create policy "profiles: own update"
  on "public"."profiles"
  as permissive
  for update
  to public
using ((auth.uid() = auth_user_id));



  create policy "profiles: read others"
  on "public"."profiles"
  as permissive
  for select
  to public
using (true);



  create policy "uhb: own read"
  on "public"."user_health_baselines"
  as permissive
  for select
  to public
using ((user_id = ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.auth_user_id = auth.uid()))));



  create policy "uhb: own update"
  on "public"."user_health_baselines"
  as permissive
  for update
  to public
using ((user_id = ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.auth_user_id = auth.uid()))));



  create policy "uhb: own upsert"
  on "public"."user_health_baselines"
  as permissive
  for insert
  to public
with check ((user_id = ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.auth_user_id = auth.uid()))));


CREATE TRIGGER tr_notify_challenge_declined AFTER UPDATE OF status ON public.direct_challenges FOR EACH ROW EXECUTE FUNCTION public.notify_challenge_declined();

CREATE TRIGGER tr_notify_challenge_received AFTER INSERT ON public.direct_challenges FOR EACH ROW EXECUTE FUNCTION public.notify_challenge_received();

CREATE TRIGGER tr_finalize_when_all_confirmed AFTER INSERT OR UPDATE OF data_status ON public.match_day_participants FOR EACH ROW EXECUTE FUNCTION public.finalize_when_all_confirmed();

CREATE TRIGGER tr_notify_lead_changed AFTER UPDATE OF metric_total ON public.match_day_participants FOR EACH ROW EXECUTE FUNCTION public.notify_lead_changed();

CREATE TRIGGER tr_push_live_activity_updates AFTER INSERT OR UPDATE OF metric_total ON public.match_day_participants FOR EACH ROW EXECUTE FUNCTION public.push_live_activity_updates();

CREATE TRIGGER tr_on_all_accepted_after_participant AFTER INSERT OR UPDATE OF accepted_at ON public.match_participants FOR EACH ROW EXECUTE FUNCTION public.tr_on_all_accepted_after_participant();

CREATE TRIGGER tr_matchmaking_pairing_after_insert AFTER INSERT ON public.match_search_requests FOR EACH ROW EXECUTE FUNCTION public.tr_matchmaking_pairing_after_insert();

CREATE TRIGGER tr_notify_public_matchmaking_declined AFTER UPDATE OF state ON public.matches FOR EACH ROW WHEN (((old.state = 'pending'::text) AND (new.state = 'cancelled'::text) AND (new.match_type = 'public_matchmaking'::text))) EXECUTE FUNCTION public.notify_public_matchmaking_declined();


