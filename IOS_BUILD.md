# iOS build and private installation

## Audit summary

Lunaria is a Flutter/Dart app organized around feature screens, Riverpod
providers, repositories, and a shared Supabase client. Its existing native iOS
project uses Swift Package Manager for Flutter plugins and targets iOS 15. The
Xcode project already defines bundle ID `com.lunaria.lunariaFlutter`; the
display name and app icons are present.

The dependencies in `pubspec.yaml` have iOS implementations where native
functionality is needed. The checked-in iOS plugin registrant includes secure
storage, web authentication, image picker, app links, package info, shared
preferences, and URL launching. Supabase, Riverpod, routing, animations,
SVG/fonts, HTTP, and crypto are Flutter/Dart packages.

| App capability | iOS status and configuration |
| --- | --- |
| Supabase email/password auth, database, and Storage | Uses HTTPS and the shared Supabase client; no Android-only code found. A public anon/publishable key must be supplied at build time. |
| BeautyRoom and profile/chat images | Uses the system photo library picker. `NSPhotoLibraryUsageDescription` is already present. No camera, microphone, or broad filesystem access is used. |
| Spotify authorization | Uses `flutter_web_auth_2` and PKCE. The `lunaria-spotify` callback scheme already matches `lunaria-spotify://callback` in `Info.plist` and the Dart default. Add that exact redirect URI in Spotify's developer settings and provide `SPOTIFY_CLIENT_ID` at build time to enable it. |
| Spotify tokens | Stored with `flutter_secure_storage`, backed by iOS Keychain. |
| External links and app updates | Opened via `url_launcher` using external HTTPS URLs; no extra URL-query permission is needed for those calls. |
| Version updater | Now selects APK assets on Android and IPA assets on iOS. iOS presents the required sideloading/weekly-renewal steps; iOS itself cannot silently install a downloaded IPA. |
| Local preferences and app metadata | Uses iOS Foundation-backed implementations already present in the dependency lockfile/plugin registrant. |

No incompatible dependency or missing permission was found in the reviewed
code. The iOS Runner target now explicitly uses Xcode automatic code signing
for Debug, Profile, and Release; no team ID, certificate, or private key is
embedded. The updater now supports `.ipa` assets on iOS while keeping `.apk`
selection on Android. `Info.plist`, the current bundle ID, deployment target,
callback URL, icon catalog, and plugin registration were already correctly
configured and remain unchanged. The bundle ID must still be confirmed as
unique/available for the Apple account used to sign the app. No Android files
were changed.

## Remote macOS build

Flutter's iOS build requires macOS and Xcode; Linux cannot compile the iOS
target locally. The added [`codemagic.yaml`](codemagic.yaml) provides a
Codemagic macOS M2 workflow that produces a **release IPA without a signature**.
It intentionally does not request Apple signing assets or upload credentials.

1. Connect the repository to Codemagic. This shares the repository source with
   that service; review its access and privacy terms before connecting it.
2. Create a Codemagic environment-variable group named
   `lunaria_ios_config`. Add `SUPABASE_ANON_KEY` using only the public
   publishable/anon key. Add `SPOTIFY_CLIENT_ID` if Spotify should be enabled.
   Do not add a `service_role` key, SMTP password, private key, or other
   administrative secret.
3. Run the `lunaria_ios_unsigned` workflow. It creates the ignored `.env` only
   in the temporary build workspace, runs `flutter pub get`, and publishes
   `build/ios/ipa/*.ipa` as a build artifact.
4. The resulting IPA is unsigned and **cannot be installed directly**. Signing
   it for the iPhone is a separate step below.
5. To have Lunaria's updater offer an iOS update, attach an `.ipa` asset to the
   matching stable GitHub release. The app opens its download in the browser;
   the user must hand the IPA to AltStore/SideStore to sign and install it.

