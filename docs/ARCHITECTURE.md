# Architecture

## Tech stack

| Concern | Choice | Why |
|---|---|---|
| Language | Swift 6.4, Swift 6 language mode | Native Core Audio access; strict concurrency catches thread bugs |
| UI | SwiftUI views hosted in AppKit windows | SwiftUI for content; AppKit for the island panel, which `MenuBarExtra` can't position or animate |
| Menu-bar icon | `NSStatusItem` with a template glyph | Full control over left/right click |
| Island window | Borderless, non-activating `NSPanel` + `NSHostingView` | Floats over the menu bar without stealing focus |
| Audio | Core Audio HAL: process taps (`CATapDescription`, `AudioHardwareCreateProcessTap`), private aggregate devices, IOProcs | The public, driver-free way to capture one app's audio and send it elsewhere |
| Real-time shared state | `Synchronization.Atomic` | Lock-free volume and meters readable from the IOProc |
| Persistence | `UserDefaults` | Routes as one JSON blob keyed by bundle ID; settings as plain keys |
| Global shortcut | Carbon `RegisterEventHotKey` | No Accessibility permission needed |
| Login item | `SMAppService.mainApp` | |
| Build | SwiftPM + `scripts/build-app.sh` | Plain-text project with no `.xcodeproj`; builds entirely from the command line |
| Deployment target | macOS 26 | Taps by bundle ID with process restore (D5) |
| Sandbox / network | Off / none | Not an App Store app; fully offline |

## Package layout

```
Sources/
├── SoundforkCore/                  # library: no UI
│   ├── CoreAudio/
│   │   ├── AudioObject+Properties.swift   # typed read/write/has helpers for AudioObject properties
│   │   ├── CoreAudioError.swift           # OSStatus → error with call name and four-char code
│   │   ├── OutputDevices.swift            # list outputs, default output, set default
│   │   ├── AudioProcesses.swift           # processes Core Audio knows about
│   │   ├── DeviceVolume.swift             # a device's own volume and mute
│   │   ├── HardwareObserver.swift         # device, default-output, process-list and restart notifications
│   │   ├── TapAggregate.swift             # tap + private aggregate + IOProc, torn down in order
│   │   ├── Route.swift                    # one app → one device, built on TapAggregate
│   │   ├── RouteRenderer.swift            # the real-time IOProc: copy + ramped gain
│   │   └── AudioCapturePermission.swift   # raises the permission prompt without changing audio
│   ├── Model/  (OutputDevice, AudioProcess, AudioApp, RoutePreference)
│   ├── AudioApps.swift                    # group helper processes under their app
│   ├── RouteManager.swift                 # owns all routes; reconciles them with preferences and hardware
│   ├── RouteStore.swift                   # persistence
│   └── AppIdentity.swift                  # bundle ID shared by logging, aggregates and self-exclusion
├── Soundfork/                      # the app: AppKit + SwiftUI
│   ├── AppDelegate.swift, main.swift, LaunchOptions.swift
│   ├── StatusItemController.swift, StatusGlyph.swift, AppInfo.swift
│   ├── Island/     (IslandController, IslandPanel, IslandModel, NotchGeometry, IslandSnapshot)
│   ├── Settings/   (AppSettings, GlobalHotKey)
│   └── Views/      (IslandView, AppRow, DeviceChip, DevicePicker, VolumeLine, PillSlider, SettingsView, WelcomeView, …)
└── TapSpike/                       # command-line diagnostic: route one app and log formats and levels
```

Only `SoundforkCore/CoreAudio/` calls the Core Audio C API.

## A route

`Route(source: .bundleIDs([...]), destination:, volume:)` sends one app's audio to one output device:

1. **Tap.** A `CATapDescription` with the app's bundle IDs (the app plus any helper processes seen playing its audio),
   `muteBehavior = .mutedWhenTapped` (the app stops playing through its normal output while we read it),
   `isProcessRestoreEnabled` (the tap re-attaches when the app relaunches), private to this process.
2. **Aggregate device.** Private, with the destination as its main sub-device and the tap in its tap list with drift
   compensation. The aggregate puts both on one clock and resamples the tap when rates differ (48 kHz app → 44.1 kHz
   Bluetooth; measured in D5).
3. **IOProc.** `RouteRenderer.render` copies the tap's stereo input to the destination's output channels, ramping gain
   linearly from the last buffer's value to the current volume. Extra output channels get silence. No allocation,
   locks or logging on this thread; volume and meters are atomics.

Teardown (`TapAggregate.stop`) always runs in the order IOProc → aggregate → tap, including after a partial setup failure.
If the app quits or crashes, the taps and aggregates die with it and every app plays normally again.

## Which apps are listed

Core Audio lists processes, not apps. `AudioApps` groups them: known owners first (`com.apple.WebKit.GPU` → Safari),
then anything with `.helper` in its bundle ID belongs to the app named before it (`com.google.Chrome.helper` → Chrome).
The island shows apps that are playing, plus any app with a saved preference; the rest sit under "Other apps".

## RouteManager

Works in the background without the UI. It reconciles whenever a preference changes, devices come or go, the default
output changes, a device finishes settling, or the Mac wakes.

```
devices  = OutputDevices.all()                         # once per reconcile
settled  = devices connected for at least 1.5 s        # Bluetooth needs a moment after connecting
for each preference:
    target = chosen device if settled, else the default output
for each live route:
    same target and same tap bundle IDs → keep it (update volume)
    otherwise → build the replacement first, then stop the old route (no gap on the wrong device)
```

A device disconnecting sends its apps to the default output at their own volume; they move back when it reconnects.
A preference of "System default at 100%" is removed rather than routed. Other triggers:

- **Process list changed:** newly seen helper bundle IDs are added to routed apps' taps (browsers spawn helpers).
- **coreaudiod restarted:** every route is rebuilt, since all object IDs are stale.
- **Wake:** every route is rebuilt once devices have had the settle delay.

Volume changes during a slider drag go straight to the renderer's atomic; saving is batched.

## Island UI

- `IslandController` owns the `IslandPanel` (level above the main menu, all Spaces, full-screen auxiliary). It opens on a
  status-item click, the ⌃⌥⌘S shortcut, relaunching the app, or the pointer resting on the notch (polled at 10 Hz in the
  default run-loop mode, so it pauses while menus track). Hover-opened islands close when the pointer leaves; others close
  on an outside click or Esc.
- `IslandView` is black, grows from the notch's size (from `NSScreen.auxiliaryTopLeftArea`/`auxiliaryTopRightArea`) with
  a spring, and has three pages: apps, settings, welcome.
- `IslandModel` refreshes from Core Audio every 0.5 s while open, publishing only values that changed. Where an app is
  "actually playing" comes from `RouteManager.currentDestination`, not recomputed in the UI.

## Threads

- Main actor: UI, `RouteManager`, all route creation and teardown, hardware notifications.
- The permission probe runs off the main thread, because tap creation blocks until the user answers the prompt.
- IOProcs: Core Audio's real-time thread; they touch only buffers and atomics.
