# Roadmap

## Done (v1.0.0)

- **Routing engine:** Core Audio process tap → private aggregate device → real-time IOProc, one per routed app.
  Proven with `TapSpike` before any UI was built (results in [DECISIONS.md](DECISIONS.md), D5).
- **App discovery:** helper processes grouped under their app; any app playing audio shows up.
- **Per-app output, volume and mute,** persisted by bundle ID and device UID. Volume ramps smoothly,
  and switching devices starts the new route before stopping the old one.
- **Lifecycle:** device disconnect falls back to the default output; reconnect restores the route after a
  1.5 s settle; routes rebuild after wake and after coreaudiod restarts; user aggregate / Multi-Output devices work.
- **Island UI:** opens from the notch (hover), the ⌃⌥⌘S shortcut or the menu-bar icon; inline device
  pickers; Output section with device switching and main volume.
- **App shell:** one-time welcome, in-island settings, open at login, hideable menu-bar icon, app icon.
- **Engineering:** unit tests for route planning, settling, the renderer and persistence; CI on every push;
  hardened runtime; universal release zip via `scripts/release.sh`.

## Next

1. **macOS 14.4+ support.** Tapping by bundle ID needs macOS 26; older systems need process-object taps,
   re-created when an app relaunches or spawns helpers (`Route.Source.processes` already exists). Start with
   a design spike: TapSpike on a macOS 14/15 machine, and an audit of newer SwiftUI/AppKit APIs.

## Maybe later

- Volume control for the device an app is routed to, not only the default output (move device control out of
  `IslandModel` into Core first).
- Output level meters on routed apps (`RouteRenderer` already measures peaks).
- Developer ID signing and notarization, so downloads open without the "Open Anyway" step.
- Routing one app to several devices at once.

## Out of scope

EQ and effects, recording, per-tab browser routing, App Store distribution.
