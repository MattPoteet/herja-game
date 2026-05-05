# Mobile App and AdMob Notes

Herja's Godot client now has a small mobile/app platform layer in `godot_client/scripts/MobilePlatform.gd`.

Mobile layout is enabled when either:

- The build is running as a native Android or iOS app.
- The viewport is phone-sized.

AdMob is intentionally native-only. Desktop web and normal browser play do not load AdMob.

## AdMob configuration

The source code defaults to Google test ad unit IDs. Configure production IDs through the app/export environment before release.
The Android app config currently has:

- Android app ID: `ca-app-pub-1019842095728273~4129909747`
- Android interstitial ID: `ca-app-pub-1019842095728273/2164108458`

Android banner and rewarded IDs are blank until those ad units are created in AdMob.

Supported environment/config names:

- `NEXT_PUBLIC_ADMOB_ENABLED`
- `NEXT_PUBLIC_ADMOB_TEST_MODE`
- `NEXT_PUBLIC_ADMOB_ANDROID_APP_ID`
- `NEXT_PUBLIC_ADMOB_IOS_APP_ID`
- `NEXT_PUBLIC_ADMOB_ANDROID_BANNER_ID`
- `NEXT_PUBLIC_ADMOB_ANDROID_INTERSTITIAL_ID`
- `NEXT_PUBLIC_ADMOB_ANDROID_REWARDED_ID`
- `NEXT_PUBLIC_ADMOB_IOS_BANNER_ID`
- `NEXT_PUBLIC_ADMOB_IOS_INTERSTITIAL_ID`
- `NEXT_PUBLIC_ADMOB_IOS_REWARDED_ID`
- `NEXT_PUBLIC_ADMOB_INTERSTITIAL_EVERY_N_LOADS`

`NEXT_PUBLIC_ADMOB_INTERSTITIAL_EVERY_N_LOADS` controls how often native interstitial ads can appear during area/load transitions. The default is every 10 loads.

## Native plugin TODO

`godot_client/scripts/AdMobManager.gd` looks for common Godot singleton names:

- `GodotAdMob`
- `AdMob`
- `AdmobPlugin`

Install and configure the actual Android/iOS Godot AdMob plugin before publishing native builds. The manager is safe without the plugin; it logs that the plugin is missing and falls back without showing AdMob.

## Gameplay safety

Ad breaks are requested from the existing loading-screen flow, after gameplay starts. They are not shown on the login screen. The existing ad pause system still pauses player movement and enemy combat while an ad break is active.
