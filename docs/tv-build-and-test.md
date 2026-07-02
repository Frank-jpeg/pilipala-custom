# Android TV Build and Test Guide

## Purpose

The Android TV work lives on the `tv` branch and is isolated from the mobile `main` flow.
It is currently a usable MVP for manual TV testing, not a published in-app update channel.

## TV app shape

- Flavor: `tv`
- Entry point: `lib/main_tv.dart`
- Package/application id: `com.guozhigq.pilipala.custom.tv`
- Main TV UI: `lib/tv/`
- GitHub Actions workflow: `.github/workflows/tv_apk_artifact.yml`
- CI artifact name: `pilipala-custom-android-tv-arm64`
- CI APK filename pattern: `pilipala-custom-tv-<version>-<sha>-arm64-v8a.apk`

The TV app now uses a left navigation shell, with recommendation as one real section instead of replacing the whole app:

- left navigation items: `推荐` / `搜索` / `媒体库` / `登录` or `我的` / `设置`
- `推荐` section uses the immersive recommendation stage
- selected recommendation now starts an inline homepage video preview after focus settles, with artwork fallback if preview playback fails
- DPAD up/down switches recommendations
- OK enters full-screen playback
- right opens details
- left returns focus to the left navigation
- idle on a recommendation can auto-enter full-screen playback
- from recommendation playback, DPAD up/down switches previous/next recommendation
- `设置` can enable/disable idle auto-fullscreen and change the delay from 5 to 60 seconds
- `设置` can enable TV anti-addiction controls with a local 4-digit parent PIN
- TV anti-addiction tracks recommendation preview and full-screen playback, then locks playback for forced rest or daily limit countdowns

## API sources

The TV MVP reuses the existing project API layer.

- Home recommendation currently uses the app feed endpoint: `https://app.bilibili.com/x/v2/feed/index`.
- Video details use Web API: `https://api.bilibili.com/x/web-interface/view`.
- Playback uses WBI Web API: `https://api.bilibili.com/x/player/wbi/playurl`.
- Login QR in the TV UI currently uses the existing Web QR login flow.
- TV login also provides an `账号登录` fallback that opens the same official Bilibili H5 login page used by the mobile app through WebView. Use this when QR login does not sync, or when password/SMS/risk verification is required.

Reference projects checked on 2026-06-29:

- `kkkunny/bilitv`: primarily uses Web/WBI APIs for recommendation, search, details, playback, QR login, history, and dynamic feeds.
- `xiaye13579/BBLL`: public repo contains README only; the latest release APK string scan shows Web/WBI API usage such as `x/web-interface/*`, `x/player/wbi/playurl`, Web QR login, history, favorites, and dynamic endpoints. No clear TV-only API source was visible from the public repo/APK string scan.

## Local build commands

Use the pinned Flutter SDK:

```powershell
$env:MEDIA_KIT_ANDROID_VIDEO_ARM64_JAR='C:\Users\Lan\Desktop\default-arm64-v8a.jar'
& 'G:\Dev\flutter_3.19.6\bin\flutter.bat' build apk --release --flavor tv -t lib/main_tv.dart --target-platform android-arm64 --split-per-abi
```

Expected output:

- `build/app/outputs/flutter-apk/app-arm64-v8a-tv-release.apk`

For the Google TV emulator:

```powershell
$env:MEDIA_KIT_ANDROID_VIDEO_ARM64_JAR='C:\Users\Lan\Desktop\default-arm64-v8a.jar'
$env:MEDIA_KIT_ANDROID_VIDEO_X64_JAR='C:\Users\Lan\Desktop\default-x86_64.jar'
& 'G:\Dev\flutter_3.19.6\bin\flutter.bat' build apk --debug --flavor tv -t lib/main_tv.dart --target-platform android-x64
```

Expected output:

- `build/app/outputs/flutter-apk/app-tv-debug.apk`

## Emulator setup

Installed local emulator setup:

