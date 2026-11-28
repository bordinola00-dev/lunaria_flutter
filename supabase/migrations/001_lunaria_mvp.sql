create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  interests text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.mood_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mood text not null,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.diary_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.beauty_products (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  brand text not null default '',
  category text not null default '',
  shade text not null default '',
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.beauty_looks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  description text not null default '',
  products text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.playlists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  url text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.songs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  artist text not null default '',
  url text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists mood_entries_user_created_idx on public.mood_entries(user_id, created_at desc);
create index if not exists diary_entries_user_created_idx on public.diary_entries(user_id, created_at desc);
create index if not exists beauty_products_user_created_idx on public.beauty_products(user_id, created_at desc);
create index if not exists beauty_looks_user_created_idx on public.beauty_looks(user_id, created_at desc);
create index if not exists playlists_user_created_idx on public.playlists(user_id, created_at desc);
create index if not exists songs_user_created_idx on public.songs(user_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.mood_entries enable row level security;
alter table public.diary_entries enable row level security;
alter table public.beauty_products enable row level security;
alter table public.beauty_looks enable row level security;
alter table public.playlists enable row level security;
alter table public.songs enable row level security;

create policy "Users manage their profile" on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

create policy "Users manage their moods" on public.mood_entries
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users manage their diary" on public.diary_entries
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users manage their beauty products" on public.beauty_products
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users manage their beauty looks" on public.beauty_looks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users manage their playlists" on public.playlists
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users manage their songs" on public.songs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
