
begin;

-- =========================================================
-- 1. MELODYROOM: CANCIONES Y PLAYLISTS
-- =========================================================

alter table public.songs
  add column if not exists spotify_track_id text,
  add column if not exists reflection text not null default '',
  add column if not exists cover_url text,
  add column if not exists is_favorite boolean not null default false,
  add column if not exists library_source text not null default 'legacy';

alter table public.songs
  alter column title drop not null,
  alter column artist drop not null,
  alter column url drop not null;

create table if not exists public.playlists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  url text not null default '',
  description text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.playlists
  add column if not exists description text not null default '';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'songs_library_source_check'
      and conrelid = 'public.songs'::regclass
  ) then
    alter table public.songs add constraint songs_library_source_check
      check (library_source in ('legacy', 'manual', 'spotify')) not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'songs_cover_url_check'
      and conrelid = 'public.songs'::regclass
  ) then
    alter table public.songs add constraint songs_cover_url_check
      check (cover_url is null or cover_url ~* '^https?://[^[:space:]]+$')
      not valid;
  end if;
end;
$$;

alter table public.songs
  drop constraint if exists songs_manual_fields_check;

alter table public.songs
  add constraint songs_manual_fields_check
  check (
    library_source = 'legacy'
    or (
      library_source = 'manual'
      and length(btrim(coalesce(title, ''))) between 1 and 150
      and length(btrim(coalesce(artist, ''))) between 1 and 120
      and url is not null
      and url ~* '^https://open[.]spotify[.]com/(intl-[a-z]{2}/)?track/[A-Za-z0-9]{22}([?][^[:space:]]*)?$'
      and spotify_track_id is not null
      and spotify_track_id ~ '^[A-Za-z0-9]{22}$'
    )
    or (
      library_source = 'spotify'
      and spotify_track_id is not null
      and spotify_track_id ~ '^[A-Za-z0-9]{22}$'
    )
  ) not valid;

-- Las canciones existentes con ID de Spotify se clasifican
-- como Spotify, pero NO se marcan como favoritas.
update public.songs
set library_source = 'spotify'
where spotify_track_id is not null
  and spotify_track_id ~ '^[A-Za-z0-9]{22}$'
  and library_source = 'legacy';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'playlists_description_length_check'
      and conrelid = 'public.playlists'::regclass
  ) then
    alter table public.playlists
      add constraint playlists_description_length_check
      check (length(description) <= 500) not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'playlists_name_length_check'
      and conrelid = 'public.playlists'::regclass
  ) then
    alter table public.playlists
      add constraint playlists_name_length_check
      check (length(btrim(name)) between 1 and 100) not valid;
  end if;
end;
$$;

create unique index if not exists songs_id_user_unique
  on public.songs (id, user_id);

create unique index if not exists playlists_id_user_unique
  on public.playlists (id, user_id);

create unique index if not exists songs_user_spotify_track_uidx
  on public.songs (user_id, spotify_track_id)
  where spotify_track_id is not null;

create index if not exists songs_user_created_idx
  on public.songs (user_id, created_at desc);

create index if not exists playlists_user_created_idx
  on public.playlists (user_id, created_at desc);

create table if not exists public.playlist_songs (
  playlist_id uuid not null,
  song_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (playlist_id, song_id),
  foreign key (playlist_id, user_id)
    references public.playlists(id, user_id) on delete cascade,
  foreign key (song_id, user_id)
    references public.songs(id, user_id) on delete cascade
);

create index if not exists playlist_songs_user_playlist_idx
  on public.playlist_songs (user_id, playlist_id);

alter table public.playlist_songs enable row level security;

revoke all on table public.playlist_songs from anon, public;

grant select, insert, delete
  on table public.playlist_songs to authenticated;

drop policy if exists "MelodyRoom users manage their playlist songs"
  on public.playlist_songs;

create policy "MelodyRoom users manage their playlist songs"
  on public.playlist_songs for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "MelodyRoom restrict playlist song ownership"
  on public.playlist_songs;