- SDK root: `G:\Android\Sdk`
- AVD home: `G:\Android\avd`
- AVD name: `PiliPala_Google_TV_API_36`
- System image: `system-images;android-36;google-tv;x86_64`
- Device template: `tv_1080p`

Start it with:

```powershell
$env:ANDROID_AVD_HOME='G:\Android\avd'
$env:ANDROID_SDK_ROOT='G:\Android\Sdk'
Start-Process -FilePath 'G:\Android\Sdk\emulator\emulator.exe' -ArgumentList @('-avd','PiliPala_Google_TV_API_36','-gpu','auto') -WindowStyle Hidden
```

Install and launch:

```powershell
& 'G:\Android\Sdk\platform-tools\adb.exe' -s emulator-5554 install -r 'build\app\outputs\flutter-apk\app-tv-debug.apk'
& 'G:\Android\Sdk\platform-tools\adb.exe' -s emulator-5554 shell am start -n com.guozhigq.pilipala.custom.tv/com.guozhigq.pilipala.MainActivity
```

DPAD smoke commands:

```powershell
& 'G:\Android\Sdk\platform-tools\adb.exe' -s emulator-5554 shell input keyevent 20  # down
& 'G:\Android\Sdk\platform-tools\adb.exe' -s emulator-5554 shell input keyevent 19  # up
& 'G:\Android\Sdk\platform-tools\adb.exe' -s emulator-5554 shell input keyevent 23  # OK
& 'G:\Android\Sdk\platform-tools\adb.exe' -s emulator-5554 shell input keyevent 4   # back
```

## Emulator limitations

The Google TV emulator is useful for:

- launcher/activity startup
- Android TV manifest and Leanback environment
- DPAD focus and navigation
- API parsing and Flutter runtime exceptions
- basic full-screen player route behavior

It is not enough to sign off video playback quality. During 2026-06-29 testing, the emulator could request playback URLs and enter the player, but video output was black on some runs. This can be an emulator/software-rendering/media_kit limitation and must be checked on a real Android TV or TV box before calling playback done.

## Real-device test checklist

Use the latest `tv` branch artifact from GitHub Actions or the local arm64 release APK.

1. Install the TV APK on a real Android TV or TV box.
2. Confirm the app appears in the TV launcher.
3. Open the app and confirm the left navigation shell loads.
4. Enter `推荐` and confirm the immersive recommendation stage loads.
5. Confirm the focused recommendation starts autoplaying on the home page after a short delay.
6. Use DPAD up/down to switch recommendations and confirm the preview switches with the selected item.
7. Wait for the configured idle delay and confirm it enters full-screen playback.
8. Press OK on a recommendation and confirm full-screen playback opens.
9. In recommendation playback, use DPAD up/down to switch videos.
10. Press Back and confirm it returns to the correct previous page:
   - recommendation playback -> recommendation stage
   - detail playback -> detail page
11. Enter `登录` and test both login paths:
    - `扫码登录`: scan the TV QR code and confirm the app detects login state.
    - `账号登录`: open the official WebView login page and confirm `刷新登录状态` syncs the account after login.
12. Enter `搜索` and confirm both `返回` and `搜索` buttons are focusable with DPAD.
13. Enter `媒体库` and confirm the page is usable in both logged-in and not-logged-in states.
14. Enter `设置` and confirm idle auto-fullscreen can be toggled and its delay can be adjusted.
15. In `设置`, set a parent PIN, enable `TV 防沉迷`, and confirm the default values are 30 minutes watch / 20 minutes rest / daily limit off.
16. Temporarily reduce the single-session limit during manual testing if needed, then confirm recommendation preview and full-screen playback both trigger the lock page.
17. Confirm Back cannot bypass the anti-addiction lock page.
18. Confirm parent PIN unlock resumes playback and daily-limit PIN unlock adds only the temporary extra watch time.
19. Confirm real playback has video and audio.
20. Test account-only flows after login if needed.

If real-device playback is black, treat it as a player/play-url compatibility bug and inspect `TvPlayerController` plus the shared `PlPlayerController`/`media_kit` integration first.
