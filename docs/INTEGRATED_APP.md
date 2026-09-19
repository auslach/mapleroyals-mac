# Combined launcher and fullscreen controls (0.7.2)

The player ZIP now contains one **MapleRoyals.app**. Its native UI manages the game and optional fullscreen scaling. The older separate display helpers remain as developer source but are no longer packaged for players.

## Player behavior

- Every opening selects **800×600** without changing the screen or starting Wine. Old auto-launch preferences are ignored.
- Choices: normal display, fullscreen scaling at **800×600**, or fullscreen scaling at **1024×768**. Fullscreen offers **60 Hz** and **120 Hz**. Menu changes alone have no display side effects.
- **Change screen resolution** applies the choice. A new display/mode combination gets a 20-second **Keep resolution** test. Timeout, cancellation or quitting during preview restores the display. Confirmation finishes only the display change; an existing game keeps running.
- **Play** starts only the unchanged CX24/OpenGL game using the current screen. It never applies the pending display choice. Skipping the resolution button keeps the normal Mac display.
- **Install game** prepares a first installation and returns to Ready; it does not start the game.
- The app restores its display when the game session finishes, startup fails or the idle launcher quits. A **Restore normal display** button is available before and during gameplay. Size, refresh rate and Change screen resolution also stay available while the game runs; they pause only while a display change is being applied or confirmed.
- Game resolution remains a game setting. Use 800×600 in the game with the 800×600 display choice, and Option+Return if its window borders are still visible.

Fullscreen still scales the entire Mac desktop while active. This does not implement game-only stretching or fix 1024×768 rendering performance.

## Implementation

`portable/GameDisplay.swift` owns the virtual display, original physical mode and cancellation generation. It uses the same private CoreGraphics declarations as the earlier DeskPad-derived helper. Game-worker activity and display preparation have independent state. Completing or canceling a display operation cannot enable a second Play or release prefix ownership; game exit cancels a pending display operation. UI state and display work run on the AppKit thread; setup and Wine run on the existing worker queue. The app links only Apple's frameworks and provisions the pinned Wine runtime as before.

`play-preferences.json` lives beside `installation.json` in the user's Application Support directory. It stores the refresh rate and confirmation keys (physical display UUID, macOS major version, size and refresh rate). The file is not bundled or committed. The existing installed game, runtime, prefix and registry settings are reused.

The game launch command remains:

```json
["explorer", "/desktop=MapleRoyals,1024x768", "C:\\MapleRoyals\\MapleRoyals.exe"]
```

Wine's virtual desktop argument is separate from the Mac display scaling selection. The known CX24/MSync/OpenGL/CSMT settings are unchanged. No CrossOver application or new compatibility layer is required.

## Historical validation: 0.7.0

On the original M1 Pro, macOS 27.0:

- Built version 0.7.0 and inspected the combined UI through computer use. The window fits on the 800×600 test display; display/rate controls lock during a session.
- At 800×600/60 Hz, the first-use prompt appeared; after 20 seconds, it returned to normal display without launching the game. The log recorded successful unmirroring, physical-mode restoration and completion.
- At 800×600/120 Hz, Keep & Play started the pinned Wine runtime after the display was mirrored. Logs confirmed the Explorer-first command, MSync, CSMT 0 and OpenGL. At session end, Wine and its server wait both exited successfully; the launcher automatically unmirrored and restored the previous physical mode (all three return codes were 0). Computer use verified the launcher returned to its idle state with the restored-display message. This check did not independently verify character loading or repeat gameplay acceptance for 0.7.0.
- Existing core checks passed: integrity, invalid installer rejection, exclusive ownership, portable paths, environment isolation and existing-data preservation.

A second Mac, all size/rate combinations, forced termination, disconnects, sleep/wake and performance improvements are not established by these checks. The display implementation uses private APIs; unusual display configurations may require restoring settings manually in System Settings. No game assets, Wine binaries, used prefixes or user preferences are shipped in the ZIP.

## Validation: 0.7.1

The 0.7.1 checks are recorded separately from the earlier automatic-launch version. The runtime, renderer and game command are unchanged.

On the original M1 Pro/macOS 27, computer use verified:

- Opening with legacy auto-launch preferences present stayed idle at 800×600. The log contained only the launcher-open event, with no display creation or Wine command.
- Selecting 1024×768 alone left the display unchanged. Reopening returned the selection to 800×600 and still did not start anything.
- Change screen resolution applied the previously confirmed 800×600/120 Hz mode and returned to idle with Play available. No Wine command ran.
- A new 800×600/60 Hz mode showed Keep resolution with Play disabled during the test. Keeping it returned to idle without starting Wine.
- Restore normal display before gameplay and quitting an idle launcher with an applied display both restored the original mode; unmirror, mode and completion return codes were all 0.

The Swift build and bundle signature checks passed. These 0.7.1 checks intentionally exercised the launcher without starting the game; they do not constitute a new gameplay acceptance run or a fresh-install test. Game execution and the runtime remain unchanged from the previous version.

## Validation: 0.7.2

On the original M1 Pro/macOS 27, one explicit Play started the unchanged CX24/OpenGL game process. Computer use then exercised the display controls while that session remained active:

- Applied 800×600/120 Hz, then selected and applied 1024×768/120 Hz and kept its new-mode confirmation.
- Restored the normal display without ending the game session.
- Applied an unconfirmed 1024×768/60 Hz mode, then canceled its preview. Display controls became available again and Play remained disabled.
- The log contained exactly one Wine game-launch command throughout these changes, with no intervening game exit. Every mirror, unmirror and mode-restoration operation returned success (0).

The app compiled and its signatures verified. These checks establish the launcher controls and continued process lifetime; they do not independently establish character/map rendering after each switch or performance. The game’s own resolution must still be changed separately. Gameplay after switching and failure/exit races need further coverage; the implementation preserves the game lock on display failure and cancels pending display work on game exit.