Codemagic's published individual free plan currently includes 500 macOS M2
build minutes per month, one concurrent build, and a 120-minute maximum build
duration. After that allowance it lists US$0.095 per M2 minute. Avoid enabling
pay-as-you-go or adding billing details unless you accept possible charges;
pricing and terms can change. This workflow does not use Codemagic's signing
service.

Other options:

- GitHub Actions standard macOS runners are billed at US$0.062/minute and
  private-repository usage draws from the account's included compute allowance
  before additional billing. Public-repository standard runner usage is free,
  but that requires making the source public. This is not a reliably free
  option for a private app.
- Codemagic's documented automated iOS signing workflow requires Apple
  Developer Program signing resources. Do not assume its free build minutes
  also provide free signing.

## Free Apple signing and private installation

An unpaid Apple Account can use an Xcode **Personal Team** for personal device
testing. Apple's current limits are up to 10 App IDs and 3 registered devices
(each expires after 7 days), and up to 3 installed apps per device. A Personal
Team provisioning profile expires after 7 days, so Lunaria must be signed and
reinstalled/refreshed at least weekly. This is not App Store distribution and
does not require paying the Apple Developer Program's US$99 annual membership
(regional price/tax may vary), but it does not provide durable signing.

For a Linux-only computer, the least-cost route to try is:

1. Build the unsigned IPA with the Codemagic workflow above.
2. On Linux, use the community-maintained
   [AltServer-Linux](https://github.com/powenn/AltServer-Linux-PyScript) /
   [SideStore Altcon](https://github.com/SideStore/Altcon) tooling to pair the
   iPhone over USB, install a sideloading client, and sign/install Lunaria with
   the free Apple Account. The AltServer-Linux project documents installation
   of a locally supplied IPA and Wi-Fi/tethered refresh.
3. Keep the Linux helper available and refresh the app before the 7-day
   profile expires. On iOS 16 and later, enable Developer Mode if iOS requests
   it.

If a physical Mac is available, sign in to the Apple Account in Xcode and
select its **Personal Team** under Runner → Signing & Capabilities. The
automatic-signing setting added to this project lets Xcode create the
development profile; the iPhone must be connected and trusted for initial
provisioning. Codemagic's unsigned workflow does not perform this step.

These are community tools, not an Apple-supported Linux workflow. Their
availability, Apple authentication, and compatibility can change, and this
route has not been tested with Lunaria or the target iPhone. Use only a
repository/release you have independently vetted. If it does not work, the
fallback is access to a physical Mac with Xcode or a Windows/Mac computer with
an officially supported sideloading utility; a cloud build runner cannot
connect to a USB iPhone sitting beside the Linux computer.

Never upload Apple credentials, signing certificates/private keys, or the
local `.env` to this repository. The Supabase client key and Spotify client ID
are public client configuration; the IPA necessarily contains the Supabase
public key. They do not replace server-side Supabase row-level security.

## Manual checks still required

- Confirm the existing bundle ID is available for the Apple Personal Team and
  retain it consistently while signing.
- Configure the exact Spotify redirect URI
  `lunaria-spotify://callback` in Spotify's developer dashboard and set its
  client ID in Codemagic if that integration is used.
- Supply the project's public Supabase anon/publishable key to the Codemagic
  variable group. Keep the Supabase project and its policies configured; this
  build does not change backend migrations.
- Install and exercise the app on the actual iPhone: onboarding, sign-up/login,
  email confirmation, image selection/upload, Spotify callback, external
  links, and Supabase-backed reads/writes.

This environment is Linux and has no Flutter executable or Xcode. Therefore no
iOS compilation, signing, installation, or on-device behavior is claimed as
verified here.

## References

- [Flutter: build and release an iOS app](https://docs.flutter.dev/deployment/ios)
- [Apple: Developer account and Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [Codemagic pricing](https://codemagic.io/pricing/)
- [Codemagic: Flutter YAML workflow](https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/)
- [Codemagic: iOS code signing requirements](https://docs.codemagic.io/yaml-code-signing/signing-ios/)
- [GitHub Actions runner pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing)
- [AltStore: install on Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)
