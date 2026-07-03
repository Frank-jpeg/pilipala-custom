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
- OK enters full-screen playback and resumes from the current homepage preview position when available
- right opens details
- left returns focus to the left navigation
- idle on a recommendation can auto-enter full-screen playback and resumes from the current homepage preview position when available
- from recommendation playback, DPAD up/down switches previous/next recommendation
- `设置` can enable/disable idle auto-fullscreen and change the delay from 5 to 60 seconds
- `设置` can enable TV anti-addiction controls with a local 4-digit parent PIN
- TV anti-addiction tracks recommendation preview and full-screen playback, then locks playback for forced rest or daily limit countdowns
- `登录` / `我的` supports `扫码登录`, `手机号登录`, and `网页登录兜底`, and the logged-in `我的` page exposes logout
- `手机号登录` uses the on-screen 9-key number pad for phone number and SMS code, and now overlays a DPAD cursor when Geetest point-select captcha appears
- `网页登录兜底` reuses the official Bilibili H5 login page in WebView and also provides the same DPAD cursor for remote-only devices during password/risk verification

## API sources

The TV MVP reuses the existing project API layer.

- Home recommendation currently uses the app feed endpoint: `https://app.bilibili.com/x/v2/feed/index`.
- Video details use Web API: `https://api.bilibili.com/x/web-interface/view`.
- Playback uses WBI Web API: `https://api.bilibili.com/x/player/wbi/playurl`.
- Login QR in the TV UI currently uses the existing Web QR login flow.
- TV login provides three paths:
  - `扫码登录`: Web QR login with polling.
  - `手机号登录`: remote-friendly 9-key number pad for phone number and SMS code.
  - `网页登录兜底`: opens the same official Bilibili H5 login page used by the mobile app through WebView. Use this when QR/SMS login does not sync, or when password/risk verification is required.
- The TV SMS path still uses the existing Web SMS + Geetest captcha flow, but the TV shell now injects a remote-controlled pointer for point-select captcha taps.
- The `tvLogin` WebView path also injects the same remote-controlled pointer so official H5 password/risk verification remains operable from a DPAD-only device.

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
- versioned handoff copy: `releases/pilipala-custom-tv-v<version>-<build>-<short-sha>-arm64-v8a.apk`

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
8. Confirm the idle auto-fullscreen playback continues from the homepage preview position instead of restarting from 0 seconds.
9. Press OK on a recommendation and confirm full-screen playback opens from the current homepage preview position when preview is already playing.
10. In recommendation playback, use DPAD up/down to switch videos and confirm switched videos start from 0 seconds.
11. Press Back and confirm it returns to the correct previous page:
   - recommendation playback -> recommendation stage
   - detail playback -> detail page
12. Enter `登录` and test all login paths:
    - `扫码登录`: scan the TV QR code and confirm the app detects login state.
    - `手机号登录`: use the on-screen 9-key number pad to input an 11-digit phone number, request an SMS code, and if Geetest point-select captcha appears, confirm the DPAD cursor appears, arrow keys move it, and OK can click the requested characters.
    - `手机号登录`: after captcha passes, input the 6-digit SMS code and confirm login state syncs.
    - `网页登录兜底`: open the official WebView login page and confirm the DPAD cursor can click the official page controls, password/risk verification remains operable, and `刷新登录状态` syncs the account after login.
    - `我的`: after login, enter `我的` and confirm `退出登录` clears the login state.
13. In `手机号登录`, confirm `清空`, `0`, `删除`, `返回手机号`, countdown resend, incomplete input validation, and captcha overlay re-entry all work with DPAD/OK.
14. Enter `搜索` and confirm both `返回` and `搜索` buttons are focusable with DPAD.
15. Enter `媒体库` and confirm the page is usable in both logged-in and not-logged-in states.
16. Enter `设置` and confirm idle auto-fullscreen can be toggled and its delay can be adjusted.
17. In `设置`, set a parent PIN, enable `TV 防沉迷`, and confirm the default values are 30 minutes watch / 20 minutes rest / daily limit off.
18. Temporarily reduce the single-session limit during manual testing if needed, then confirm recommendation preview and full-screen playback both trigger the lock page.
19. Confirm Back cannot bypass the anti-addiction lock page.
20. Confirm parent PIN unlock resumes playback and daily-limit PIN unlock adds only the temporary extra watch time.
21. Confirm real playback has video and audio.
22. Test account-only flows after login if needed.

If real-device playback is black, treat it as a player/play-url compatibility bug and inspect `TvPlayerController` plus the shared `PlPlayerController`/`media_kit` integration first.