create policy "MelodyRoom restrict playlist song ownership"
  on public.playlist_songs as restrictive for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);


-- =========================================================
-- 2. PERFILES
-- =========================================================

alter table public.profiles
  add column if not exists bio text not null default '',
  add column if not exists avatar_path text;

alter table public.profiles enable row level security;

revoke all on table public.profiles from anon, public;

grant select, insert, update
  on table public.profiles to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_bio_length_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_bio_length_check
        check (length(bio) <= 500)
        not valid;
  end if;
end;
$$;


-- =========================================================
-- 3. MY LUNA: TABLAS
-- =========================================================

create table if not exists public.lunaria_spaces (
  id uuid primary key default gen_random_uuid(),
  state text not null default 'active'
    check (state in ('active', 'deleting')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.lunaria_space_members (
  space_id uuid not null references public.lunaria_spaces(id) on delete cascade,
  user_id uuid not null unique references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (space_id, user_id)
);

create index if not exists lunaria_space_members_space_idx
  on public.lunaria_space_members (space_id, joined_at);

create table if not exists public.lunaria_space_invitations (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.lunaria_spaces(id) on delete cascade,
  token_hash text not null unique
    check (token_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days'),
  consumed_at timestamptz,
  consumed_by uuid references auth.users(id) on delete set null,
  revoked_at timestamptz
);

create unique index if not exists lunaria_one_open_invite_per_space_uidx
  on public.lunaria_space_invitations (space_id)
  where consumed_at is null and revoked_at is null;

create table if not exists public.lunaria_space_messages (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.lunaria_spaces(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  message_type text not null default 'text'
    check (message_type in ('text', 'image', 'audio')),
  body text not null default '',
  media_path text,
  created_at timestamptz not null default now(),
  constraint lunaria_message_payload_check check (
    (message_type = 'text' and media_path is null
      and length(btrim(body)) between 1 and 4000)
    or
    (message_type in ('image', 'audio') and media_path is not null
      and length(body) <= 1000)
  ),
  constraint lunaria_message_media_path_check check (
    media_path is null
    or media_path like space_id::text || '/chat/' || sender_id::text || '/%'
  ),
  unique (id, space_id)
);

create index if not exists lunaria_space_messages_history_idx
  on public.lunaria_space_messages (space_id, created_at desc);

create table if not exists public.lunaria_space_message_reads (
  message_id uuid not null,
  space_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (message_id, user_id),
  foreign key (message_id, space_id)
    references public.lunaria_space_messages(id, space_id) on delete cascade
);

create index if not exists lunaria_space_message_reads_space_idx
  on public.lunaria_space_message_reads (space_id, read_at desc);


-- =========================================================
-- 4. FUNCIONES AUXILIARES DE MY LUNA
-- =========================================================

create or replace function public.is_lunaria_space_member(p_space_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.lunaria_space_members m
    where m.space_id = p_space_id
      and m.user_id = auth.uid()
  );
$$;

create or replace function public.is_active_lunaria_space_member(
  p_space_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.lunaria_space_members m
    join public.lunaria_spaces s on s.id = m.space_id
    where m.space_id = p_space_id
      and m.user_id = auth.uid()
      and s.state = 'active'
  );
$$;

create or replace function public.is_lunaria_space_member_text(p_space_id text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if p_space_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  return public.is_lunaria_space_member(p_space_id::uuid);
end;
$$;

create or replace function public.is_active_lunaria_space_member_text(
  p_space_id text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if p_space_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  return public.is_active_lunaria_space_member(p_space_id::uuid);
end;
$$;

create or replace function public.is_active_lunaria_space_topic(p_topic text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select left(p_topic, 8) = 'my-luna:'
    and public.is_active_lunaria_space_member_text(substr(p_topic, 9));
$$;

create or replace function public.can_read_lunaria_profile(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p_user_id = auth.uid()
    or exists (
      select 1
      from public.lunaria_space_members mine
      join public.lunaria_space_members theirs
        on theirs.space_id = mine.space_id
      join public.lunaria_spaces s on s.id = mine.space_id
      where mine.user_id = auth.uid()
        and theirs.user_id = p_user_id
        and s.state = 'active'
    );
$$;

revoke all on function public.is_lunaria_space_member(uuid) from public, anon;
revoke all on function public.is_active_lunaria_space_member(uuid) from public, anon;
revoke all on function public.is_lunaria_space_member_text(text) from public, anon;
revoke all on function public.is_active_lunaria_space_member_text(text) from public, anon;
revoke all on function public.is_active_lunaria_space_topic(text) from public, anon;
revoke all on function public.can_read_lunaria_profile(uuid) from public, anon;

grant execute on function public.is_lunaria_space_member(uuid) to authenticated;
grant execute on function public.is_active_lunaria_space_member(uuid) to authenticated;
grant execute on function public.is_lunaria_space_member_text(text) to authenticated;
grant execute on function public.is_active_lunaria_space_member_text(text) to authenticated;
grant execute on function public.is_active_lunaria_space_topic(text) to authenticated;
grant execute on function public.can_read_lunaria_profile(uuid) to authenticated;


-- =========================================================
-- 5. FUNCIONES RPC DE MY LUNA
-- =========================================================

create or replace function public.create_lunaria_space(p_token_hash text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  caller_id uuid := auth.uid();
  new_space_id uuid;
begin
  if caller_id is null then
    raise exception 'Authentication required';
  end if;

  if p_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid invitation';
  end if;

  if exists (
    select 1 from public.lunaria_space_members
    where user_id = caller_id
  ) then
    raise exception 'This account already belongs to a Mi Luna space';
  end if;

  insert into public.lunaria_spaces default values
  returning id into new_space_id;

  insert into public.lunaria_space_members (space_id, user_id)
  values (new_space_id, caller_id);

  insert into public.lunaria_space_invitations (
    space_id, token_hash, created_by
  ) values (new_space_id, lower(p_token_hash), caller_id);

  return new_space_id;
end;
$$;

create or replace function public.create_lunaria_space_invitation(
  p_space_id uuid,
  p_token_hash text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null
    or not public.is_active_lunaria_space_member(p_space_id) then
    raise exception 'You are not an active participant in this space';
  end if;

  if p_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid invitation';
  end if;

  perform 1 from public.lunaria_spaces
  where id = p_space_id and state = 'active'
  for update;

  if not found then
    raise exception 'This space is no longer active';
  end if;

  if (
    select count(*) from public.lunaria_space_members
    where space_id = p_space_id
  ) >= 2 then
    raise exception 'This space already has two participants';
  end if;

  update public.lunaria_space_invitations
  set revoked_at = now()
  where space_id = p_space_id
    and consumed_at is null
    and revoked_at is null;

  insert into public.lunaria_space_invitations (
    space_id, token_hash, created_by
  ) values (p_space_id, lower(p_token_hash), auth.uid());
end;
$$;

create or replace function public.accept_lunaria_space_invitation(
  p_token_hash text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  caller_id uuid := auth.uid();
  invite public.lunaria_space_invitations;
  member_count integer;
begin
  if caller_id is null then
    raise exception 'Authentication required';
  end if;

  if p_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'This invitation is invalid or expired';
  end if;

  if exists (
    select 1 from public.lunaria_space_members
    where user_id = caller_id
  ) then
    raise exception 'This account already belongs to a Mi Luna space';
  end if;

  select * into invite
  from public.lunaria_space_invitations
  where token_hash = lower(p_token_hash)
    and consumed_at is null
    and revoked_at is null
    and expires_at > now()
  for update;

  if not found then
    raise exception 'This invitation is invalid, expired, or already used';
  end if;

  perform 1 from public.lunaria_spaces
  where id = invite.space_id and state = 'active'
  for update;

  if not found then
    raise exception 'This space is no longer active';
  end if;

  select count(*) into member_count
  from public.lunaria_space_members
  where space_id = invite.space_id;

  if member_count >= 2 or invite.created_by = caller_id then
    raise exception 'This invitation cannot be used by this account';
  end if;

  insert into public.lunaria_space_members (space_id, user_id)
  values (invite.space_id, caller_id);

  update public.lunaria_space_invitations
  set consumed_at = now(), consumed_by = caller_id
  where id = invite.id;

  return invite.space_id;
end;
$$;

create or replace function public.revoke_lunaria_space_invitations(
  p_space_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null
    or not public.is_active_lunaria_space_member(p_space_id) then
    raise exception 'You are not an active participant in this space';
  end if;

  update public.lunaria_space_invitations
  set revoked_at = now()
  where space_id = p_space_id
    and consumed_at is null
    and revoked_at is null;
end;
$$;

create or replace function public.begin_lunaria_space_deletion(
  p_space_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  media_paths text[];
begin
  if auth.uid() is null
    or not public.is_lunaria_space_member(p_space_id) then
    raise exception 'You are not a participant in this space';
  end if;

  update public.lunaria_spaces
  set state = 'deleting', updated_at = now()
  where id = p_space_id;

  if not found then
    raise exception 'This space no longer exists';
  end if;

  update public.lunaria_space_invitations
  set revoked_at = now()
  where space_id = p_space_id
    and consumed_at is null
    and revoked_at is null;

  select coalesce(array_agg(media_path), array[]::text[])
  into media_paths
  from public.lunaria_space_messages
  where space_id = p_space_id and media_path is not null;

  return jsonb_build_object('media_paths', media_paths);
end;
$$;

create or replace function public.finish_lunaria_space_deletion(
  p_space_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null
    or not public.is_lunaria_space_member(p_space_id) then
    raise exception 'You are not a participant in this space';
  end if;

  if not exists (
    select 1 from public.lunaria_spaces
    where id = p_space_id and state = 'deleting'
  ) then
    raise exception 'Space deletion was not started';
  end if;

  if exists (
    select 1 from storage.objects
    where bucket_id = 'lunaria-private'
      and name like p_space_id::text || '/chat/%'
  ) then
    raise exception 'Some private media could not be removed; retry cleanup';
  end if;

  delete from public.lunaria_spaces where id = p_space_id;
end;
$$;

create or replace function public.mark_lunaria_space_messages_read(
  p_space_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null
    or not public.is_active_lunaria_space_member(p_space_id) then
    raise exception 'You are not an active participant in this space';
  end if;

  insert into public.lunaria_space_message_reads (
    message_id, space_id, user_id, read_at
  )
  select m.id, m.space_id, auth.uid(), now()
  from public.lunaria_space_messages m
  where m.space_id = p_space_id
    and m.sender_id <> auth.uid()
  on conflict (message_id, user_id)
  do nothing;
end;
$$;

revoke all on function public.create_lunaria_space(text) from public, anon;
revoke all on function public.create_lunaria_space_invitation(uuid, text) from public, anon;
revoke all on function public.accept_lunaria_space_invitation(text) from public, anon;
revoke all on function public.revoke_lunaria_space_invitations(uuid) from public, anon;
revoke all on function public.begin_lunaria_space_deletion(uuid) from public, anon;
revoke all on function public.finish_lunaria_space_deletion(uuid) from public, anon;
revoke all on function public.mark_lunaria_space_messages_read(uuid) from public, anon;

grant execute on function public.create_lunaria_space(text) to authenticated;
grant execute on function public.create_lunaria_space_invitation(uuid, text) to authenticated;
grant execute on function public.accept_lunaria_space_invitation(text) to authenticated;
grant execute on function public.revoke_lunaria_space_invitations(uuid) to authenticated;
grant execute on function public.begin_lunaria_space_deletion(uuid) to authenticated;
grant execute on function public.finish_lunaria_space_deletion(uuid) to authenticated;
grant execute on function public.mark_lunaria_space_messages_read(uuid) to authenticated;


-- =========================================================
-- 6. RLS Y PERMISOS DE MY LUNA
-- =========================================================

alter table public.lunaria_spaces enable row level security;
alter table public.lunaria_space_members enable row level security;
alter table public.lunaria_space_invitations enable row level security;
alter table public.lunaria_space_messages enable row level security;
alter table public.lunaria_space_message_reads enable row level security;

revoke all on table public.lunaria_spaces,
  public.lunaria_space_members,
  public.lunaria_space_invitations,
  public.lunaria_space_messages,
  public.lunaria_space_message_reads
from anon, public;

grant select on table public.lunaria_spaces,
  public.lunaria_space_members,
  public.lunaria_space_messages,
  public.lunaria_space_message_reads
to authenticated;

grant insert on table public.lunaria_space_messages to authenticated;

grant insert, update on table public.lunaria_space_message_reads
to authenticated;

drop policy if exists "My Luna participants read their spaces"
  on public.lunaria_spaces;

create policy "My Luna participants read their spaces"
  on public.lunaria_spaces for select to authenticated
  using (public.is_lunaria_space_member(id));

drop policy if exists "My Luna participants read membership"
  on public.lunaria_space_members;

create policy "My Luna participants read membership"
  on public.lunaria_space_members for select to authenticated
  using (public.is_lunaria_space_member(space_id));

drop policy if exists "My Luna participants read shared profiles"
  on public.profiles;

create policy "My Luna participants read shared profiles"
  on public.profiles for select to authenticated
  using (public.can_read_lunaria_profile(id));

drop policy if exists "My Luna restrict profile visibility"
  on public.profiles;

create policy "My Luna restrict profile visibility"
  on public.profiles as restrictive for select to authenticated
  using (public.can_read_lunaria_profile(id));


-- =========================================================
-- 7. POLÍTICAS DE CANCIONES, PLAYLISTS Y PERFILES
-- =========================================================

alter table public.songs enable row level security;
alter table public.playlists enable row level security;

revoke all on table public.songs, public.playlists from anon, public;

grant usage on schema public to authenticated;

grant select, insert, update, delete
  on table public.songs, public.playlists
  to authenticated;

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

drop policy if exists "Users manage their playlists" on public.playlists;

create policy "Users manage their playlists"
  on public.playlists for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "MelodyRoom restrict playlist ownership"
  on public.playlists;

create policy "MelodyRoom restrict playlist ownership"
  on public.playlists as restrictive for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users manage their profile"
  on public.profiles;

create policy "Users manage their profile"
  on public.profiles for all to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);


-- =========================================================
-- 8. POLÍTICAS DE MENSAJES Y LECTURAS
-- =========================================================

drop policy if exists "My Luna participants read active messages"
  on public.lunaria_space_messages;

create policy "My Luna participants read active messages"
  on public.lunaria_space_messages for select to authenticated
  using (public.is_active_lunaria_space_member(space_id));

drop policy if exists "My Luna participants send their own messages"
  on public.lunaria_space_messages;

create policy "My Luna participants send their own messages"
  on public.lunaria_space_messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_active_lunaria_space_member(space_id)
  );

drop policy if exists "My Luna participants read receipts"
  on public.lunaria_space_message_reads;

create policy "My Luna participants read receipts"
  on public.lunaria_space_message_reads for select to authenticated
  using (public.is_active_lunaria_space_member(space_id));

drop policy if exists "My Luna users create their own read receipts"
  on public.lunaria_space_message_reads;

create policy "My Luna users create their own read receipts"
  on public.lunaria_space_message_reads for insert to authenticated
  with check (
    user_id = auth.uid()
    and public.is_active_lunaria_space_member(space_id)
  );

drop policy if exists "My Luna users update their own read receipts"
  on public.lunaria_space_message_reads;

create policy "My Luna users update their own read receipts"
  on public.lunaria_space_message_reads for update to authenticated
  using (
    user_id = auth.uid()
    and public.is_active_lunaria_space_member(space_id)
  )
  with check (
    user_id = auth.uid()
    and public.is_active_lunaria_space_member(space_id)
  );


-- =========================================================
-- 9. STORAGE PRIVADO
-- =========================================================

drop policy if exists "My Space participants upload private media"
  on storage.objects;

create policy "My Space participants upload private media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'lunaria-private'
    and (
      (
        (storage.foldername(name))[1] = auth.uid()::text
        and (storage.foldername(name))[2] = 'profile'
      )
      or (
        (storage.foldername(name))[2] = 'chat'
        and (storage.foldername(name))[3] = auth.uid()::text
        and public.is_active_lunaria_space_member_text(
          (storage.foldername(name))[1]
        )
      )
    )
  );

drop policy if exists "My Space participants read private media"
  on storage.objects;

create policy "My Space participants read private media"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'lunaria-private'
    and (
      (
        (storage.foldername(name))[1] = auth.uid()::text
        and (storage.foldername(name))[2] = 'profile'
      )
      or (
        (storage.foldername(name))[2] = 'profile'
        and public.can_read_lunaria_profile(
          case
            when (storage.foldername(name))[1]
              ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            then (storage.foldername(name))[1]::uuid
            else null
          end
        )
      )
      or (
        (storage.foldername(name))[2] = 'chat'
        and public.is_active_lunaria_space_member_text(
          (storage.foldername(name))[1]
        )
      )
    )
  );

drop policy if exists "My Space participants delete private media"
  on storage.objects;

create policy "My Space participants delete private media"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'lunaria-private'
    and (
      (
        (storage.foldername(name))[1] = auth.uid()::text
        and (storage.foldername(name))[2] = 'profile'
      )
      or (
        (storage.foldername(name))[2] = 'chat'
        and public.is_lunaria_space_member_text(
          (storage.foldername(name))[1]
        )
      )
    )
  );


-- =========================================================
-- 10. REALTIME: POLÍTICAS
-- =========================================================
-- IMPORTANTE:
-- No ejecutar ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY.
-- Supabase administra esa tabla y esta migración no debe intentar
-- cambiar su configuración de RLS.

drop policy if exists "My Luna participants access their private realtime channel"
  on realtime.messages;

create policy "My Luna participants access their private realtime channel"
  on realtime.messages for select to authenticated
  using (
    public.is_active_lunaria_space_topic(realtime.topic())
  );

drop policy if exists "My Luna participants publish presence"
  on realtime.messages;

create policy "My Luna participants publish presence"
  on realtime.messages for insert to authenticated
  with check (
    extension = 'presence'
    and public.is_active_lunaria_space_topic(realtime.topic())
  );


-- =========================================================
-- 11. BUCKET PRIVADO
-- =========================================================

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'lunaria-private',
  'lunaria-private',
  false,
  12582912,
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/heic',
    'audio/aac', 'audio/mp4', 'audio/mpeg', 'audio/ogg',
    'audio/wav', 'audio/webm'
  ]
)
on conflict (id) do update set
  public = false,
  file_size_limit = 12582912,
  allowed_mime_types = array[
    'image/jpeg', 'image/png', 'image/webp', 'image/heic',
    'audio/aac', 'audio/mp4', 'audio/mpeg', 'audio/ogg',
    'audio/wav', 'audio/webm'
  ];


-- =========================================================
-- 12. TRIGGERS updated_at
-- =========================================================

drop trigger if exists set_updated_at on public.lunaria_spaces;

create trigger set_updated_at
  before update on public.lunaria_spaces
  for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at on public.songs;

create trigger set_updated_at
  before update on public.songs
  for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at on public.playlists;

create trigger set_updated_at
  before update on public.playlists
  for each row execute function public.set_updated_at();


-- =========================================================
-- 13. PUBLICACIÓN REALTIME
-- =========================================================

do $$
begin
  if exists (
    select 1 from pg_publication
    where pubname = 'supabase_realtime'
  ) then

    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'lunaria_space_messages'
    ) then
      alter publication supabase_realtime
        add table public.lunaria_space_messages;
    end if;

    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'lunaria_space_message_reads'
    ) then
      alter publication supabase_realtime
        add table public.lunaria_space_message_reads;
    end if;

  end if;
end;
$$;

notify pgrst, 'reload schema';

commit;
