# Lunaria Flutter

Native Android and iOS reconstruction of Lunaria.

## Run

```bash
cd lunaria_flutter
flutter pub get
flutter run
```

The app runs in local SharedPreferences mode without Supabase values.

## Optional Supabase

Read [SUPABASE_SETUP.md](SUPABASE_SETUP.md) before configuring Supabase. This
repository is missing the base migration `001_lunaria_mvp.sql`, so its included
migrations cannot provision a new Supabase project from an empty database.
Migration 007 has already been applied to the current Lunaria environment; do
not run it there again.

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://gtzzvklqnmndqfzgbmpd.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-publishable-key
```

Never add a Supabase service-role key to the Flutter client.

## Android

```bash
flutter devices
flutter run
flutter build apk --debug
```
