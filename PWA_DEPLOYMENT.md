# Despliegue de Lunaria PWA en GitHub Pages

Lunaria conserva Flutter/Dart, Android y el proyecto iOS. Esta guía prepara la
versión web como un destino adicional en:

`https://bordinola00-dev.github.io/lunaria_flutter/`

GitHub Pages sirve archivos estáticos públicamente; no protege la web completa
con una contraseña en el plan gratuito. La autenticación y el acceso a los
datos privados dependen de Supabase Auth y RLS. No se debe publicar la app con
la migración de autorización pendiente.

## Coste y límites

- GitHub Pages está disponible gratuitamente para repositorios públicos. El
  sitio publicado es público y la URL no es un secreto.
- Los runners estándar de GitHub Actions son gratuitos para repositorios
  públicos. En repositorios privados, el uso puede consumir minutos incluidos
  y generar cargos al superar el cupo del plan.
- La app usa el dominio `github.io`; no hace falta comprar un dominio.
- GitHub Pages no ejecuta un backend ni oculta el JavaScript, el ID de cliente
  de Spotify o la clave pública de Supabase.

Consulta los [límites de GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits)
y la [facturación de Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
antes de cambiar la visibilidad del repositorio o el uso del runner.

## Variables de GitHub Actions

En **Settings → Secrets and variables → Actions → Variables**, configura:

| Variable | Valor/uso |
| --- | --- |
| `SUPABASE_URL` | `https://gtzzvklqnmndqfzgbmpd.supabase.co` |
| `SUPABASE_ANON_KEY` | Clave pública anon/publishable del proyecto |
| `SPOTIFY_CLIENT_ID` | Client ID público de Spotify |
| `SPOTIFY_REDIRECT_URI` | `https://bordinola00-dev.github.io/lunaria_flutter/auth.html` |

Son valores de cliente: se incorporan al JavaScript y pueden inspeccionarse.
No pongas aquí una Supabase `service_role`/`sb_secret`, un Spotify Client
Secret, credenciales SMTP ni claves privadas. El workflow no imprime los
valores y el build falla si falta alguno o no coincide el callback.

El `.env` local está ignorado por Git. El script de build crea un `.env`
temporal solo cuando Flutter lo necesita, elimina el asset de la salida y
falla si encuentra cualquier `.env*` restante en `build/web`.

## Preparar el repositorio y desplegar

1. Confirma que el repositorio sea público si quieres evitar cargos de Actions
   y disponer de GitHub Pages en el plan gratuito.
2. En **Settings → Pages**, establece **Build and deployment → Source: GitHub
   Actions**.
3. Configura las cuatro variables anteriores en Actions.
4. La migración base recuperada está versionada en
   `supabase/migrations/001_lunaria_mvp.sql`. Se comparó con la copia original
   de `lunaria/supabase/migrations/001_lunaria_mvp.sql`: ambas son idénticas
   byte a byte (SHA-256
   `46d9a1b6db3f9a6509df5969df883015ce2b559012e9f3b3d4ae588d3fccf748`).
   Revisa el resumen de auditoría más abajo y compara el historial real de
   Supabase antes de aplicar nada.
5. Comprueba en Supabase que el esquema corresponde a las migraciones
   existentes. En una base nueva, aplica migraciones en este orden:

   1. `001_lunaria_mvp.sql` (recuperada y versionada en este proyecto)
   2. `002_lunaria_profile_trigger.sql`
   3. `003_home_daily_data.sql`
   4. `004_mindspace_tables_and_rls.sql`
   5. `005_beautyroom_catalog_and_storage.sql`
   6. `006_melodyroom_spotify_favorites.sql`
   7. `007_melodyroom_library_and_my_space.sql`
   8. `008_authorized_lunaria_users.sql`

   En el proyecto Lunaria existente, 007 fue reportada como aplicada. No
   repitas migraciones: compara primero el historial y el esquema real. La 008
   es local y requiere revisión/aplicación manual; no debe aplicarse hasta
   verificar que sus objetos existen. No ejecuté ninguna migración.
6. Después de aplicar y revisar la 008, consulta los UUID en **Supabase → Auth
   → Users** e incorpora solo los dos valores reales en el SQL Editor:

   ```sql
   insert into private.lunaria_authorized_users (slot, user_id)
   values
     (1, '<UUID_REAL_DE_TU_CUENTA>'::uuid),
     (2, '<UUID_REAL_DE_MAI>'::uuid);
   ```

   Sustituye ambos placeholders por los UUID verificados. No los incluyas en
   Git, Flutter, variables del build ni logs. Confirma la inserción mediante
   una consulta administrativa y no expongas los UUID en logs públicos.
7. En Supabase **Authentication → URL Configuration**, configura como **Site
   URL**:

   `https://bordinola00-dev.github.io/lunaria_flutter/`

   Añade esa URL exacta y
   `https://bordinola00-dev.github.io/lunaria_flutter/auth.html` a la lista de
   retorno permitida. El enlace de confirmación de email usa el Site URL
   predeterminado porque Lunaria no pasa un `redirectTo` propio en el registro.
8. En Spotify Developer Dashboard, añade exactamente:

   `https://bordinola00-dev.github.io/lunaria_flutter/auth.html`

   No uses Client Secret. La implementación solicita Authorization Code with
   PKCE y verifica el parámetro `state`.
9. Primero abre un pull request hacia `main`: el workflow compila Flutter Web,
   comprueba el contenido y prepara `build/web` como artifact sin desplegarlo.
   Tras revisar el resultado y configurar la protección de datos, fusionar o
   actualizar `main` ejecutará el job de publicación. `workflow_dispatch`
   permite iniciarlo manualmente; no se ha ejecutado ningún workflow desde
   este entorno.

Todas las acciones de GitHub Actions están fijadas a commits completos, no a
tags móviles. El workflow usa `flutter build web --release --pwa-strategy=none` con base href
`/lunaria_flutter/`, sube `build/web` como artifact de GitHub Pages y despliega
solo en eventos distintos de `pull_request`. GitHub Pages debe tener el origen
**GitHub Actions** seleccionado.

## Restricción de acceso a dos cuentas

La allowlist vive en el esquema privado de PostgreSQL, no en Flutter ni en
GitHub Actions. La tabla limita el número de cuentas a dos posiciones. Después
de aplicar la migración 008, obtiene los UUID reales en **Supabase → Auth →
Users** y ejecuta en el SQL Editor, sin sustituirlos por valores inventados:

```sql
insert into private.lunaria_authorized_users (slot, user_id)
values
  (1, '<UUID_REAL_DE_TU_CUENTA>'::uuid),
  (2, '<UUID_REAL_DE_MAI>'::uuid);
```

No guardes esos UUID en este repositorio. La app consulta la autorización tras
restaurar o iniciar sesión; si Supabase no puede verificarla, cierra la sesión
y no abre las pantallas privadas. Las políticas restrictivas cubren las tablas
de Lunaria conocidas, Storage, Realtime y las RPC de Mi Luna. El backend sigue
siendo la barrera efectiva; el guard de Flutter solo mejora la experiencia.

La pantalla de registro no impide crear un usuario en Supabase. Una cuenta que
no esté en las dos posiciones se cierra al intentar entrar y RLS le deniega
acceso a los datos. No publiques antes de aplicar y comprobar la migración 008
en el proyecto Supabase real. La recuperación de la 001 permite completar la
auditoría estática de las migraciones del repositorio, pero no verifica el
estado ni los permisos actuales del proyecto remoto.

## Pruebas previas a publicar

Las siguientes pruebas requieren las dos cuentas autorizadas y una tercera
cuenta de prueba. No compartas contraseñas, tokens ni service keys; usa sesiones
temporales y no guardes sus tokens en archivos del repositorio:

1. Inicia sesión con cada una de las dos cuentas autorizadas y verifica acceso
   a perfiles compartidos, fotografías y conversación de Mi Luna.
2. Inicia sesión con una tercera cuenta Supabase no autorizada. La app debe
   cerrarle la sesión y la API debe denegar SELECT, INSERT, UPDATE y DELETE
   sobre las tablas privadas.
3. Sin sesión, verifica que las consultas a tablas privadas, Storage y RPC
   protegidas sean denegadas.
4. Con la tercera cuenta, prueba lectura, carga, actualización y borrado en
   `beautyroom-images` y `lunaria-private`; todo debe fallar. Confirma que
   ambos buckets estén marcados como privados.
5. Con la tercera cuenta, invoca directamente las RPC de Mi Luna; deben fallar
   por autorización incluso sin pasar por Flutter.
6. Suscribe la tercera cuenta a un canal privado Realtime de Mi Luna y verifica
   que no reciba eventos. Repite con una cuenta autorizada.
7. Completa Spotify OAuth con el callback exacto bajo
   `/lunaria_flutter/auth.html`; no se usa Spotify Client Secret.
8. Inspecciona el build: no debe contener `.env*`, `service_role`, `sb_secret`
   ni un service-role JWT. Verifica rutas/assets bajo `/lunaria_flutter/`,
   manifest, callback `auth.html` y que el service worker no contenga
   manejadores de `fetch` ni use Cache API para almacenar respuestas privadas.
9. Espera el éxito del build de PR. Solo tras autorización explícita para
   publicar, fusiona a `main` y comprueba el deployment de Pages. Prueba luego
   la URL en Safari de iPhone y Android reales.

No se han ejecutado pruebas contra el proyecto Supabase real ni contra cuentas
reales; son pasos pendientes, no resultados. Un build local o un smoke test de
navegador no certifican autorización, OAuth, Storage ni Realtime remotos. La
auditoría estática cubre ahora las migraciones locales 001–008, pero no permite
declarar Lunaria lista para datos privados hasta verificar el esquema y todos
los resultados en el proyecto remoto.

## Auditoría de las migraciones 001–008

La 001 recuperada crea las tablas `profiles`, `mood_entries`, `diary_entries`,
`beauty_products`, `beauty_looks`, `playlists` y `songs`. Sus relaciones de
propiedad referencian `auth.users(id)` con borrado en cascada; crea índices de
usuario/fecha para las tablas de actividad y activa RLS con políticas de
propietario en las siete tablas. No crea vistas, funciones, triggers, buckets
de Storage ni configuración/publicación de Realtime.

Las migraciones siguientes dependen de esa estructura:

- **002** añade el trigger de alta de usuario y `set_updated_at`; presupone
  `profiles` y las tablas base.
- **003** extiende `mood_entries` con fecha y crea `set_daily_mood` y
  `daily_routines` con RLS.
- **004** vuelve a declarar `mood_entries` y `diary_entries` con `IF NOT
  EXISTS`. Sus columnas coinciden con la 001; sustituye las políticas base por
  políticas autenticadas y restrictivas.
- **005** amplía productos y looks, añade la función/trigger de limpieza de
  looks y el bucket privado `beautyroom-images` con políticas Storage.
- **006** amplía canciones para favoritos Spotify y reemplaza la política de
  canciones.
- **007** amplía canciones/perfiles/playlist, crea `playlist_songs` y las
  tablas de Mi Luna, sus funciones/RPC, políticas Storage para
  `lunaria-private` y políticas/publicación Realtime.
- **008** crea la allowlist de dos slots y políticas restrictivas adicionales
  para las tablas conocidas, Storage, Realtime y las RPC de Mi Luna.

Hay duplicaciones deliberadas compatibles: la 004 repite las definiciones
base de ánimo/diario con `IF NOT EXISTS`; la 007 vuelve a crear `playlists`
con `IF NOT EXISTS` y agrega `description`. Las columnas base coinciden. Las
políticas con nombres repetidos se eliminan antes de recrearse en 004–007.
Índices repetidos usan `IF NOT EXISTS` y las definiciones revisadas coinciden.
No encontré en estas migraciones vistas ni otras tablas base ocultas.

Esta comparación verifica compatibilidad textual/dependencias entre los
archivos; no ejecuta SQL ni prueba idempotencia contra una instancia real.
Debe confirmarse que el proyecto remoto aplicó la 001 original y las
migraciones posteriores esperadas, que los buckets siguen siendo privados, que
las políticas están instaladas y que ambas filas reales de allowlist existen.

## Compilación local en Linux

Se requiere Flutter estable 3.50.1 o compatible. Configura las variables
públicas en el entorno de la shell y ejecuta:

```bash
flutter pub get
./tool/build_web.sh
```

La salida se genera en `build/web`. No se necesita macOS ni Xcode para
compilar Flutter Web. `--pwa-strategy=none` evita que la compilación genere
un worker con caché offline; Flutter marca esta opción como deprecada, así que
hay que revisar este ajuste al actualizar el SDK y mantener la prueba del
artefacto.

Las rutas de Flutter usan el hash de URL de GoRouter, por ejemplo
`/lunaria_flutter/#/login`; recargar vuelve a servir `index.html` y no requiere
un `404.html` de SPA en GitHub Pages. `auth.html` es un archivo real bajo el
subdirectorio del proyecto.

## Instalar en iPhone

1. Abre `https://bordinola00-dev.github.io/lunaria_flutter/` en Safari.
2. Selecciona **Compartir → Añadir a pantalla de inicio**.
3. Abre Lunaria desde el icono para usar el modo standalone.

El manifest, los iconos y las etiquetas Apple usan el subdirectorio del
repositorio. El proyecto no promete uso offline. La selección de fotografías
usa el selector de archivos del navegador y queda limitada por iOS/Safari. La
persistencia, la ventana de OAuth de Spotify y la instalación deben probarse
en un iPhone real; no se afirma que esas pruebas se hayan realizado.
