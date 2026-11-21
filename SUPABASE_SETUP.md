# Supabase setup

## Migration inventory

This Flutter repository contains these SQL migrations:

1. `supabase/migrations/002_lunaria_profile_trigger.sql`
2. `supabase/migrations/003_home_daily_data.sql`
3. `supabase/migrations/004_mindspace_tables_and_rls.sql`
4. `supabase/migrations/005_beautyroom_catalog_and_storage.sql`
5. `supabase/migrations/006_melodyroom_spotify_favorites.sql`
6. `supabase/migrations/007_melodyroom_library_and_my_space.sql`

The base migration `001_lunaria_mvp.sql` is not present in this repository.
Earlier setup instructions referenced a sibling checkout; that path is not
available when this repository is cloned by itself. The SQL files here are
therefore not sufficient to provision a new Supabase project from an empty
database.

Do not reconstruct or substitute the missing migration. Recover the exact
`001_lunaria_mvp.sql` from the project's authorized source of truth, review it,
and include it in the migration history before attempting a fresh installation.
Once recovered, apply the migrations in numerical order, including 002 through
007. Do not apply 002 through 007 alone to an empty database.

## Existing Supabase environment

The current Lunaria Supabase environment has already had migration 007 applied
and its tables, `songs` columns, private `lunaria-private` bucket, and Realtime
publication were verified by the project owner. Do not run migration 007 again
against that environment. This confirmation applies only to the current
environment; it does not make a fresh installation possible without migration
001.

## Flutter configuration

Flutter reads the Supabase URL and public client key with
`String.fromEnvironment`; it does not load `.env` automatically. Supply the
values when running or building:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://gtzzvklqnmndqfzgbmpd.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-publishable-key
```

For an Android device, find its ID with `flutter devices`, then use:

```bash
flutter run -d DEVICE_ID \
  --dart-define=SUPABASE_URL=https://gtzzvklqnmndqfzgbmpd.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-publishable-key
```

To build and install separately, use `flutter build apk --debug` with the same
two `--dart-define` values, then `flutter install -d DEVICE_ID`.

Use only the public publishable/anon client key in the Flutter app. Never put a
`service_role` key in `--dart-define`, source code, assets, or a distributed
build. The local `.env` file is ignored by Git; `.env.example` contains
placeholders and is not loaded by Flutter.

When Supabase values are absent, Lunaria can use its local SharedPreferences
mode. Cloud-backed features require a configured Supabase project and an
authenticated user.

Lunaria validates `SUPABASE_URL` against the official project URL above and
passes that exact base URL to the single shared Supabase client. `.env` is not
loaded by Flutter; the URL also defaults to the official value when no
`SUPABASE_URL` dart-define is supplied.

## Email confirmation delivery

Email sign-up requires confirmation in the current project. Supabase's default
email sender is limited to pre-authorized team addresses and has strict
rate-limits; it is not intended for public production delivery. To send
verification emails to app users, configure a custom SMTP provider in the
Supabase Dashboard under **Authentication → SMTP Settings**. Keep email
confirmation enabled, then test sign-up and the app's **Reenviar correo de
verificación** action. Do not put SMTP credentials in the Flutter app or Git.
