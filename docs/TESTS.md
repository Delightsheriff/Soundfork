# Manual tests

Build and launch: `./scripts/build-app.sh && open build/Soundfork.app`
Watch the logs: `log stream --level info --predicate 'subsystem == "com.delightsheriff.Soundfork"'`

| # | Setup | Action | Expect |
|---|---|---|---|
| 1 | Mac output = ZEALOT. Spotify and a Chrome YouTube video both playing | Menu → Google Chrome → MacBook Pro Speakers | Chrome moves to the laptop within about 1 s; Spotify stays on ZEALOT; icon becomes filled |
| 2 | After test 1 | Chrome → System default | Chrome back on ZEALOT |
| 3 | Mac output = MacBook Pro Speakers | Spotify → ZEALOT | Spotify on ZEALOT only, correct pitch, no clicks, over 30 min |
| 4 | Route active | Turn the ZEALOT off | Spotify falls back to the Mac speakers; row says "disconnected device" |
| 5 | After test 4 | Turn the ZEALOT back on | Route comes back by itself |
| 6 | Route active | Quit Soundfork | App goes back to the system default immediately |
| 7 ✅ | Route saved | Relaunch Soundfork | Route comes back without touching anything (verified 2026-09-24) |
| 8 | Chrome routed | Quit and reopen Chrome, play something | Still routed |
| 9 | Chrome routed and playing | Chrome submenu → drag the volume slider | Volume changes smoothly while dragging, no clicks; row shows e.g. "· 40%" |
| 10 | App on System default, playing | Drag its slider to 50% | Gets quieter on the default output (a route to the default device is created) |
| 11 | After test 10 | Drag back to 100% | Route removed; app plays directly again |
| 12 | Volume set, then device disconnected | Turn the speaker off | App falls back to the default output at the same volume |
