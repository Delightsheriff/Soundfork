# Decisions

Short records of choices and the evidence behind them. Newest at the bottom.

## D1: Process taps + aggregate device, no driver
Process taps (macOS 14.2+) can capture one process's output and mute the original.
An aggregate device with the destination as its main sub-device gives us an IOProc that has
the tapped audio as input and the destination as output. That's enough for per-app routing with no driver.

## D2: SwiftPM + build script instead of an Xcode project
`.pbxproj` files are hard for agents to edit safely. SwiftPM plus a script that assembles and signs
the `.app` builds entirely from the CLI.

## D3: AppKit NSPanel for the island, not MenuBarExtra
`MenuBarExtra(.window)` always opens a popover anchored under the icon. The dynamic-island look needs a
borderless panel at the top-center with custom animation.

## D4: Deployment target macOS 26, unsandboxed
Personal tool on macOS 27. Newer APIs are fine; the sandbox adds friction and buys nothing here.

## D5: Phase 1 spike results (2026-09-24, macOS 27.0, M-series MacBook Pro)
Measured with `TapSpike` (logs in `build/spike.log`):

| Test | Tap format | Aggregate | Result |
|---|---|---|---|
| Spotify (process object) → MacBook Pro Speakers, 40 s | 48 kHz, 2 ch float32 interleaved | 48 kHz, 1 in buf / 1 out buf | ~94 IOProc calls/s, peak ≈ −3 dBFS throughout, clean teardown |
| Spotify (**bundle ID**, macOS 26 API) → MacBook Pro Speakers, 15 s | same | same | same; `bundleIDs` + `isProcessRestoreEnabled` work |
| Spotify → ZEALOT-S67 Bluetooth (44.1 kHz), 15 s | 48 kHz | **44.1 kHz** | ~86 calls/s (44100/512); aggregate resamples the tap itself |

Conclusions:
- The tap is always delivered as one interleaved stereo float32 buffer; destinations here have no input streams (offset 0).
- The aggregate device with drift compensation handles 48k → 44.1k. **No resampler code needed**, pending an ear check for pitch and clicks.
- Tapping by bundle ID works. Prefer `Route.Source.bundleIDs` in the app: taps survive app relaunch without re-tapping.
  Browser helpers still need their helper bundle IDs listed (e.g. `com.google.Chrome.helper`).
- The permission prompt appeared on first tap creation (about 4 s delay before the first frames, once only).

Still open: the 30-minute listening test on the real scenario (Spotify → Bluetooth while other audio stays on the MacBook).

## D6: Name is Soundfork (2026-09-24)
"Earshot" was the first choice, but at least six macOS apps on GitHub use it, including a menu-bar EQ
and an AirPods/Bluetooth app that routes audio. "Soundfork" only matched a 2013 song-sharing site and a
Flutter plugin, with no Mac app and no audio-routing tool. It's also the icon: a tuning fork splitting one sound two ways.
Bundle ID `com.delightsheriff.Soundfork`; saved routes migrate from the old `dev.local.AudioRouter` domain.

## D7: Global shortcut is ⌃⌥⌘S
Apple's published shortcuts use ⌃⌥⌘ only for 8 (invert colors) and , / . (contrast), and nothing standard uses
⌃⌥⌘S. It's registered with Carbon `RegisterEventHotKey`, which needs no Accessibility permission and reports
a clash if another app already owns the combination; Settings shows that and lets you turn it off.

## D8: Background-first app
No Dock icon or windows (`LSUIElement`). The welcome shows once; launches at login are silent. The menu-bar icon
can be hidden, but hover, the shortcut, or the icon always stays available, and launching the app again opens the island.
