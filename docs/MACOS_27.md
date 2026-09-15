# macOS 27 startup investigation

On September 15, 2026, the original M1 Pro MacBook Pro was upgraded from macOS 26.5.2 to **macOS 27.0 (26A428)**. Launcher 0.6.0 opened, but no game window appeared. Version **0.6.1** changes the launch order to initialize Wine's desktop before starting the game. It retains the existing runtime, installed game, registry settings and renderer.

## What the evidence shows

- Rosetta executes Intel binaries: `arch -x86_64 /usr/bin/uname -m` returned `x86_64`. The pinned Wine executable returned `wine-9.0 (KegworksCX 24.0.7)`. The update did not remove all Intel execution support.
- The old launcher log recorded Wine starting, MSync initializing, and exit status 0 with no game window. Quiet logging concealed the actual window initialization error. An earlier attempt to open the Intel Compatibility helper also produced a Launch Services error; subsequent Intel execution worked. That earlier helper error is not established as the cause of the game failure.
- A diagnostic run used an APFS clone of the existing prefix, the same runtime and settings, and additional Wine error/process/module/window logging. The original installation was preserved.
- Direct game launch started Explorer at log timestamp `6230.209`. The game reported `Application tried to create a window, but no driver could be loaded` and `The explorer process failed to start` at `6241.352`, then exited with status 0. Explorer reached `macdrv_SetDesktopWindow` at `6244.234`, after the game had exited.
- Launching Explorer explicitly with the game as its child initialized the window system before the game. The log reached builtin D3D8/WineD3D/OpenGL initialization, and the user confirmed the visible login screen and that the game worked.

These observations support a **startup ordering/timing failure**. They do not identify the macOS subsystem responsible for the slower initialization, prove an upstream macOS defect, or establish that every macOS 27 Mac needs the workaround. The earlier character-selection failure and 1024×768 performance limitation are separate issues.

The first diagnostic run also spent time in early Wine initialization before logging began. A process sample showed an `open()` wait; it later progressed without intervention. Its exact cause was not established. It should not be conflated with the later, logged window initialization failure.

## Reproducible configuration

The native launcher sets the game directory as its working directory and passes this argument array to the pinned `bin/wine`:

```json
["explorer", "/desktop=MapleRoyals,1024x768", "C:\\MapleRoyals\\MapleRoyals.exe"]
```

The existing portable data root is `~/Library/Application Support/MapleRoyalsLauncher`. Its runtime ID remains `cx24-0.7_5-template-1.0.15`.

| Item | Setting |
|---|---|
| Runtime | Sikarugir/Kegworks `WS12WineCX24.0.7_5` and Template 1.0.15 native libraries |
| Prefix | Existing `prefixes/cx24-0.7_5-template-1.0.15`; `WINEARCH=win64`; WoW64 for the 32-bit game |
| Windows version | Windows 7 |
| Renderer | Builtin D3D8 → WineD3D → OpenGL |
| Direct3D registry | `renderer=gl`; `csmt` DWORD 0 |
| Synchronization | `WINEMSYNC=1`, `WINEESYNC=0` |
| DLL overrides | `WINEDLLOVERRIDES=mscoree,mshtml=` |
| Log setting in 0.6.1 | `WINEDEBUG=-all,err+all` |
| Wine desktop argument | `/desktop=MapleRoyals,1024x768`; not a macOS display-mode change |
| Existing game setting | Windowed; 800×600 remains the recommended internal resolution |
| Extra graphics DLLs | None; no DXVK, D9VK, D3DMetal or custom `iphlpapi.dll` added |

`WINEPREFIX`, matching `WINESERVER`, runtime `PATH`, and `DYLD_FALLBACK_LIBRARY_PATH` are constructed by `portable/PortableCore.swift`. The fallback library path points to the downloaded template's `Contents/Frameworks` followed by `/usr/lib`. No local build paths are embedded in the portable launcher.

Wine labels its WoW64 and renderer announcements as `err:` messages too. Those messages alone are not evidence of failure; correlate them with the window, process exit and subsequent log entries.

## Validation of launcher 0.6.1

- The diagnostic desktop-first run reached gameplay according to the user and later exited normally with status 0.
- The old portable launcher was closed, and the rebuilt regular app was opened through Finder/Launch Services using the original installed prefix. Its log recorded the new Explorer command and the same OpenGL/MSync/CSMT configuration. The user confirmed the login screen appeared again.
- This regular-app cold launch took approximately 90 seconds. A process sample was captured during the delay; it did not establish its cause. The new launch order allowed initialization to finish instead of letting the game fail early. Do not claim that startup latency is fixed.
- The existing core checks passed, covering download integrity, installer rejection, exclusive prefix ownership, environment isolation, portable paths and data preservation. All four app signatures passed after extracting the ZIP. The installed launcher executable matches the ZIP byte for byte.
- The regular rebuilt app was verified through the login screen. The gameplay confirmation was obtained with the diagnostic launcher using the same command/runtime and a cloned prefix. A further character/map test of the rebuilt regular app has not been separately recorded.

## Updating and validation limits

Players download the current [ready-built ZIP](../download/MapleRoyals-Mac.zip), close the game and old launcher, replace **MapleRoyals.app**, and open it. The app reuses the installation; no Wine download, prefix migration or game reinstall is required. See [the player update steps](PLAYER_GUIDE.md#updating-an-existing-installation).

The macOS 27 check uses the same Mac and an existing installation, not a second machine or fresh setup. Missing-Rosetta installation, first-open security prompts on another Mac, long sessions, two clients, and the optional fullscreen helpers on macOS 27 remain unvalidated. No performance improvement is claimed.

## Sources

- [Apple: using Intel-based apps with Rosetta](https://support.apple.com/en-us/102527), updated September 14, 2026, documents Rosetta availability on macOS 27 and earlier.
- [Wine 9.0 window-driver initialization](https://github.com/wine-mirror/wine/blob/wine-9.0/dlls/win32u/driver.c): `load_desktop_driver` waits for the desktop and supplies the observed error if initialization cannot complete. This is upstream reference code, not proof that the patched CX24 binary is identical.
- [Wine 9.0 Explorer desktop initialization](https://github.com/wine-mirror/wine/blob/wine-9.0/programs/explorer/desktop.c): Explorer creates and initializes the desktop before executing its supplied command line. This informed the tested change in launch order.

Private diagnostic logs and prefix copies are intentionally excluded from the repository. They may contain local paths and account-related state.
