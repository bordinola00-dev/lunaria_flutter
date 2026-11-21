begin;

alter table public.songs
  add column if not exists spotify_track_id text,
  add column if not exists reflection text not null default '';

alter table public.songs
  alter column title drop not null,
  alter column artist drop not null,
  alter column url drop not null;

create unique index if not exists songs_user_spotify_track_uidx
  on public.songs (user_id, spotify_track_id)
  where spotify_track_id is not null;

alter table public.songs enable row level security;

revoke all on table public.songs from anon, public;
grant usage on schema public to authenticated;
grant select, insert, update, delete on table public.songs to authenticated;

drop policy if exists "Users manage their songs" on public.songs;
create policy "Users manage their songs"
  on public.songs for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "MelodyRoom owner restriction on songs"
  on public.songs;
create policy "MelodyRoom owner restriction on songs"
  on public.songs as restrictive for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

notify pgrst, 'reload schema';

commit;
