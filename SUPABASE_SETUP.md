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

Lunaria loads Supabase configuration centrally at app startup from the bundled
`.env` asset when it is present, and falls back to compile-time
`--dart-define` values when `.env` does not provide them. All modules use the
same shared Supabase client.

Create or update `.env` in `lunaria_flutter/` with the public client values:

```env
SUPABASE_URL=https://gtzzvklqnmndqfzgbmpd.supabase.co
SUPABASE_ANON_KEY=your-public-publishable-key
```

`SUPABASE_URL` must be exactly the official Lunaria project URL above. Use only
the public publishable/anon key that is compatible with the installed
`supabase_flutter` client. Never put a `service_role` key, secret key, or any
administrative credential in `.env`, `--dart-define`, source code, assets, or a
distributed build.

### Local development

```bash
flutter pub get
flutter run
```

`flutter run` and release builds include the project assets configured in
`pubspec.yaml`, so the `.env` asset is available to the app when present.

### Release builds

Release builds require a valid Supabase configuration. If the configuration is
missing or invalid, Lunaria shows a clear configuration error instead of
starting in local mode.

If you need to provide values at build time instead of the bundled `.env`, pass
the same `--dart-define` values to the release command:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://gtzzvklqnmndqfzgbmpd.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-publishable-key
```

For an Android device, you can run directly with:

```bash
flutter run -d DEVICE_ID --release \
  --dart-define=SUPABASE_URL=https://gtzzvklqnmndqfzgbmpd.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-publishable-key
```

### Notes

- `.env` is ignored by Git; `.env.example` is a placeholder template and must
  not contain real credentials.
- Because `.env` can be bundled for app startup, it must contain only the public
  Supabase client key, never secrets.
- In development builds, Lunaria may offer an explicit local mode when Supabase
  is unavailable, but this mode is not used silently in release builds.
- Cloud-backed features require valid Supabase configuration and an
  authenticated user.

## Email confirmation delivery

Email sign-up requires confirmation in the current project. Supabase's default
email sender is limited to pre-authorized team addresses and has strict
rate-limits; it is not intended for public production delivery. To send
verification emails to app users, configure a custom SMTP provider in the
Supabase Dashboard under **Authentication → SMTP Settings**. Keep email
confirmation enabled, then test sign-up and the app's **Reenviar correo de
verificación** action. Do not put SMTP credentials in the Flutter app or Git.
