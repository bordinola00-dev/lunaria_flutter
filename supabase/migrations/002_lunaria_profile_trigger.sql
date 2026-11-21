create or replace function public.handle_new_lunaria_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, name, interests)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', ''), '{}'::text[])
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_lunaria on auth.users;
create trigger on_auth_user_created_lunaria
  after insert on auth.users
  for each row execute procedure public.handle_new_lunaria_user();

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles',
    'mood_entries',
    'diary_entries',
    'beauty_products',
    'beauty_looks',
    'playlists',
    'songs'
  ]
  loop
    execute format(
      'drop trigger if exists set_updated_at on public.%I',
      table_name
    );
    execute format(
      'create trigger set_updated_at before update on public.%I
       for each row execute procedure public.set_updated_at()',
      table_name
    );
  end loop;
end;
$$;
