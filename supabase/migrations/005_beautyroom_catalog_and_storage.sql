begin;

alter table public.beauty_products
  add column if not exists product_url text,
  add column if not exists image_url text,
  add column if not exists image_path text;

alter table public.beauty_looks
  add column if not exists image_url text,
  add column if not exists image_path text;

alter table public.beauty_products enable row level security;
alter table public.beauty_looks enable row level security;

revoke all on table public.beauty_products, public.beauty_looks from anon, public;
grant usage on schema public to authenticated;
grant select, insert, update, delete
  on table public.beauty_products, public.beauty_looks to authenticated;

drop policy if exists "Users manage their beauty products"
  on public.beauty_products;
create policy "Users manage their beauty products"
  on public.beauty_products for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users manage their beauty looks"
  on public.beauty_looks;
create policy "Users manage their beauty looks"
  on public.beauty_looks for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "BeautyRoom owner restriction on products"
  on public.beauty_products;
create policy "BeautyRoom owner restriction on products"
  on public.beauty_products as restrictive for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "BeautyRoom owner restriction on looks"
  on public.beauty_looks;
create policy "BeautyRoom owner restriction on looks"
  on public.beauty_looks as restrictive for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.remove_beauty_product_from_looks()
returns trigger
language plpgsql
as $$
begin
  update public.beauty_looks
  set products = array_remove(products, old.id::text)
  where user_id = old.user_id
    and products @> array[old.id::text];
  return old;
end;
$$;

drop trigger if exists remove_deleted_beauty_product_from_looks
  on public.beauty_products;
create trigger remove_deleted_beauty_product_from_looks
  after delete on public.beauty_products
  for each row execute function public.remove_beauty_product_from_looks();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'beautyroom-images',
  'beautyroom-images',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update set
  public = false,
  file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/heic'];

drop policy if exists "BeautyRoom users read their own images" on storage.objects;
create policy "BeautyRoom users read their own images"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'beautyroom-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "BeautyRoom users upload their own images" on storage.objects;
create policy "BeautyRoom users upload their own images"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'beautyroom-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "BeautyRoom users update their own images" on storage.objects;
create policy "BeautyRoom users update their own images"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'beautyroom-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'beautyroom-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "BeautyRoom users delete their own images" on storage.objects;
create policy "BeautyRoom users delete their own images"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'beautyroom-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "BeautyRoom restrict image reads to owner"
  on storage.objects;
create policy "BeautyRoom restrict image reads to owner"
  on storage.objects as restrictive for select to authenticated
  using (
    bucket_id <> 'beautyroom-images'
    or (
      bucket_id = 'beautyroom-images'
      and (storage.foldername(name))[1] = (select auth.uid())::text
    )
  );

drop policy if exists "BeautyRoom restrict image uploads to owner"
  on storage.objects;
create policy "BeautyRoom restrict image uploads to owner"
  on storage.objects as restrictive for insert to authenticated
  with check (
    bucket_id <> 'beautyroom-images'
    or (
      bucket_id = 'beautyroom-images'
      and (storage.foldername(name))[1] = (select auth.uid())::text
    )
  );

drop policy if exists "BeautyRoom restrict image updates to owner"
  on storage.objects;
create policy "BeautyRoom restrict image updates to owner"
  on storage.objects as restrictive for update to authenticated
  using (
    bucket_id <> 'beautyroom-images'
    or (
      bucket_id = 'beautyroom-images'
      and (storage.foldername(name))[1] = (select auth.uid())::text
    )
  )
  with check (
    bucket_id <> 'beautyroom-images'
    or (
      bucket_id = 'beautyroom-images'
      and (storage.foldername(name))[1] = (select auth.uid())::text
    )
  );

drop policy if exists "BeautyRoom restrict image deletes to owner"
  on storage.objects;
create policy "BeautyRoom restrict image deletes to owner"
  on storage.objects as restrictive for delete to authenticated
  using (
    bucket_id <> 'beautyroom-images'
    or (
      bucket_id = 'beautyroom-images'
      and (storage.foldername(name))[1] = (select auth.uid())::text
    )
  );

notify pgrst, 'reload schema';

commit;
