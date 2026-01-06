## Pomafocus

A lightweight macOS menu bar Pomodoro timer with configurable session length and a global hotkey toggle.

### Running

```sh
swift run
```

### Bundling into an `.app`

Create a distributable app bundle (with Info.plist and icon) by running:

```sh
./Scripts/build_app.sh
```

The script outputs `dist/Pomafocus.app`, which you can drag into `/Applications`. The bundle inherits the accessory-style behavior (dock-less window) from the executable, so it lives solely in the menu bar once launched.
*** End Patch*** End Patch
