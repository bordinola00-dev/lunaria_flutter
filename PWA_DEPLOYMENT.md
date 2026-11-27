# Lunaria PWA for iPhone

Lunaria remains a Flutter/Dart app. This branch adds Flutter Web as an
additional target; Android and the existing iOS project are retained.

## Web compatibility and limitations

- Supabase authentication and storage use the browser's HTTPS APIs. Configure
  Supabase Auth's Site URL and redirect allowlist for the deployed
  `https://<project>.pages.dev` origin (and any custom domain).
- Spotify uses Authorization Code with PKCE. The web callback is
  `https://<project>.pages.dev/auth.html`; register that exact URL in the
  Spotify app settings and pass it as `SPOTIFY_REDIRECT_URI` at build time.
  The web authentication plugin opens a separate authorization window and
  returns the callback to Lunaria. Safari and installed-PWA behavior still
  needs validation on a physical iPhone.
- Photo selection uses the browser's file picker. The browser controls access
  to the photo library and local files; the app cannot browse arbitrary device
  storage.
- Web secure storage requires HTTPS (or localhost) and is scoped to the
  browser origin/profile. It is not equivalent to iOS Keychain; clearing
  website data can remove saved Spotify tokens and sessions.
- Flutter 3.50 no longer registers a caching service worker automatically
  (the build output can still contain legacy service-worker files). This app
  is installable as a standalone web app, but does not promise offline access.
  Supabase and Spotify features require a network connection.

## Public build configuration

Set these variables in the shell that runs the build:

| Variable | Purpose |
| --- | --- |
| `SUPABASE_URL` | Must be `https://gtzzvklqnmndqfzgbmpd.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase public anon/publishable client key |
| `SPOTIFY_CLIENT_ID` | Public Spotify application client ID |
| `SPOTIFY_REDIRECT_URI` | Exact registered HTTPS callback ending in `/auth.html` |

These values are compiled into the public web app and can be inspected by
anyone who downloads it. Only use the Supabase anon/publishable key and Spotify
client ID. Never use a Supabase `service_role` key, Spotify client secret,
SMTP credential, private key, or other server secret. `.env` remains ignored
by Git; the build script uses the Dart defines and removes the bundled `.env`
asset from `build/web`.

## Build on Linux

Install Flutter 3.50 or later and run `flutter pub get` once. Export the
variables without adding them to the repository, then build:

```bash
export SUPABASE_URL='https://gtzzvklqnmndqfzgbmpd.supabase.co'
export SUPABASE_ANON_KEY='YOUR_PUBLIC_SUPABASE_KEY'
export SPOTIFY_CLIENT_ID='YOUR_SPOTIFY_CLIENT_ID'
export SPOTIFY_REDIRECT_URI='https://YOUR_PROJECT.pages.dev/auth.html'
./tool/build_web.sh
```

The script runs a release web build with content-hashed assets and writes the
deployable site to `build/web`. It rejects an incorrect Supabase project URL or
a non-HTTPS production Spotify callback.

## Cloudflare Pages free deployment

The simplest Linux workflow is Cloudflare Pages **Direct Upload**. It avoids
requiring a Mac or Flutter support in Cloudflare's build image:

1. Create a free Cloudflare account and install Node.js/npm.
2. Authenticate Wrangler with `npx wrangler login`.
3. Create a Pages project with `npx wrangler pages project create lunaria`.
   Choose the production branch when prompted. Direct Upload projects cannot
   later be converted to Git-integrated projects; create a separate project
   if automatic Git deployments are preferred.
4. Build using the production variables above, then deploy:

   ```bash
   npx wrangler pages deploy build/web --project-name=lunaria
   ```

5. Register the resulting `https://lunaria.pages.dev/auth.html` callback in
   Spotify and set the matching `SPOTIFY_REDIRECT_URI` for future builds.
   Update Supabase Auth's Site URL and redirect allowlist for this origin.

This workflow uses only free static Pages Direct Upload; it does not configure
paid Workers or automatic plan upgrades. Cloudflare Pages Free currently
documents 500 builds per month, one concurrent build, a maximum of 20,000
files per site, and a 25 MiB maximum per asset. Limits and plan terms can
change; check Cloudflare's [Pages limits](https://developers.cloudflare.com/pages/platform/limits/)
before deployment. The default `pages.dev` host avoids buying a custom domain.
Wrangler authentication uses the Cloudflare account; do not put API tokens in
this repository. GitHub Actions can automate the upload but requires
Cloudflare account/token secrets and is not needed for manual Direct Upload.

Cloudflare Pages serves a Flutter single-page app through its default
`index.html` fallback as long as there is no top-level `404.html`. Keep
client-side routes on the root domain.

## Install on iPhone

After deployment, open the Pages URL in Safari on the iPhone, choose
**Share > Add to Home Screen**, and enable **Open as Web App** if Safari offers
that option. The Lunaria icon, launch image, and standalone metadata are
supplied by the web manifest and Apple touch-icon tags.

The source has not been tested in iPhone Safari. Before relying on it, test
sign-up/email confirmation, Spotify authorization and return, photo selection,
session persistence after closing/reopening the installed app, network errors,
and display around the iPhone safe areas.
