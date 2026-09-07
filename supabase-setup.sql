-- STARCARE Étudiant — shared visit/click counters
-- Run this once in the Supabase dashboard: SQL Editor > New query > paste > Run

create table if not exists public.starcare_counters (
  key text primary key,
  count bigint not null default 0
);

insert into public.starcare_counters (key, count) values
  ('views', 0),
  ('clicks', 0)
on conflict (key) do nothing;

alter table public.starcare_counters enable row level security;

-- anyone can read the counts (needed so the admin panel can display them)
drop policy if exists "public read counters" on public.starcare_counters;
create policy "public read counters" on public.starcare_counters
  for select using (true);

-- increment function: runs with elevated privileges so it can update the
-- table even though direct writes are blocked by RLS for the public/anon role
create or replace function public.increment_counter(counter_key text)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  new_count bigint;
begin
  update public.starcare_counters
    set count = count + 1
    where key = counter_key
    returning count into new_count;

  if new_count is null then
    insert into public.starcare_counters(key, count) values (counter_key, 1)
    returning count into new_count;
  end if;

  return new_count;
end;
$$;

grant select on public.starcare_counters to anon;
grant execute on function public.increment_counter(text) to anon;

-- enable realtime push so the admin panel updates instantly on every visit/click
alter publication supabase_realtime add table public.starcare_counters;
