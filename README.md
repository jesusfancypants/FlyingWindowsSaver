# Flying Windows

Always loved that flying classic Windows screesaver, so now it's on mac! Also there is an Apple logo and an option to put a custom emoji (for unknown reasons).

<img width="1024" height="666" alt="flying" src="https://github.com/user-attachments/assets/614b6d8a-8206-4014-aad7-41ac3df0324c" />

Amount, speed and rotation options are included and self-explanatory.

Ships as a real `.saver` module (System Settings → Wallpaper → Screen Saver → Bottom of the list → Other → Far right).

## Requirements

- macOS 12+ (Apple Silicon or Intel)
- Xcode Command Line Tools (`xcode-select --install`) — no full Xcode needed

## Build

```sh
./build.sh
```

Compiles a universal (arm64 + x86_64) binary via `swiftc` + `lipo` (no `.xcodeproj` involved) and installs `Flying Windows.saver` to `~/Library/Screen Savers/` automatically.

## Install / select it

System Settings → Wallpaper → Screen Saver → Other → **Flying Windows**, then its "Options…" button to change icon/count/speed/rotation.

**Known first-run quirk:** right after installing for the first time, "Options…" may not open on the very first click — this is System Settings not having fully registered the freshly-installed `.saver` with its `legacyScreenSaver.appex` host yet (an Apple-side timing issue, not something this code controls). If it doesn't open, close and reopen System Settings, then try again — it's reliable after that.

**Another known issue:** Settings menu have to be reopened completely one time so the Mac OS magically refreshes and let's you use the settings.


## Uninstall

```sh
rm -rf ~/Library/Screen\ Savers/Flying\ Windows.saver
rm -f ~/Library/Preferences/ByHost/com.rezo.FlyingWindowsSaver.*.plist
pkill -f legacyScreenSaver.appex 2>/dev/null
```

Pick a different screen saver first if "Flying Windows" is currently selected — macOS won't let you delete the active one out from under it.
