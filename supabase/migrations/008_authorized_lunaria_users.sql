begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.lunaria_authorized_users (
  slot smallint primary key check (slot in (1, 2)),
  user_id uuid not null unique references auth.users(id) on delete cascade
);

alter table private.lunaria_authorized_users enable row level security;
revoke all on table private.lunaria_authorized_users
  from public, anon, authenticated;

create or replace function public.is_lunaria_user_authorized()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from private.lunaria_authorized_users allowed
      where allowed.user_id = auth.uid()
    );
$$;

revoke all on function public.is_lunaria_user_authorized()
  from public, anon;
grant execute on function public.is_lunaria_user_authorized()
  to authenticated;

create or replace function private.assert_lunaria_user_authorized()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_lunaria_user_authorized() then
    raise exception 'This account is not authorized to use Lunaria'
      using errcode = '42501';
  end if;
end;
$$;

revoke all on function private.assert_lunaria_user_authorized()
  from public, anon, authenticated;

create or replace function public.is_lunaria_space_member(p_space_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_lunaria_user_authorized()
    and exists (
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
set search_path = ''
as $$
  select public.is_lunaria_user_authorized()
    and exists (
      select 1
      from public.lunaria_space_members m
      join public.lunaria_spaces s on s.id = m.space_id
      where m.space_id = p_space_id
        and m.user_id = auth.uid()
        and s.state = 'active'
    );
$$;

create or replace function public.is_lunaria_space_member_text(
  p_space_id text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_lunaria_user_authorized()
    or p_space_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
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
set search_path = ''
as $$
begin
  if not public.is_lunaria_user_authorized()
    or p_space_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
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
set search_path = ''
as $$
  select public.is_lunaria_user_authorized()
    and left(p_topic, 8) = 'my-luna:'
    and public.is_active_lunaria_space_member_text(substr(p_topic, 9));
$$;

create or replace function public.can_read_lunaria_profile(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_lunaria_user_authorized()
    and (
      p_user_id = auth.uid()
      or exists (
        select 1
        from public.lunaria_space_members mine
        join public.lunaria_space_members theirs
          on theirs.space_id = mine.space_id
        join public.lunaria_spaces s on s.id = mine.space_id
        where mine.user_id = auth.uid()
          and theirs.user_id = p_user_id
          and s.state = 'active'
      )
    );
$$;

alter table public.profiles enable row level security;
alter table public.mood_entries enable row level security;
alter table public.diary_entries enable row level security;
alter table public.daily_routines enable row level security;
alter table public.beauty_products enable row level security;
alter table public.beauty_looks enable row level security;
alter table public.songs enable row level security;
alter table public.playlists enable row level security;
alter table public.playlist_songs enable row level security;
alter table public.lunaria_spaces enable row level security;
alter table public.lunaria_space_members enable row level security;
alter table public.lunaria_space_invitations enable row level security;
alter table public.lunaria_space_messages enable row level security;
alter table public.lunaria_space_message_reads enable row level security;

revoke all on table
  public.profiles,
  public.mood_entries,
  public.diary_entries,
  public.daily_routines,
  public.beauty_products,
  public.beauty_looks,
  public.songs,
  public.playlists,
  public.playlist_songs,
  public.lunaria_spaces,
  public.lunaria_space_members,
  public.lunaria_space_invitations,
  public.lunaria_space_messages,
  public.lunaria_space_message_reads
from anon, public;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles',
    'mood_entries',
    'diary_entries',
    'daily_routines',
    'beauty_products',
    'beauty_looks',
    'songs',
    'playlists',
    'playlist_songs',
    'lunaria_spaces',
    'lunaria_space_members',
    'lunaria_space_invitations',
    'lunaria_space_messages',
    'lunaria_space_message_reads'
  ]
  loop
    execute format(
      'drop policy if exists %I on public.%I',
      'Lunaria authorized accounts only',
      table_name
    );
    execute format(
      'create policy %I on public.%I as restrictive for all to authenticated
       using (public.is_lunaria_user_authorized())
       with check (public.is_lunaria_user_authorized())',
      'Lunaria authorized accounts only',
      table_name
    );
  end loop;
end;
$$;

drop policy if exists "Lunaria authorized accounts only"
  on storage.objects;
update storage.buckets
set public = false
where id in ('beautyroom-images', 'lunaria-private');

create policy "Lunaria authorized accounts only"
  on storage.objects as restrictive for all to authenticated
  using (public.is_lunaria_user_authorized())
  with check (public.is_lunaria_user_authorized());

drop policy if exists "Lunaria authorized accounts only"
  on realtime.messages;
create policy "Lunaria authorized accounts only"
  on realtime.messages as restrictive for all to authenticated
  using (public.is_lunaria_user_authorized())
  with check (public.is_lunaria_user_authorized());

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
  perform private.assert_lunaria_user_authorized();

  if caller_id is null then
    raise exception 'Authentication required';
  end if;
  if p_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid invitation';
  end if;
  if exists (
    select 1 from public.lunaria_space_members where user_id = caller_id
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
  perform private.assert_lunaria_user_authorized();

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
  perform private.assert_lunaria_user_authorized();

  if caller_id is null then
    raise exception 'Authentication required';
  end if;
  if p_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'This invitation is invalid or expired';
  end if;
  if exists (
    select 1 from public.lunaria_space_members where user_id = caller_id
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
  perform private.assert_lunaria_user_authorized();

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
  perform private.assert_lunaria_user_authorized();

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
  perform private.assert_lunaria_user_authorized();

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
  perform private.assert_lunaria_user_authorized();

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
  on conflict (message_id, user_id) do nothing;
end;
$$;

notify pgrst, 'reload schema';

commit;
