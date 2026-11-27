Quiero que trabajes sobre este proyecto, llamado **Lunaria**, una aplicación desarrollada con Flutter y Dart.

Mi objetivo es preparar una versión **nativa para iOS (iPhone)**. Por ahora, quiero trabajar exclusivamente en la adaptación para iOS.

### Objetivo principal
Analiza todo el proyecto y adapta su código, configuración y dependencias para que Lunaria pueda ejecutarse correctamente en un iPhone como aplicación nativa.

### Instrucciones

1. Analiza la arquitectura completa del proyecto antes de modificar cualquier archivo.
2. Identifica las dependencias, paquetes y funcionalidades que no sean compatibles con iOS.
3. Adapta los archivos de configuración de iOS, incluyendo `Info.plist`, permisos, identificadores y configuraciones necesarias.
4. Comprueba la compatibilidad de todas las funcionalidades actuales.
5. Conserva el diseño visual, las animaciones, la navegación y la experiencia original de Lunaria.
6. Mantén funcionando los servicios externos y las integraciones existentes, como Supabase, autenticación, almacenamiento y cualquier otra que utilice el proyecto.
7. Revisa los permisos necesarios para cámara, galería, almacenamiento, enlaces externos y demás funcionalidades.
8. Configura correctamente los identificadores de la aplicación, los esquemas de URL y las integraciones que correspondan.
9. No elimines funcionalidades simplemente porque presenten incompatibilidades: busca alternativas compatibles con iOS.
10. No modifiques ni rompas la versión Android. Mantén los cambios específicos de iOS separados siempre que sea posible.

### Restricciones importantes

- No quiero una PWA ni una página web.
- No quiero convertir Lunaria en una aplicación diferente.
- Quiero conservar Flutter y Dart.
- No quiero publicar la aplicación en App Store.
- Mi objetivo es instalarla de manera privada en un iPhone sin pagar una suscripción de Apple Developer.
- Trabajo desde Linux y no tengo una Mac.

### Estrategia de compilación e instalación

Investiga y prepara una estrategia viable para compilar remotamente el proyecto iOS utilizando servicios que tengan un plan gratuito.

Evalúa las alternativas para generar un archivo IPA y posteriormente instalarlo de forma privada en un iPhone mediante firma gratuita de Apple, explicando las limitaciones de renovación de certificados y perfiles.

No supongas que todo es gratuito: identifica cualquier requisito, limitación o coste antes de recomendar una solución.

### Forma de trabajo

- Primero realiza una auditoría completa.
- Después presenta los problemas encontrados y un plan de adaptación.
- Luego implementa los cambios necesarios.
- No inventes resultados de compilación ni afirmes que funciona en iPhone si no se ha probado.
- Si necesitas macOS, Xcode, certificados, credenciales o alguna intervención manual, indícalo claramente.
- No expongas ni modifiques secretos, claves privadas o credenciales del proyecto.

### Resultado esperado

Quiero que Lunaria quede preparada para compilarse como una aplicación nativa de iOS, conservando todas sus funcionalidades originales, y que me entregues un informe con los cambios realizados, los pasos pendientes y la estrategia más económica para instalarla en el iPhone.# Supabase setup

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
