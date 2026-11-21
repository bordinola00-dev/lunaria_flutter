
begin;

-- ==========================================
-- 1. FUNCION PARA ACTUALIZAR updated_at
-- ==========================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ==========================================
-- 2. TABLA DE EMOCIONES
-- ==========================================

create table if not exists public.mood_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mood text not null,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ==========================================
-- 3. TABLA DEL DIARIO
-- ==========================================

create table if not exists public.diary_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ==========================================
-- 4. INDICES
-- ==========================================

create index if not exists mood_entries_user_created_idx
on public.mood_entries (user_id, created_at desc);

create index if not exists diary_entries_user_created_idx
on public.diary_entries (user_id, created_at desc);

-- ==========================================
-- 5. ACTIVAR RLS
-- ==========================================

alter table public.mood_entries enable row level security;
alter table public.diary_entries enable row level security;

revoke all on table public.mood_entries, public.diary_entries
from anon, public;

grant usage on schema public to authenticated;

grant select, insert, update, delete
on table public.mood_entries, public.diary_entries
to authenticated;

-- ==========================================
-- 6. POLITICAS DE EMOCIONES
-- ==========================================

drop policy if exists "Users manage their moods"
on public.mood_entries;

create policy "Users manage their moods"
on public.mood_entries
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "MindSpace owner restriction on moods"
on public.mood_entries;

create policy "MindSpace owner restriction on moods"
on public.mood_entries
as restrictive
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- ==========================================
-- 7. POLITICAS DEL DIARIO
-- ==========================================

drop policy if exists "Users manage their diary"
on public.diary_entries;

create policy "Users manage their diary"
on public.diary_entries
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "MindSpace owner restriction on diary"
on public.diary_entries;

create policy "MindSpace owner restriction on diary"
on public.diary_entries
as restrictive
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- ==========================================
-- 8. TRIGGERS
-- ==========================================

drop trigger if exists set_updated_at
on public.mood_entries;

create trigger set_updated_at
before update on public.mood_entries
for each row
execute function public.set_updated_at();

drop trigger if exists set_updated_at
on public.diary_entries;

create trigger set_updated_at
before update on public.diary_entries
for each row
execute function public.set_updated_at();

-- ==========================================
-- 9. RECARGAR ESQUEMA API
-- ==========================================

notify pgrst, 'reload schema';

commit;
