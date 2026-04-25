-- Public “today” activity for each user: readable by all authenticated users for the challenge rival strip;
-- each user may only insert/update their own row.

create table "public"."user_public_daily_activity" (
  "user_id" uuid not null,
  "active_date" date not null,
  "steps" integer,
  "active_calories" integer,
  "updated_at" timestamptz not null default now(),
  constraint "user_public_daily_activity_pkey" primary key ("user_id"),
  constraint "user_public_daily_activity_user_id_fkey" foreign key ("user_id") references "public"."profiles" ("id") on delete cascade
);

create index "user_public_daily_activity_active_date_idx" on "public"."user_public_daily_activity" using btree ("active_date" desc);

alter table "public"."user_public_daily_activity" enable row level security;

-- Match leaderboard / profiles read patterns: public read for the strip.
create policy "upda: public read"
  on "public"."user_public_daily_activity"
  as permissive
  for select
  to public
  using (true);

create policy "upda: own insert"
  on "public"."user_public_daily_activity"
  as permissive
  for insert
  to public
  with check ((
    "user_id" = (select "id" from "public"."profiles" where "auth_user_id" = auth.uid() limit 1)
  ));

create policy "upda: own update"
  on "public"."user_public_daily_activity"
  as permissive
  for update
  to public
  using ((
    "user_id" = (select "id" from "public"."profiles" where "auth_user_id" = auth.uid() limit 1)
  ))
  with check ((
    "user_id" = (select "id" from "public"."profiles" where "auth_user_id" = auth.uid() limit 1)
  ));

grant delete on table "public"."user_public_daily_activity" to "anon";
grant insert on table "public"."user_public_daily_activity" to "anon";
grant references on table "public"."user_public_daily_activity" to "anon";
grant select on table "public"."user_public_daily_activity" to "anon";
grant trigger on table "public"."user_public_daily_activity" to "anon";
grant truncate on table "public"."user_public_daily_activity" to "anon";
grant update on table "public"."user_public_daily_activity" to "anon";

grant delete on table "public"."user_public_daily_activity" to "authenticated";
grant insert on table "public"."user_public_daily_activity" to "authenticated";
grant references on table "public"."user_public_daily_activity" to "authenticated";
grant select on table "public"."user_public_daily_activity" to "authenticated";
grant trigger on table "public"."user_public_daily_activity" to "authenticated";
grant truncate on table "public"."user_public_daily_activity" to "authenticated";
grant update on table "public"."user_public_daily_activity" to "authenticated";

grant delete on table "public"."user_public_daily_activity" to "service_role";
grant insert on table "public"."user_public_daily_activity" to "service_role";
grant references on table "public"."user_public_daily_activity" to "service_role";
grant select on table "public"."user_public_daily_activity" to "service_role";
grant trigger on table "public"."user_public_daily_activity" to "service_role";
grant truncate on table "public"."user_public_daily_activity" to "service_role";
grant update on table "public"."user_public_daily_activity" to "service_role";
