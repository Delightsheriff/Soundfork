# Architecture

## Tech stack

| Concern | Choice | Why |
|---|---|---|
| Language | Swift 6.4, Swift 6 language mode | Native, first-class Core Audio access, strict concurrency catches thread bugs |
| UI | SwiftUI views hosted in AppKit windows | SwiftUI for the content; AppKit for the island window, which SwiftUI's `MenuBarExtra` can't position or animate |
| Menu-bar icon | `NSStatusItem` | Full control over click handling (MenuBarExtra always opens its own popover) |
| Island window | Borderless, non-activating `NSPanel` + `NSHostingView` | Floats above everything at top-center without stealing focus |
| Audio | Core Audio HAL C API (`AudioHardwareCreateProcessTap`, `CATapDescription`, `AudioHardwareCreateAggregateDevice`, `AudioDeviceCreateIOProcIDWithBlock`) | The only public, driver-free way to capture and redirect a single app's audio |
| Real-time shared state | `Synchronization.Atomic` (stdlib) | Lock-free volume/mute/counters readable from the IOProc |
| Persistence | `UserDefaults` (one Codable blob) | Tiny data: `[bundleID: RoutePreference]` |
| Build | SwiftPM package + `scripts/build-app.sh` | No `.xcodeproj` for agents to corrupt; builds from the CLI |
| Signing | "Apple Development" identity already in the keychain | Stable signature so the audio-capture permission persists between builds |
| Deployment target | macOS 26 | Personal tool on a macOS 27 machine; lets us use the newest tap APIs |
| Sandbox | Off | Not shipping to the App Store; avoids sandbox restrictions on taps and aggregate devices |
| Network | None | Fully offline |

Info.plist keys: `LSUIElement = YES` (no Dock icon), `NSAudioCaptureUsageDescription` (required for taps),
`CFBundleIdentifier = com.delightsheriff.Soundfork`.

## Package layout

```
Soundfork/
├── Package.swift
├── Resources/Info.plist
├── scripts/build-app.sh            # swift build -c release → assemble .app → codesign
├── Sources/
│   ├── SoundforkCore/            # library: no UI, testable
│   │   ├── CoreAudio/
│   │   │   ├── CoreAudioError.swift
│   │   │   ├── AudioObject+Properties.swift   # typed get/set helpers for AudioObjectGetPropertyData
│   │   │   ├── OutputDevices.swift            # list outputs, observe add/remove, default device
│   │   │   ├── AudioProcesses.swift           # list audio processes, observe changes
│   │   │   └── Route.swift                    # tap + aggregate + IOProc lifecycle
│   │   ├── Model/
│   │   │   ├── OutputDevice.swift             # uid, name, objectID, transport (bluetooth/builtin/...)
│   │   │   ├── AudioApp.swift                 # bundleID, name, icon, processObjectIDs, isPlaying
│   │   │   └── RoutePreference.swift          # deviceUID, volume, muted
│   │   ├── RouteManager.swift                 # @MainActor; owns [bundleID: Route], reconciles
│   │   └── RouteStore.swift                   # UserDefaults persistence
│   ├── Soundfork/             # executable: AppKit + SwiftUI
│   │   ├── main.swift / AppDelegate.swift
│   │   ├── StatusItemController.swift
│   │   ├── IslandPanel.swift                  # NSPanel subclass + positioning
│   │   └── Views/ (IslandView, AppRow, DevicePicker)
│   └── TapSpike/                   # Phase 1 only: hard-coded single route, deleted later
└── Tests/SoundforkCoreTests/     # pure logic only (grouping, reconciliation, persistence)
```

## Audio engine: one route

A `Route` moves one app's audio to one output device.

```
start(processObjectIDs, destinationUID)
  1. tapDesc = CATapDescription(stereoMixdownOfProcesses: processObjectIDs)
     tapDesc.muteBehavior = .mutedWhenTapped
     tapDesc.isPrivate = true
  2. AudioHardwareCreateProcessTap(tapDesc) → tapID
  3. read kAudioTapPropertyFormat (log it)
  4. AudioHardwareCreateAggregateDevice([
        UID: "com.delightsheriff.Soundfork.route.<uuid>",
        IsPrivate: true,
        MainSubDevice: destinationUID,
        SubDeviceList: [[UID: destinationUID]],
        TapList: [[UID: tapDesc.uuid, DriftCompensation: true]],
        TapAutoStart: true ]) → aggregateID
  5. AudioDeviceCreateIOProcIDWithBlock(aggregateID) { inInput, outOutput in
        copy input buffers → output buffers, × volume (atomic); zero output if muted
     }
  6. AudioDeviceStart(aggregateID, ioProcID)

stop()   (reverse order, always runs even if start partly failed)
  AudioDeviceStop → AudioDeviceDestroyIOProcID → AudioHardwareDestroyAggregateDevice → AudioHardwareDestroyProcessTap
```

