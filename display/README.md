# Experimental fullscreen display helper

Players using the compiled ZIP should follow the [fullscreen instructions in the player guide](../docs/PLAYER_GUIDE.md#fullscreen-with-black-side-bars). The notes below are for developers building or changing the helper.

Build with `python3 build.py --output /your/output/MapleRoyals-Display.app`, then open the generated app in Finder. The app does not change the display until its Test button is pressed.

The refresh rate is supplied through `MapleRoyalsRefreshRate` in the app Info.plist; both builds compile the same Swift source. Add `--refresh-hz 120` to build the 120 Hz comparison used on this M1 Pro's 120 Hz panel. Both source variants compiled and signed locally; the build recipe was also compiled and signed for the 60 Hz variant. Do not run both helpers' display tests at once.

Version 0.2 offers **800×600** and **1024×768** in a Resolution menu, defaulting to 1024×768. Restore the display before changing the selection. It creates the selected non-HiDPI virtual display at 60 Hz (120 Hz in that build), and requests mirroring from that display to the built-in panel. The initial test restores after 20 seconds. Keep cancels that timer; Restore or quitting releases the virtual display and reapplies the previous physical display mode. This changes the whole Mac display presentation for the session; the game's internal resolution is a separate setting. On this M1 Pro, 800×600 is the user-confirmed smoother, playable option. 1024×768 works but remains laggy.

Local test: macOS 26.5.2 accepted creation and mirroring, and automatic restoration returned success. In the longer trial, the user confirmed correct fullscreen presentation with side bars, but 1024×768 still lagged. Read ../docs/RESEARCH.md for current results.

At 60 Hz, a later comparison made the two resolutions feel similar while some lag remained; the user was unsure whether 800×600 had become worse. Changing the same running game to the 120 Hz virtual display restored the perceived difference: 800×600 felt smoother and 1024×768 still lagged. This does not establish a rendering-performance fix. A fresh game launch under 120 Hz was subsequently tested and did not remove the difference. The final main app uses CX24/OpenGL with MSync on, CSMT off and quiet logging; 800×600 remains smoother.

The implementation uses private CoreGraphics APIs. Compatibility with other macOS versions, multiple external displays, process crashes, sleep/wake and production signing are not validated. This is separate experimental scaffolding, not yet integrated into MapleRoyals.app. The reused declarations and their MIT notice are included here. No game or Wine assets are included.

The builder targets Apple silicon and macOS 14 or newer. Logs are saved under `~/Library/Application Support/MapleRoyalsLauncher/logs`, so the app can live in Applications without writing beside itself. Other Mac/macOS combinations remain unvalidated.

The 800×600 helper mode does not change the game resolution. Select 800×600 in the game as well so its window fits. A performance benefit from the new display mode has not been established.

Version 0.2 validation (September 17, 2026): both refresh-rate builds compiled and signed, both resolution menus were checked with computer use, and the 60 Hz Test button followed the selected size. The user activated and kept 800×600 at 120 Hz on macOS 27; the UI showed that mode active, and creation, mirroring and restoration returned success in the log. Fullscreen appearance and performance have not been separately confirmed. Other size/rate combinations in version 0.2 remain untested live.
