Supabase workflow reminder:

- I run SQL manually in Supabase SQL Editor.
- Do not run SQL, apply migrations, deploy functions, alter secrets, or change cron automatically.
- If SQL is needed, create a clearly named file in `supabase/manual_sql/` and tell me whether I must run it.
- If Edge Functions change, do not deploy; give me exact deploy commands from repo root.
- If both SQL and Edge Functions change, tell me the correct order.
- If no SQL or deploy is needed, explicitly say so in the final response.