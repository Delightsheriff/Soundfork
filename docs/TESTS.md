# Manual tests

The audio path can't be unit-tested end to end, so these are checked by ear before a release.
`swift test` covers the logic underneath (route planning, settling, the renderer, persistence).

Build and install: `./scripts/install.sh`
Watch the logs: `log stream --level info --predicate 'subsystem == "com.delightsheriff.Soundfork"'`

"Open the island" means: rest the pointer on the notch, press ⌃⌥⌘S, or click the fork icon in the menu bar.

## First launch

| # | Setup | Action | Expect |
|---|---|---|---|
| 1 | Settings cleared (`defaults delete com.delightsheriff.Soundfork`) | Launch Soundfork | Welcome grows out of the notch: intro → Allow audio access → Open at login |
| 2 | Welcome step 2 | Allow Access | macOS asks once (if it hasn't already); the step shows a checkmark; nothing you're listening to changes |
| 3 | Welcome step 3 | Done with Open at login on | Soundfork appears in System Settings → General → Login Items |
| 4 | Welcome finished | Quit and relaunch | No welcome; nothing opens by itself |

## Opening and closing

| # | Setup | Action | Expect |
|---|---|---|---|
| 5 | Island closed | Rest the pointer on the notch | Opens after a short pause; moving away closes it after about half a second |
| 6 | Island closed | ⌃⌥⌘S | Opens; stays open until an outside click, Esc, or ⌃⌥⌘S again |
| 7 | Island open | Click another app, or Esc | Closes smoothly; the other app keeps focus |
| 8 | A full-screen app in front | Open the island | Appears over it |
| 9 | Settings → Show menu-bar icon off | Launch Soundfork again from Spotlight | The island opens |

## Routing

| # | Setup | Action | Expect |
|---|---|---|---|
| 10 | Mac output = Bluetooth speaker. Spotify and a Chrome video playing | Chrome's device chip → MacBook Pro Speakers | Chrome moves to the laptop within about 1 s; Spotify stays on the speaker; the menu-bar fork shows waves |
| 11 | After 10 | Chrome's chip → System default | Chrome back on the speaker |
| 12 | Mac output = MacBook Pro Speakers | Spotify → Bluetooth speaker, listen 30 min | Spotify only on the speaker, correct pitch, no clicks or drift |
| 13 | Chrome routed | Quit and reopen Chrome, play something | Still routed |
| 14 | An app routed to a headset with a microphone (AirPods, earbuds) | Play audio | Stays high quality (not "call" quality); the headset's mic indicator doesn't turn on. ✅ Passed with Bluetooth earbuds, 2026-09-24 |

## Volume and mute

| # | Setup | Action | Expect |
|---|---|---|---|
| 15 | An app playing | Drag its slider | Volume changes smoothly with no clicks; the percentage follows |
| 16 | An app on System default | Drag to 50%, then back to 100% and let go | Quieter while below 100%; at 100% it plays directly again. Wiggling near the top while dragging causes no dropouts |
| 17 | An app playing | Click the speaker icon on its row | The app fades to silence, the icon turns orange, the row shows "Muted"; others keep playing |
| 18 | After 17 | Click the icon again, or drag the slider | Fades back in at its previous volume |
| 19 | Output section | Drag the main volume, press the keyboard volume keys | Slider and keys stay in sync; app volumes scale within it |

## Devices coming and going

| # | Setup | Action | Expect |
|---|---|---|---|
| 20 | An app routed to the Bluetooth speaker | Turn the speaker off | The app moves to the default output at its own volume; its row explains it's playing elsewhere |
| 21 | After 20 | Turn the speaker back on | About 1.5 s after it connects, the app moves back |
| 22 | Routes active | Sleep the Mac, wake it | Routes come back within a few seconds |
| 23 | Output section | Pick another output device | The Mac's default output changes; apps on System default follow it |

## Persistence and reset

| # | Setup | Action | Expect |
|---|---|---|---|
| 24 | Routes and volumes set | Quit Soundfork | Every app immediately plays normally again |
| 25 | After 24 | Launch Soundfork | The same routes and volumes come back with no interaction, and the app doesn't freeze even if macOS asks for audio access |
| 26 | Routes set | Reset all | Every app back to default |
