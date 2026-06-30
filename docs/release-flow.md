# PiliPala Release Flow

## Purpose

This fork now has two different Android outputs on GitHub. They are not interchangeable.

- `GitHub Release` asset: user-facing update package. The in-app update check only uses the latest GitHub Release.
- `GitHub Actions artifact`: CI build output for manual download and verification. It does not feed the in-app update flow.

## Current versioning rules

- `pubspec.yaml` version must match the release you want to publish, for example `1.0.30+1030`.
- GitHub Release tags must use the `v` prefix, for example `v1.0.30`.
- Release APK asset name for this fork is `pilipala-custom-<version>-arm64-v8a.apk`.

## Local release APK

Preferred local command:

```powershell
flutter build apk --release --flavor mobile -t lib/main.dart --target-platform android-arm64 --split-per-abi --no-pub
```

Expected output:

- `build/app/outputs/flutter-apk/app-arm64-v8a-mobile-release.apk`
- optional copied file: `releases/pilipala-custom-<version>-arm64-v8a.apk`

If `android/app/vvex.jks` or `android/key.properties` is missing, this project can fall back to the debug keystore for a locally installable release build.

## Main-push artifact workflow

Workflow file:

- `.github/workflows/apk_artifact.yml`

Current behavior:

- triggers on push to `main` or manual dispatch
- builds Android arm64 only
- uses the `mobile` flavor
- uses `--split-per-abi`
- uploads only `app-arm64-v8a-mobile-release.apk`

Important guardrail:

- if CI only produces `app-release.apk` and not `app-arm64-v8a-mobile-release.apk`, the workflow must fail
- do not rename a generic `app-release.apk` to look like an arm64 split package

This guardrail was added after a false-positive success on `2026-06-28`: the workflow succeeded, but the uploaded artifact was actually the generic `app-release.apk` around 40 MB instead of the real arm64 split APK around 23 MB.

## TV branch artifact workflow

Workflow file:

- `.github/workflows/tv_apk_artifact.yml`

Current behavior:

- triggers on push to `tv` or manual dispatch
- builds Android TV arm64 only
- uses the `tv` flavor
- uses `lib/main_tv.dart`
- uses `--split-per-abi`
- verifies `build/app/outputs/flutter-apk/app-arm64-v8a-tv-release.apk`
- uploads artifact `pilipala-custom-android-tv-arm64`

The uploaded APK is renamed as:

- `pilipala-custom-tv-<version>-<short-sha>-arm64-v8a.apk`
- `pilipala-custom-tv-arm64-v8a.apk`

The workflow also updates the prerelease tag `tv-latest` so the project homepage can expose a stable direct-download link for the newest TV build.

TV artifacts are for manual sideload testing. They are not part of the mobile in-app update flow, and the `tv-latest` prerelease does not participate in the mobile app update checker.

## App update flow

The app checks for updates from GitHub Releases, not from Actions artifacts.

For an update to appear inside the app:

1. bump `pubspec.yaml`
2. build the arm64 split APK
3. commit and push `main`
4. push only the new `vX.Y.Z` tag
5. create or update the GitHub Release
6. upload `pilipala-custom-<version>-arm64-v8a.apk` to that Release

The silent startup update check shows a red dot on the avatar when a newer Release exists. Tapping into About marks that remote version as seen.

## Troubleshooting

### Artifact size is much larger than local APK

First check whether CI uploaded:

- `app-arm64-v8a-mobile-release.apk` -> expected mobile arm64 split package
- `app-release.apk` -> generic package, larger size, wrong for this workflow

If artifact size is around 39-40 MB while local arm64 APK is around 23-24 MB, CI likely uploaded the wrong package type.

### `:app:packageRelease` fails on GitHub Actions

Known fix already applied in `apk_artifact.yml`:

- append CI-only Gradle memory overrides
- set `JAVA_TOOL_OPTIONS=-Xmx4096M`
- limit Gradle workers to 1

### App does not show update

Check all of these:

- the GitHub Release tag starts with `v`
- the Release asset is uploaded
- the uploaded file is the arm64 split APK
- the new version is greater than the installed version
