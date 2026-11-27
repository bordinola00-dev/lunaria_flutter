# Lunaria

Flutter/Dart implementation of Lunaria. Android remains native; the iPhone
experience on this branch is a Safari-installable Progressive Web App (PWA).

## Run

```bash
cd lunaria_flutter
flutter pub get
flutter run
```

## Supabase configuration

Supabase configuration is centralized and loaded at startup. Lunaria reads the
official project URL and public anon/publishable key from the bundled `.env`
asset when present, with `--dart-define` values available as a fallback. Use
only the public client key; never add a `service_role` key or any secret to the
Flutter app.

Release builds require valid Supabase configuration and will show a clear
configuration error instead of starting in local mode.

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

## Android

```bash
flutter devices
flutter run
flutter build apk --release
```

## iPhone PWA

The existing native iOS project is retained. For the iPhone PWA build and
Cloudflare Pages deployment, see [PWA_DEPLOYMENT.md](PWA_DEPLOYMENT.md).

## Native iOS target

The native iOS project remains in `ios/`; it is not the iPhone distribution
path targeted by this branch. See [IOS_BUILD.md](IOS_BUILD.md) for its
previously prepared remote build and private signing notes.
