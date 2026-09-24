# Plan

**Active phase: 6** (lifecycle hardening). Phases 0–5 done: engine, discovery, island UI, persistence. Per-app volume, gain smoothing, make-before-break switching, and notch hover shipped early.

## How we work

Prompt files in `prompts/` are optional handoff notes now; the listen-and-review loop stays the same.

Three roles:

| Who | Does |
|---|---|
| **You (human)** | Listen. Report what you hear, check permission prompts, plug in and unplug devices. Nobody else can verify audio. |
| **Builder agents (Fable, etc.)** | Carry out one prompt file at a time, in a fresh session opened in this folder. They stop at the acceptance criteria and report back. |

The loop for each phase:
```
Lead writes prompts/NN-*.md
   → you open a builder session here and paste: "Do prompts/NN-*.md"
   → builder implements and reports
   → you run it and say what you hear
   → Lead reviews the code and your report → fix / re-prompt / mark done → next phase
```

Phase 1 (the audio spike) is the riskiest step and needs short debug loops, so the Lead does it directly
instead of handing it off. After that, UI and discovery can run in parallel builder sessions,
because they touch separate folders.

## Phases

### Phase 0: Scaffold (Lead)
- `Package.swift` with the `SoundforkCore`, `Soundfork` and `TapSpike` targets
- `Resources/Info.plist` and `scripts/build-app.sh` (build → .app → codesign)
- **Done when** `./scripts/build-app.sh` produces a signed app that launches and shows a menu-bar icon.

### Phase 1: Tap spike (Lead) · go/no-go
- `TapSpike`: hard-coded Spotify → the Bluetooth speaker, using `Route.swift` as specified in ARCHITECTURE.md.
- Log the tap format, destination format, and IOProc calls per second.
- Answer the open questions: different sample rates (48k tap → 44.1k Bluetooth)? `CATapDescription` by bundle ID on macOS 26+?
- **Done when** Spotify plays only on the speaker while YouTube plays on the Mac speakers,
  for 30 minutes with no clicks, drift or growing latency. Stopping the spike returns Spotify to normal output,
  and no leftover aggregate device appears in Audio MIDI Setup.
- **If it fails:** stop, write up findings in `docs/DECISIONS.md`, and rethink before building anything else.

### Phase 2: Core engine (builder)
- Extract `Route`, `OutputDevices` and `AudioProcesses` from the spike into `SoundforkCore`.
- Run several routes at once (Spotify → speaker, Chrome → Mac, Discord → AirPods).
- **Done when** three routes play simultaneously and start/stop in any order without glitches or leaks.

### Phase 3: Discovery and grouping (builder) · can run parallel to Phase 4
- Group helper processes into `AudioApp`s (see ARCHITECTURE.md → discovery). Add unit tests for the grouping table and fallback logic.
- **Done when** Safari, Chrome, Spotify, Discord and Music each show up as one app while playing, and the list updates live.

### Phase 4: Island UI (builder) · can run parallel to Phase 3, against mock data
- Status item, `IslandPanel`, and SwiftUI views driven by a protocol plus a mock data source.
- **Done when** the island expands and collapses smoothly from the top-center (and the notch, if present), dismisses correctly, and works across Spaces and full-screen apps.

### Phase 5: Wire up and persist (Lead or builder)
- `RouteManager.reconcile()`, `RouteStore`, connecting the UI to the real engine.
- **Done when** choosing a device routes the app instantly, choosing "System default" un-routes it, and routes come back after the app relaunches.

### Phase 6: Lifecycle hardening (builder + you testing)
- Bluetooth disconnect and reconnect, app quit and relaunch, browser helper churn, sleep/wake, default device changes.
- **Done when** the manual test checklist (to be written in `docs/TESTS.md`) passes.

### Phase 7: Polish (optional)
Per-app volume and mute UI, launch at login (`SMAppService`), device icons by transport type, error states in rows.

## Out of scope for v1
EQ and effects, recording, notch-hover activation, App Store distribution, per-tab browser routing.
