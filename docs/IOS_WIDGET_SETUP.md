# iOS home-screen widget: setup steps

Plan item #25. The Android widget ships now (`BojangStreakWidget.kt`). The iOS
widget code is written (`ios/BojangWidget/`) but the **extension target is not
in the Xcode project**, on purpose: an extension needs its own App ID, an App
Group on both App IDs and a provisioning profile that CI can sign with. Adding
the target without those breaks the TestFlight export.

Until then the Flutter side already runs on iOS: `HomeWidgetSync` calls
`HomeWidget.setAppGroupId('group.com.bojang.app.widget')` and writes the data.
Without the App Group entitlement that write lands in the app's own defaults,
and `updateWidget` asks WidgetKit to reload a kind nobody has, which is a no-op.

## What the widget shows

Written by `lib/services/home_widget_sync.dart`, keys defined in
`lib/utils/widget_snapshot.dart` (the contract for both platforms):

| Key | Type | Meaning |
|---|---|---|
| `streak` | int | Current streak |
| `streak_state` | string | `none` / `active` / `frozen` (a freeze covered yesterday) / `earn_back` (window open) |
| `today_done`, `today` | bool, `yyyy-mm-dd` | As of the last write |
| `last_done_date` | `yyyy-mm-dd` | Local day of the last practice; the widget compares it with its own clock |
| `day_part` | string | Part of day at the last write (`day`, `evening`, `late`, `last_call`) |
| `line_day`, `line_evening`, `line_late`, `line_last_call`, `line_done` | string | Norbu's headline per part of day (0-16h, 16-20h, 20-22h, 22-24h) and once done |
| `word_tibetan`, `word_phonetic`, `word_english` | string | Word of the day (`lib/utils/word_of_the_day.dart`) |
| `earn_back_streak` | int | The streak Earn Back would restore |

## Steps

1. **Apple Developer portal** (Certificates, Identifiers & Profiles):
   - Identifiers > App Groups > add `group.com.bojang.app.widget`.
   - Edit the App ID `com.bojang.app`: enable App Groups, select the group.
   - Add an App ID `com.bojang.app.widget` (explicit), App Groups enabled with
     the same group. No other capability.
2. **Xcode** (`ios/Runner.xcworkspace`):
   - File > New > Target > Widget Extension. Product name `BojangWidget`,
     bundle ID `com.bojang.app.widget`, no Live Activity, no configuration
     intent. Embed in Runner.
   - Delete the generated Swift files and add the files in `ios/BojangWidget/`
     (`BojangWidget.swift`, `Info.plist`, `BojangWidget.entitlements`) to the
     new target. Set Code Signing Entitlements to
     `BojangWidget/BojangWidget.entitlements`.
   - Deployment target 15.0 (same as Runner). Same team. Same
     `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` as Runner (the release job
     bumps both; set them from `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)`
     like Runner does).
   - Runner > Signing & Capabilities > + App Groups > `group.com.bojang.app.widget`
     (this adds `com.apple.security.application-groups` to
     `Runner/Runner.entitlements`).
   - The widget does not import Flutter or home_widget, so the Podfile needs no
     new target.
3. **CI** (`.github/workflows/mobile-release.yml`):
   - The archive is built unsigned and the app is ad-hoc signed with
     `Runner.entitlements` before export. Do the same for the extension: find
     `Bojang.app/PlugIns/BojangWidget.appex` and
     `codesign --force --sign - --entitlements ios/BojangWidget/BojangWidget.entitlements`
     it **before** signing the app (inner bundles first).
   - Export uses automatic signing with `-allowProvisioningUpdates` and the ASC
     key, which creates the extension's App Store profile as long as the App ID
     and App Group exist (step 1). If the API key cannot create profiles, make
     an App Store profile for `com.bojang.app.widget` by hand.
   - Add a verify step like the applesignin one:
     `codesign -d --entitlements - .../BojangWidget.appex | grep application-groups`.
4. **Test** on a device or simulator: add the widget (small and medium), finish
   a lesson and check the tick and "Done today", change the clock past 16:00,
   20:00 and 22:00 and check the headline, and check dark mode.
5. Ship through TestFlight as usual; App Review needs nothing extra for a
   widget.

## Android (already built)

`android/app/src/main/kotlin/com/projectmira/bojang/BojangStreakWidget.kt`,
layout `res/layout/bojang_streak_widget.xml`, info
`res/xml/bojang_streak_widget_info.xml` (2x1 minimum, resizable, redraws every
30 minutes), colours in `res/values{,-night}/widget.xml`. Tapping it opens the
app.
