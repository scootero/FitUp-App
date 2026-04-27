-- Explicit friendships: pending requests and accepted pairs.
-- Rows use canonical (a_id, b_id) with a_id < b_id for a stable primary key.

create table "public"."friendships" (
  "a_id" uuid not null,
  "b_id" uuid not null,
  "status" text not null,
  "requested_by" uuid not null,
  "created_at" timestamp with time zone not null default now(),
  "accepted_at" timestamp with time zone,
  constraint "friendships_pkey" primary key ("a_id", "b_id"),
  constraint "friendships_order_check" check (("a_id" < "b_id")),
  constraint "friendships_status_check" check (("status" = any (array['pending'::text, 'accepted'::text]))),
  constraint "friendships_requested_by_check" check (("requested_by" = "a_id" or "requested_by" = "b_id")),
  constraint "friendships_a_id_fkey" foreign key ("a_id") references "public"."profiles" ("id") on delete cascade,
  constraint "friendships_b_id_fkey" foreign key ("b_id") references "public"."profiles" ("id") on delete cascade,
  constraint "friendships_requested_by_fkey" foreign key ("requested_by") references "public"."profiles" ("id") on delete cascade
);

create index "friendships_status_idx" on "public"."friendships" using btree ("status");
create index "friendships_requested_by_idx" on "public"."friendships" using btree ("requested_by");

alter table "public"."friendships" enable row level security;

-- SELECT: only the two people in the row can read it.
create policy "friendships: party select"
  on "public"."friendships"
  as permissive
  for select
  to public
  using ((
    "a_id" = (select "id" from "public"."profiles" where "auth_user_id" = auth.uid() limit 1)
    or "b_id" = (select "id" from "public"."profiles" where "auth_user_id" = auth.uid() limit 1)
  ));

-- INSERT: only pending, requester is current user, requester is one of the pair.
create policy "friendships: requester insert pending"
  on "public"."friendships"
  as permissive
  for insert
  to public
  with check ((
    "status" = 'pending'
    and "accepted_at" is null
    and "requested_by" = (select "id" from "public"."profiles" where "auth_user_id" = auth.uid() limit 1)
    and (
      "a_id" = (select "id" from "public"."profiles" where "auth_user_id" = auth.uid() limit 1)
      or "b_id" = (select "id" from "public"."profiles" where "auth_user_id" = auth.uid() limit 1)
    )
  ));

-- UPDATE: only the non-requester can accept a pending request.
create policy "friendships: accept pending"
  on "public"."friendships"
  as permissive
  for update
  to public
  using ((
    "status" = 'pending'
    and "requested_by" <> (select "id" from "public"."profiles" where "auth_user_id" = auth.uid() limit 1)
    and (
      "a_id" = (select "id" from "public"."profiles" where "auth_user_id" = auth.uid() limit 1)
      or "b_id" = (select "id" from "public"."profiles" where "auth_user_id" = auth.uid() limit 1)
    )
  ))
  with check ((
    "status" = 'accepted'
    and "accepted_at" is not null
  ));

-- DELETE: either party (cancel pending, unfriend, decline by deleting).
create policy "friendships: party delete"
  on "public"."friendships"
  as permissive
  for delete
  to public
  using ((
    "a_id" = (select "id" from "public"."profiles" where "auth_user_id" = auth.uid() limit 1)
    or "b_id" = (select "id" from "public"."profiles" where "auth_user_id" = auth.uid() limit 1)
  ));

grant delete on table "public"."friendships" to "anon";
grant insert on table "public"."friendships" to "anon";
grant references on table "public"."friendships" to "anon";
grant select on table "public"."friendships" to "anon";
grant trigger on table "public"."friendships" to "anon";
grant truncate on table "public"."friendships" to "anon";
grant update on table "public"."friendships" to "anon";

grant delete on table "public"."friendships" to "authenticated";
grant insert on table "public"."friendships" to "authenticated";
grant references on table "public"."friendships" to "authenticated";
grant select on table "public"."friendships" to "authenticated";
grant trigger on table "public"."friendships" to "authenticated";
grant truncate on table "public"."friendships" to "authenticated";
grant update on table "public"."friendships" to "authenticated";

grant delete on table "public"."friendships" to "service_role";
grant insert on table "public"."friendships" to "service_role";
grant references on table "public"."friendships" to "service_role";
grant select on table "public"."friendships" to "service_role";
grant trigger on table "public"."friendships" to "service_role";
grant truncate on table "public"."friendships" to "service_role";
grant update on table "public"."friendships" to "service_role";
