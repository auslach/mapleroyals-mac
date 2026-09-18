# Combined launcher and fullscreen controls (0.7.0)

The player ZIP now contains one **MapleRoyals.app**. Its native UI manages the game and optional fullscreen scaling. The older separate display helpers remain as developer source but are no longer packaged for players.

## Player behavior

- The first opening shows display options without launching the game. Default: **Normal Mac display**.
- Choices: normal display, fullscreen scaling at **800×600**, or fullscreen scaling at **1024×768**. Fullscreen offers **60 Hz** and **120 Hz**.
- **Play** prepares the display before starting the unchanged CX24/OpenGL game. For a new display/mode combination, a 20-second **Keep & Play** test runs first. Timeout, cancellation or quitting during the preview restores the display and does not start the game.
- After confirmation, the app remembers the mode. **Start automatically next time**, enabled by default, reuses saved settings on later openings. Uncheck it to stop at the options screen each time.
- The app restores its display when the game session finishes or startup fails. A **Restore normal display** button is also available during gameplay. Quit the game before changing mode or closing the launcher.
- Game resolution remains a game setting. Use 800×600 in the game with the 800×600 display choice, and Option+Return if its window borders are still visible.

Fullscreen still scales the entire Mac desktop while active. This does not implement game-only stretching or fix 1024×768 rendering performance.

## Implementation

`portable/GameDisplay.swift` owns the virtual display, original physical mode and cancellation generation. It uses the same private CoreGraphics declarations as the earlier DeskPad-derived helper. UI state and display work run on the AppKit thread; setup and Wine run on the existing worker queue. The app links only Apple's frameworks and provisions the pinned Wine runtime as before.

`play-preferences.json` lives beside `installation.json` in the user's Application Support directory. It stores the selected mode, refresh rate, auto-launch setting and confirmation keys (physical display UUID, macOS major version, size and refresh rate). The file is not bundled or committed. The existing installed game, runtime, prefix and registry settings are reused.

The game launch command remains:

```json
["explorer", "/desktop=MapleRoyals,1024x768", "C:\\MapleRoyals\\MapleRoyals.exe"]
```

Wine's virtual desktop argument is separate from the Mac display scaling selection. The known CX24/MSync/OpenGL/CSMT settings are unchanged. No CrossOver application or new compatibility layer is required.

## Validation

On the original M1 Pro, macOS 27.0:

- Built version 0.7.0 and inspected the combined UI through computer use. The window fits on the 800×600 test display; display/rate controls lock during a session.
- At 800×600/60 Hz, the first-use prompt appeared; after 20 seconds, it returned to normal display without launching the game. The log recorded successful unmirroring, physical-mode restoration and completion.
- At 800×600/120 Hz, Keep & Play started the pinned Wine runtime after the display was mirrored. Logs confirmed the Explorer-first command, MSync, CSMT 0 and OpenGL. At session end, Wine and its server wait both exited successfully; the launcher automatically unmirrored and restored the previous physical mode (all three return codes were 0). Computer use verified the launcher returned to its idle state with the restored-display message. This check did not independently verify character loading or repeat gameplay acceptance for 0.7.0.
- Existing core checks passed: integrity, invalid installer rejection, exclusive ownership, portable paths, environment isolation and existing-data preservation.

A second Mac, all size/rate combinations, forced termination, disconnects, sleep/wake and performance improvements are not established by these checks. The display implementation uses private APIs; unusual display configurations may require restoring settings manually in System Settings. No game assets, Wine binaries, used prefixes or user preferences are shipped in the ZIP.
