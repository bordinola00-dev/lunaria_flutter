alter table public.mood_entries
  add column if not exists entry_date date;

create unique index if not exists mood_entries_user_entry_date_uidx
  on public.mood_entries (user_id, entry_date)
  where entry_date is not null;

create or replace function public.set_daily_mood(
  p_mood text,
  p_note text,
  p_entry_date date
)
returns public.mood_entries
language plpgsql
security invoker
set search_path = public
as $$
declare
  saved_entry public.mood_entries;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if length(btrim(p_mood)) = 0 or length(p_mood) > 40 then
    raise exception 'Invalid mood';
  end if;

  if length(coalesce(p_note, '')) > 1000 then
    raise exception 'Mood note is too long';
  end if;

  insert into public.mood_entries (
    user_id,
    mood,
    note,
    entry_date
  )
  values (
    auth.uid(),
    btrim(p_mood),
    coalesce(p_note, ''),
    p_entry_date
  )
  on conflict (user_id, entry_date)
    where entry_date is not null
  do update set
    mood = excluded.mood,
    note = excluded.note,
    updated_at = now()
  returning * into saved_entry;

  return saved_entry;
end;
$$;

revoke all on function public.set_daily_mood(text, text, date) from public;
revoke all on function public.set_daily_mood(text, text, date) from anon;
grant execute on function public.set_daily_mood(text, text, date) to authenticated;

create table if not exists public.daily_routines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(btrim(title)) between 1 and 100),
  description text not null default '' check (length(description) <= 500),
  routine_date date not null,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists daily_routines_user_date_idx
  on public.daily_routines (user_id, routine_date desc, created_at desc);

alter table public.daily_routines enable row level security;

drop policy if exists "Users manage their daily routines"
  on public.daily_routines;
create policy "Users manage their daily routines"
  on public.daily_routines
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_updated_at on public.daily_routines;
create trigger set_updated_at
  before update on public.daily_routines
  for each row execute procedure public.set_updated_at();