The aggregate device puts the tap and the destination on one clock. Drift compensation handles
small rate differences. **Open question for the spike:** does this also cover different sample rates
(tap at 48 kHz, Bluetooth at 44.1 kHz)? If not, we add an `AudioConverter` step, still in the IOProc
path but pre-allocated.

Channel mapping: the tap is a stereo mixdown. If the destination has a different channel count,
copy L/R into the first two output channels and zero the rest.

## App ↔ audio process discovery

Core Audio lists processes, not apps (`kAudioHardwarePropertyProcessObjectList`). For each process object read
`kAudioProcessPropertyBundleID`, `kAudioProcessPropertyPID` and `kAudioProcessPropertyIsRunningOutput`.

Group helper processes under the app the user recognizes:

1. Look up the bundle ID in a table of known helpers: `com.apple.WebKit.GPU` → Safari,
   `com.google.Chrome.helper*` → Chrome, `com.microsoft.edgemac.helper*` → Edge,
   `com.hnc.Discord.helper*` → Discord, and similar.
2. Otherwise, strip `.helper…` suffixes and match a running `NSRunningApplication`.
3. Otherwise, walk up the parent PID until we reach an app with a bundle.

A route taps **all** process objects in the group. Browsers start new helper processes, so the
`RouteManager` must rebuild a route when a group's process set changes.
**Check in the spike:** macOS 26+ may let `CATapDescription` target bundle IDs directly. If that works,
most of this re-tapping goes away.

Note: `com.apple.WebKit.GPU` is shared by all WebKit apps (Safari, Mail, etc.). Routing "Safari" moves them all. That's acceptable for v1; say so in the UI.

## RouteManager: reconciliation loop

One `@MainActor` function, `reconcile()`, runs whenever any of these change: the process list,
the device list, a user preference, or the Mac wakes from sleep.

```
for each (bundleID, pref) in store:
    group    = running audio processes for bundleID
    device   = output device with pref.deviceUID
    desired  = (group non-empty && device present) ? (group.objectIDs, device.uid) : nil
    current  = routes[bundleID]
    if desired == current's config: continue
    current?.stop()
    routes[bundleID] = desired.map { Route.start(...) }   // on failure: log, mark error, leave nil
```

This single loop covers reconnecting Bluetooth, apps quitting and relaunching, and helper churn,
with no special cases. When the device is missing the route is simply absent, and the app falls
back to the system output on its own.

## Dynamic island UI

**Menu-bar icon:** an SF Symbol (`hifispeaker.2`), filled when at least one route is active. Clicking it toggles the island.

**Island panel:**
- `NSPanel` with `styleMask: [.borderless, .nonactivatingPanel]`, `level = .statusBar`,
  `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, transparent background,
  `hasShadow = true`.
- Anchored to the top-center of the screen that has the menu bar. On notched Macs, the collapsed pill
  matches the notch width (`NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea`), so it grows out of the notch.
- States: **collapsed** (notch-sized black pill, invisible) → **expanded** (about 360 × auto height,
  rounded 24pt, black background, white text). SwiftUI `.spring(response: 0.35, dampingFraction: 0.8)` on the frame
  and corner radius, with content fading in after the expansion begins.
- Dismiss: click outside (global `NSEvent` monitor), Esc, or clicking the icon again.

**Expanded content:**
```
╭──────────────────────────────────────────╮
│  🎵 Spotify        [🔵 JBL Flip 6    ▾]  │
│     ━━━━━━━━━━━━━━━━━━━━━━●──────  72%    │
│  🌐 Chrome         [System default   ▾]  │
│  💬 Discord        [🎧 AirPods       ▾]  │
│     ⚠ AirPods disconnected, using default │
│ ──────────────────────────────────────── │
│  Show all apps              Quit         │
╰──────────────────────────────────────────╯
```
Rows show apps currently playing audio plus any app that has a saved rule. "System default" means no route.
The volume slider only appears on routed apps (v1).

v2 idea (not in v1): open the island by hovering over the notch, and show a slim "live activity"
pill while a route is active.

## Threads

- Main actor: UI, `RouteManager`, `RouteStore`, all create/destroy calls.
- Core Audio listener callbacks (`AudioObjectAddPropertyListenerBlock`): register them on the main queue.
- IOProc: Core Audio's real-time thread. It touches only the buffers and atomics captured when the route was created.
