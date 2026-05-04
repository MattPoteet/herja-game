# AdSense / H5 Games Ad Breaks

Herja has a game-side ad break controller for map section loading.

## Behavior

- Every 10th map section load triggers a sponsored break.
- Player movement is paused while the ad break is active.
- Enemy movement, enemy attacks, and enemy respawns are paused while the ad break is active.
- The ad overlay has a fallback timer so the game remains testable before real ads are configured.

## Main files

- `godot_client/scripts/AdManager.gd`
- `godot_client/scripts/Main.gd`
- `godot_client/scripts/Enemy.gd`
- `godot_client/scripts/SpawnManager.gd`
- `web/index.html`
- `WebBuild/index.html`

## Web ad hook

The Godot client calls this JavaScript hook during eligible ad breaks:

```js
window.herjaShowInterstitial()
```

The exported web HTML files include a placeholder implementation that calls Google H5 Games Ads `adBreak(...)` only if the ad API has been loaded.

## Before real ads go live

Google H5 Games Ads is an application/approval-based product for HTML5 games. Add your approved publisher and ad placement setup to the web page that hosts the game, then replace the placeholder hook with your production ad call.

For native mobile builds, use AdMob / Google Mobile Ads SDK rather than plain web AdSense.
