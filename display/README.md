# Experimental fullscreen display helper

Build with `python3 build.py --output /your/output/MapleRoyals-Display.app`, then open the generated app in Finder. The app does not change the display until its Test button is pressed.

Add `--refresh-hz 120` to build the 120 Hz comparison used on this M1 Pro's 120 Hz panel. Both source variants compiled and signed locally; the build recipe was also compiled and signed for the 60 Hz variant. Do not run both helpers' display tests at once.

It creates a non-HiDPI 1024×768 virtual display at 60 Hz, and requests mirroring from that display to the built-in panel. The initial test restores after 20 seconds. Keep cancels that timer; Restore or quitting releases the virtual display and reapplies the previous physical display mode. This changes the whole Mac display presentation for the session; the game's internal resolution is a separate setting. On this M1 Pro, 800×600 is the user-confirmed smoother, playable option. 1024×768 works but remains laggy.

Local test: macOS 26.5.2 accepted creation and mirroring, and automatic restoration returned success. In the longer trial, the user confirmed correct fullscreen presentation with side bars, but 1024×768 still lagged. Read ../docs/RESEARCH.md for current results.

At 60 Hz, a later comparison made the two resolutions feel similar while some lag remained; the user was unsure whether 800×600 had become worse. Changing the same running game to the 120 Hz virtual display restored the perceived difference: 800×600 felt smoother and 1024×768 still lagged. This does not establish a rendering-performance fix. A fresh game launch under 120 Hz was subsequently tested and did not remove the difference. The final main app uses CX24/OpenGL with MSync on, CSMT off and quiet logging; 800×600 remains smoother.

The implementation uses private CoreGraphics APIs. Compatibility with other macOS versions, multiple external displays, process crashes, sleep/wake and production signing are not validated. This is separate experimental scaffolding, not yet integrated into MapleRoyals.app. The reused declarations and their MIT notice are included here. No game or Wine assets are included.

The builder targets Apple silicon and macOS 14 or newer. Logs are saved under `~/Library/Application Support/MapleRoyalsLauncher/logs`, so the app can live in Applications without writing beside itself. Other Mac/macOS combinations remain unvalidated.
