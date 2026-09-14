# MapleRoyals on this M1 Pro, without CrossOver

Research and local tests: September 11–12, 2026, America/Los_Angeles.

**A native Mac launcher is feasible, and the user now reports the game running without apparent crashes using our launcher.** The best locally supported configuration is the standalone `WS12WineCX24.0.7_5` engine, a 64-bit prefix using new WoW64, Windows 7, WineD3D/OpenGL, and an explicitly configured 1024×768 virtual desktop. CrossOver was not installed or used. No community DLL was installed.

This is a successful proof of concept with incomplete acceptance testing, not a claim that every stage, display mode, or future client is supported. The earlier Wine 10 configuration really did fail at character entry. The user initially described the CX24 attempt as another crash, then corrected that report to “it works now,” and subsequently “it works now and doesn't seem to crash.” Those corrections are the current result.

**Performance remains the practical limitation:** 1024×768 still feels less smooth than 800×600. The main `MapleRoyals.app` now selects the preferred CX24/OpenGL prefix with MSync on, CSMT off and quiet logging. The native display helper supplies correct 4:3 fullscreen with side bars. D9VK produced approximately 0.3–0.4 FPS; standalone WineHQ 11.17 passed 32-bit command-line and window-painting probes but stalled during MapleRoyals startup before Direct3D loaded. None of these results establishes a smooth 1024×768 Vulkan configuration.

This is an archive of the local investigation. Paths beginning with `work/`, names of experimental apps, and raw-log/evidence filenames refer to the original private test workspace; those files are intentionally not published here. For this repository’s installation steps, use [the main README](../README.md).

## What was actually tested

The Mac is a MacBookPro18,3 with an Apple M1 Pro and 16 GB RAM, running macOS 26.5.2 (25F84). Rosetta x86_64 execution is available. The user downloaded the July 2, 2026 WZ and IMG installers from the [official downloads page](https://royals.ms/downloads). We installed **WZ** into `C:\MapleRoyals`; IMG was not tested. The installer registered version `26.07.02` and installed Visual C++ 2015 x86 14.0.23026.

| Stage | Evidence and result |
|---|---|
| Windows installer | Completed locally; user completed its UI and pressed Finish. |
| Executable starts | Verified in Wine module logs on Wine 10 and CX24. |
| Login screen | User confirmed reaching it and signing in. |
| World/server and channel selection | User explicitly confirmed. |
| Character selection | User explicitly confirmed. |
| PIC | **Not exercised**: the user says there was no PIC prompt. |
| Enter game | User reports the CX24 attempt now works and does not seem to crash. No equivalent success with the earlier Wine 10 test. |
| Gameplay movement/input | User repeatedly compared rapid movements and busy scenes; input and gameplay work, with resolution-dependent visual lag. Every key and mouse action was not individually checked. |
| Change maps | Not yet explicitly confirmed as a separate acceptance step. |
| Windowed 1024×768 | Desktop registry and windowed game flag verified; screenshot-based measurement of the actual game viewport remains unverified. |
| Second concurrent client | Not tested. A launcher button exists, but its existence is not evidence of game compatibility. |
| Fullscreen | Game toggle alone did not scale. A native 1024×768/60 Hz virtual-display mirroring helper subsequently produced user-confirmed correct fullscreen with side bars; 1024×768 remained laggy. |
| Repeated cold launches/long sessions | Not established. |

Computer mode was used to open the apps in Finder and inspect the native launcher. Its app inventory did not expose the separate Wine game window, and attaching to custom apps sometimes stalled. **Game-stage confirmations came from the user, supported by Wine logs; they were not independently screenshot-verified by the agent.** No credentials or PIC were requested in chat.

## The compatibility stack

```text
Native arm64 Swift/AppKit launcher
    └─ starts standalone x86_64 Wine on macOS under Rosetta 2
         └─ new WoW64 runs MapleRoyals.exe (PE32 / x86)
              └─ Gr2D_DX8.dll → builtin d3d8.dll → WineD3D → OpenGL
```

The game's local PE imports include `dinput8`, `iphlpapi`, `mss32`, Winsock and WinINet. `Gr2D_DX8.dll` contains `Direct3DCreate8` and `d3d8.dll` references; runtime logs show builtin `D3D8.DLL`, `wined3d.dll`, and OpenGL loaded. Thus **Direct3D 8 is the demonstrated rendering requirement**. It would be wrong to infer a DirectDraw-only game from its age, or install a DirectDraw wrapper without evidence. `Sound_DX8.dll` and DirectSound appear in the local logs as well.

Sikarugir's current documentation supports macOS 14+, requires Rosetta on Apple Silicon, and assigns WineD3D to DirectX 8 and earlier. Its newer D9VK, DXMT, DXVK and D3DMetal defaults/toggles concern other API paths. We did not execute the wrapper's automatic renderer setup. [Official Sikarugir documentation](https://github.com/Sikarugir-App/Sikarugir)

WoW64 handles the Windows 32/64-bit boundary; Rosetta supplies the CPU translation used by these x86_64 Mac engines. They solve different problems. Wine 11 considers new WoW64 fully supported, rejects pure `win32` prefixes in that mode, and uses a single `wine` loader. This does not certify a particular game. Wine 11 also says its Vulkan renderer still lacks OpenGL feature parity. [Wine 11 release notes](https://raw.githubusercontent.com/wine-mirror/wine/wine-11.0/ANNOUNCE.md)

Wine 10's ARM64EC support alone was not a ready-made Rosetta replacement: its release required an external emulator and described a 4 KB page-size constraint. Wine 11 adds limited emulation of 4 KB pages on larger-page hosts. Neither establishes that a stock ARM64 distribution runs this client here. [Wine 10 release notes](https://raw.githubusercontent.com/wine-mirror/wine/wine-10.0/ANNOUNCE.md), [Wine 11 release notes](https://raw.githubusercontent.com/wine-mirror/wine/wine-11.0/ANNOUNCE.md)

There is a relevant 2026 development: CodeWeavers announced a Mac ARM64 Wine/FEX preview on July 31, requiring macOS 26.5+ for that path, fresh bottles, and substantial further testing. That is a future runtime direction, **not a standalone, validated MapleRoyals replacement demonstrated here**; the CrossOver product was not used. [CodeWeavers ARM64/FEX announcement](https://www.codeweavers.com/blog/mjohnson/2026/7/31/crossover-preview-the-right-to-bear-arm64-on-mac)

Apple currently promises general Rosetta availability through macOS 27, with limited older-game functionality from macOS 28. Do not promise that this Wine wrapper qualifies for that exception. A distributable app needs an OS support policy and a future separately validated Wine/FEX migration. [Apple, February 16, 2026](https://support.apple.com/en-us/102527)

## Current engines and alternatives

The maintained **project** and its **pinned engine** are separate considerations. CX24 `_5` is the locally successful historical build, not the newest release.

| Upstream artifact | Asset update date | Local disposition |
|---|---|---|
| `WS12WineSikarugir10.0_6` | 2026-04-10 | `wine-10.0 (Sikarugir)`; installed the game, then failed at character entry with desktop mode. |
| `WS12WineCX24.0.7_5` | 2025-08-19 | `wine-9.0 (KegworksCX 24.0.7)`; successful candidate after Windows 7 and explicit desktop configuration. |
| `WS12WineCX24.0.7_7` | 2025-11-20 | Listed currently; not tested. |
| `WS11WineSikarugir11.0` | 2026-09-03 | Downloaded and checksum-verified; reports `wine-11.0 (Sikarugir)`. Prefix initialization failed, including an empty-prefix control; the game and direct WineD3D/Vulkan renderer were not reached. |
| WineHQ `wine-devel-11.17-osx64` | 2026-09-11 | Own native libraries; initialized an empty prefix, ran a 32-bit Windows command and painted a 32-bit Notepad window. MapleRoyals startup stalled before graphics initialization. |
| `Template-1.0.15` | 2026-09-04 | Supplies native dependency libraries for our tests. Its Sikarugir launcher is not the running launcher. |

Dates above are asset updates, not the old release-tag date. Exact URLs, sizes and SHA-256 digests are in `evidence/upstream-assets.json`. [Engine list](https://raw.githubusercontent.com/Sikarugir-App/Engines/main/EngineList.txt), [engine assets](https://github.com/Sikarugir-App/Engines/releases/tag/v1.0), [template assets](https://github.com/Sikarugir-App/Wrapper/releases/tag/v1.0)

The Gcenx WineHQ macOS packages are a maintained lower-level alternative, supporting 32- and 64-bit Windows executables. Their current documented configuration includes `--without-opengl`, however, so they are **not an interchangeable implementation of our tested OpenGL path**. Independent testing of 11.17 reached Windows GUI painting but did not reach MapleRoyals' Vulkan renderer. [Official build repository](https://github.com/Gcenx/macOS_Wine_builds), [tested Mac package](https://github.com/Gcenx/macOS_Wine_builds/releases/tag/11.17)

Whisky's repository is archived and says it is not actively maintained; its presence in an engine list does not make it a preferred maintained baseline. [Whisky repository](https://github.com/Whisky-App/Whisky)

A 2026 M3 Pro report describes success with Parallels and Windows ARM. That remains an untested, larger VM alternative here, rather than the requested minimal Wine app. [April 2026 forum report](https://royals.ms/forum/threads/play-mapleroyals-on-macbook-apple-silicon.256791/)

## What the forum reports do and do not establish

| Report | Supported conclusion |
|---|---|
| M1 Pro, Sequoia 15.6.1, September 27, 2025 | Installer success with `WS12WineCX24.0.7_5` followed by `-2147467259 (Call Failed)` on game launch; no solution appears in that thread. Same engine alone is not a guarantee. [Report](https://royals.ms/forum/threads/error-code-2147467259-call-failed-on-a-mac.250285/) |
| M2 Pro, Tahoe 26.0, October 26, 2025 | User reports the instructions work with **`WS12WineCX24.0.7_5` and `Template-1.0.1`**. They mention DXVK moved to a checkbox; that is not proof DXVK is required or of every gameplay stage. [Post #8](https://royals.ms/forum/threads/macbook-x-wineskin-winery.231186/) |
| July 3, 2026 character-entry report | A Win7 64-bit CrossOver setup had an executable access violation and later `WzFlashRenderer.dll` unload fault; a 1024×768 virtual desktop allowed entry. There was no PIC configured. [Post #11](https://royals.ms/forum/threads/play-on-mac-apple-silicon-crossover-tutorial-2025.244814/) |

The 2025 tutorial also describes a 4:3/60 Hz BetterDisplay arrangement and a two-client workaround, alongside reports of failure on other Apple chips. These are configuration-specific observations, not universal requirements. [2025 tutorial and replies](https://royals.ms/forum/threads/play-on-mac-apple-silicon-crossover-tutorial-2025.244814/)

The community `iphlpapi.dll` suggestion replaces Wine's **builtin `lib/wine/i386-windows/iphlpapi.dll`**. It is not the same procedure as downloading an arbitrary Microsoft DLL into the game directory. Its linked binary's exact source, patch and reproducible build were not established here. The older `dbghelp` disabling suggestion was presented as a potential workaround, not a guaranteed fix. [Community workaround post](https://royals.ms/forum/threads/macbook-x-wineskin-winery.231186/)

We used the stock CX24 `iphlpapi.dll`, hash `cd5803a41bf6546e9685f2706b1fc8b960fc5cd9a1656037069bc299001cf8b6`. The running result therefore does not depend on that community patch. We also did not disable `dbghelp`.

## Local failure analysis and successful candidate

The bare engine was initially incomplete as a standalone directory: loading failed because `@rpath/libinotify.0.dylib` was missing. Supplying the template's native library directory resolved that dependency. Attempts to initialize Wine inside the agent's restricted shell then failed at the wineserver Mach port. A native desktop launcher got beyond that tooling restriction and installed the game. These were distinct dependency/sandbox failures, not evidence that MapleRoyals itself was incompatible.

The first full game experiment used Wine 10 with its builtin renderer, then `wine explorer /desktop=MapleRoyals,1024x768 C:\MapleRoyals\MapleRoyals.exe`. Its character-entry log contains:

```text
EXCEPTION_ACCESS_VIOLATION at 0x005FCE38
attempted read at 0xFF0001A0
later allocation failure during error handling
then WzFlashRenderer.dll unload and a second access violation
```

`dbghelp` loaded after the first fault. The later allocation/unload problems do not establish that physical RAM, Flash, or `dbghelp` caused the original fault. Ordinary handled exceptions and Wine `fixme` messages likewise cannot all be called crashes. See `evidence/wine10-character-entry-failure.txt`.

For CX24 we cloned the installed Wine 10 prefix using APFS copy-on-write, ran the CX24 engine's `wineboot -u`, and imported the settings below. The game then started directly. The user corrected the apparent second failure to success. The saved CX24 excerpt has the OpenGL renderer and stock DLL load, without a matching access-violation/exit record at the time success was reported.

**This changed the engine, Windows version and desktop activation method together.** It demonstrates a useful configuration; it does not isolate which change fixed the transition. We stopped modifying it when the user reported success.

## Original successful baseline

`$WORK` below is this project's `work` directory. The app's JSON stores the actual absolute path. No global Wine, Homebrew Wine installation, CrossOver application or Sikarugir Creator is needed for launching.

| Setting | Tested value |
|---|---|
| Engine executable | `$WORK/runtime-cx24/wswine.bundle/bin/wine` |
| Wineserver | Same engine's `bin/wineserver` |
| Prefix | `$WORK/prefix-cx24`, `#arch=win64`; Windows game is PE32 |
| `WINEARCH` | `win64` |
| `DYLD_FALLBACK_LIBRARY_PATH` | `$WORK/template/Template-1.0.15.app/Contents/Frameworks:/usr/lib` |
| `WINEDLLOVERRIDES` | `mscoree,mshtml=` |
| `WINEESYNC`, `WINEMSYNC` | Both `0` |
| `WINEDEBUG` | `+timestamp,+pid,warn+seh,+loaddll,+msgbox,warn+d3d` |
| `PATH` | Engine `bin`, followed by `/usr/bin:/bin:/usr/sbin:/sbin` |
| `WINELOADER`, `WINEDLLPATH`, `DYLD_LIBRARY_PATH`, `WINE_D3D_CONFIG`, DXVK config variables | Not supplied; launcher clears relevant inherited overrides |
| Working directory | Prefix `drive_c/MapleRoyals` |
| Renderer | Builtin D3D8 → WineD3D/OpenGL; no third-party renderer overrides |
| Host display | Later verified in System Settings: 1512×982 default, ProMotion; no physical mode change used for successful launch |
| Wine display | Named desktop `Default`, 1024×768; game windowed flag `0`; font DPI 96 inherited |

```reg
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Wine]
"Version"="win7"

[HKEY_CURRENT_USER\Software\Wine\Explorer]
"Desktop"="Default"

[HKEY_CURRENT_USER\Software\Wine\Explorer\Desktops]
"Default"="1024x768"

[HKEY_CURRENT_USER\Software\Wine\Direct3D]
"renderer"="gl"

[HKEY_CURRENT_USER\Software\MapleRoyals]
"soFullScreen"=dword:00000000
```

The installer also set `HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers`, value name `C:\MapleRoyals\MapleRoyals.exe`, to `WIN7RTM`. That installer compatibility flag is separate from Wine's global `Version=win7` setting.

With the environment above, the commands were:

```sh
"$WINE" wineboot -u
"$WINE" reg import "$WORK/cx24-settings.reg"
cd "$WINEPREFIX/drive_c/MapleRoyals"
"$WINE" 'C:\MapleRoyals\MapleRoyals.exe'
```

`repro/run-baseline.sh` preserves this original environment; `run-current.sh` uses the later preferred settings below. The native launcher executes argument arrays directly, without opening a terminal or asking the user to configure Wine.

The original diagnostic log is verbose and contains repeated graphics warnings. A separate comparison with `WINEDEBUG=-all` was subsequently played by the user: 1024×768 was perhaps a little better, but 800×600 remained clearly smoother. Logging therefore did not explain most of the perceived difference. No frame-time measurements have been collected.

1024×768 Wine virtual-desktop dimensions do **not** set the physical monitor to 60 Hz or scale the game to the panel. System Settings showed ProMotion. The game toggle alone removed window decorations but left the image at the top left. Our later native virtual-display mirroring helper produced user-confirmed full-height 4:3 presentation, first with a 60 Hz virtual mode and then with 120 Hz. BetterDisplay was not installed. Performance remained worse at 1024×768 than 800×600; see the follow-up below.

## Deliverables and reproduction limits

`MapleRoyals.app` now uses the current native launcher and the preferred OpenGL configuration: prefix `work/prefix-cx24-csmt0`, `WINEMSYNC=1`, `WINEESYNC=0`, `WINEDEBUG=-all`, and `HKCU\Software\Wine\Direct3D\csmt=0`. The runtime, native library path, Windows 7, stock graphics DLLs, and 1024×768 virtual desktop remain as above. The user's saved game settings are `nResolution=1` and `soFullScreen=1`. Correct full-height presentation still depends on the separate native display helper; the currently kept helper is 120 Hz. This setting is not a claim of 120 game FPS.

The original `MapleRoyals CX24.app`, prefix and baseline shell script remain available. The original main-app JSON is preserved in `evidence/original-MapleRoyals-configuration.json`; current JSON is `evidence/current-opengl-configuration.json`. **The main app still depends on this workspace's `work` directory.** Moving the small app alone to another Mac will not work. Its signature and shell replay syntax were checked. On its consolidation launch, the registry command exited 0, MSync reported active, and Activity Monitor showed `MapleRoyals.exe` running; the user then confirmed entering the game: 1024×768 remains laggy, while 800×600 is smoother and playable. The quiet-logging consolidation is therefore gameplay-confirmed, with the performance limit unchanged.

`repro/prepare.py` downloads the exact pinned engine and template, verifies SHA-256, builds the Swift app, and initializes a private prefix through that app. The user supplies an official installer; no game assets are in the deliverable. See `repro/README.md` for commands.

The clean-machine recipe installs directly with CX24; `--performance` selects the preferred MSync/CSMT/logging settings. Our historical successful test instead began with installation on Wine 10 and a cloned prefix. **The clean-machine recipe has been argument/syntax checked and its Swift source compiled; it has not undergone a second clean-install-to-gameplay test.** Its `--performance --plan` invocation also passed. Current-client updates require renewed testing.

## Architecture for a distributable app

The proof of concept already establishes that our own native process launcher can replace the wrapper UI. A production layout should be:

```text
MapleRoyals.app/
  Contents/MacOS/MapleRoyals          native Swift launcher
  Contents/Resources/runtime.json    pinned engine/dependency manifest
  Contents/Resources/licenses/       notices and source information
  Contents/Frameworks/               optional audited bundled Wine runtime

~/Library/Application Support/MapleRoyals/
  runtimes/<version>/                alternatively provisioned, versioned runtime
  prefixes/<runtime-version>/        mutable Windows state and user-installed game
  logs/                             rotating, private diagnostics
```

First run should check the supported OS/Rosetta combination, provision verified upstream runtime artifacts or use bundled ones, and offer a native selection dialog for the user's official game installer. After installation, import the tested registry settings. Subsequent double-clicks simply launch the game. Keep credentials and PIC in the game UI. No Sikarugir/bottle/renderer controls belong in the normal flow.

Keep mutable prefixes outside the signed app. Pin runtime updates; clone the prefix before migrations, keep rollback, and validate the full stage matrix before promoting a new default. Multiple clients should share a matching engine/wineserver and only be exposed as supported after concurrent gameplay tests. Add a proper running/failed status, log rotation, and a deliberate retry path; the current launcher is diagnostic scaffolding.

The current CX24 runtime occupies about 502 MiB and the full template Frameworks about 374 MiB, apart from a roughly 3.1 GiB installed prefix. The native app is under 200 KB. The template includes approximately 149 MiB of GStreamer and 136 MiB of renderer payloads, plus its SDK and other libraries. **These are pruning candidates, not a validated minimum.** Derive and test the native dependency closure, account for libraries loaded dynamically, and omit unused Mono/Gecko and graphics packages only after regression tests. Do not change the live successful runtime just to reduce its footprint.

Before public release, audit dependencies, sign nested executable code appropriately, sign/notarize the outer app, and test Gatekeeper, relocation, fresh provisioning and update rollback. Hardened-runtime entitlements and dynamic-library layout must be validated with the chosen engine; ad-hoc signing on this Mac does not prove release readiness.

## Redistribution and ownership

Wine is LGPL 2.1 or later. Distributing its binaries requires the applicable notices and corresponding source obligations, including the actual patches/build material for the version shipped; a link to unrelated upstream Wine is insufficient. A separately written launcher communicating through processes is normally a separate program, but bundled dependencies still carry their own obligations. Preserve users' rights for covered components. [Wine license](https://raw.githubusercontent.com/wine-mirror/wine/master/LICENSE), [LGPL text](https://raw.githubusercontent.com/wine-mirror/wine/master/COPYING.LIB)

CodeWeavers publishes its FOSS sources. A CX-derived Wine engine is therefore distinct from installing or redistributing the proprietary CrossOver product. Exact source correspondence for Sikarugir's prebuilt `_5` artifact and its dependency binaries remains an audit item before we redistribute them ourselves. [CodeWeavers source distribution](https://www.codeweavers.com/crossover/source)

Sikarugir explicitly identifies Configure as LGPL, but excludes its newer Launcher/Creator from that LGPL declaration. We have not established a blanket redistribution license for the whole template. Our product should use our own launcher and audited runtime components, not rebrand the entire wrapper. Its D3DMetal payload is proprietary and unnecessary for this tested route. [Sikarugir licensing statements](https://github.com/Sikarugir-App/Sikarugir), [Configure sources](https://github.com/Sikarugir-App/Sikarugir-foss-sources)

No redistribution permission for the MapleRoyals/Nexon game assets was established. Keep EXE/WZ/IMG and the installed Microsoft redistributable out of a public app archive; let each user obtain and install authorized copies. A used prefix also contains user-specific state and must not become a public seed. The game's rules require official, unmodified files; this test did not patch its game executable. [MapleRoyals terms](https://royals.ms/forum/threads/mapleroyals-game-terms-conditions.86769/)

Direct provisioning from official upstream locations is the simplest initial distribution design, while runtime source/licensing and fully portable packaging are audited. Rosetta is provisioned by macOS, not bundled by our launcher.

## Follow-up: resolution and fullscreen performance

The user reports smooth, responsive rendering at **800×600**, but lag/delay at **1024×768**, which they prefer. The Wine desktop is 1024×768; this is distinct from the game's selected internal resolution. At the same frame rate, 1024×768 contains 63.84% more pixels than 800×600. That arithmetic does not identify the bottleneck. No smooth-1024×768 claim has been established. The user closed the original game normally (exit status 0); the quiet comparison then launched on a separate cloned prefix. It uses the identical native executable, engine, renderer and registry state, with diagnostics disabled and setup skipped because the prefix is already initialized.

**Quiet comparison result:** the user switched between both resolutions and reported that 800×600 remained much smoother; 1024×768 was perhaps slightly better than before. The game's borderless/fullscreen toggle made 1024×768 a little smoother, but not significantly, and still did not fill the panel. This is a qualitative user observation, not a measured FPS result.

**MSync comparison result:** a fresh APFS clone of the closed quiet-test prefix used the same CX24 engine and OpenGL settings, with `WINEMSYNC=1`, `WINEESYNC=0` and logging still off. All three registry files matched the source clone by SHA-256 before launch. The user played successfully and reported perhaps a tiny improvement, but 1024×768 remained noticeably laggier during rapid repetitive movement and busy scenes. Activity Monitor's Wine server inspector confirmed the MSync shared-memory object `/wine-1546eec-msync`, the test prefix, and builtin D3D8/WineD3D/OpenGL libraries. Thus the backend was active even though quiet logging did not print its initialization banner. This did not resolve smooth 1024×768 gameplay; no large benefit is established.

System Settings confirms the physical display normally uses 1512×982 and ProMotion. Its complete native resolution list has no 1024×768 mode. Removing game-window decorations did not perform display scaling. A native Swift helper was built using private CoreGraphics declarations from the MIT-licensed [DeskPad project](https://github.com/Stengo/DeskPad), creating a non-HiDPI 1024×768, 60 Hz virtual Mac display and requesting native mirroring to the built-in panel. macOS accepted creation and mirroring (success code 0), and the initial 20-second automatic rollback also returned success. The user requested a longer trial, so the next trial was kept active. **The user confirmed correct fullscreen presentation, but 1024×768 still lagged.** Restore or quitting the helper returns the normal display. The helper remains separate from the launcher; source, build recipe and MIT notices are in `repro/display/`. Multiple displays, sleep/wake, abnormal termination and compatibility with other macOS versions remain untested.

A lightweight FPS diagnostic (`WINEDEBUG=-all,+timestamp,+fps`) was played with MSync, OpenGL and 60 Hz fullscreen presentation. Wine's existing FPS channel prints an approximate presented-frame rate every 1.5 seconds. The user then found both game resolutions similar, while still feeling some lag, and was unsure whether 800×600 had become worse. Recent readings commonly fell around 55–75 presented FPS, but test phases were not timed precisely enough to report a rigorous resolution-by-resolution average. Saved registry resolution values can also lag in-game changes. These readings do not measure input latency, individual stalls or physical panel scanout. `repro/summarize-fps.py` extracts the nonduplicated WineD3D presentation readings; do not average the whole log across startup and focus/display changes. [Wine 9 command-stream implementation](https://raw.githubusercontent.com/wine-mirror/wine/wine-9.0/dlls/wined3d/cs.c)

The same fullscreen helper was then built for **1024×768 at 120 Hz**. Creation and mirroring succeeded; System Settings showed the built-in panel mirroring and optimized for that virtual display, with ProMotion still selected on the physical panel. The same running game again felt smoother at 800×600 and laggy at 1024×768. This supports, but does not prove, the inference that the earlier 60 Hz comparison partly reduced 800×600 smoothness. A fresh prefix/server/client launch under the already-active 120 Hz display was subsequently tested: the user reported perhaps a tad less visual delay, but still enough lag to make busy scenes a concern. Thus restarting under 120 Hz did not establish a satisfactory 1024×768 configuration.

**Graphics queue comparison:** a fresh copied prefix used `HKCU\Software\Wine\Direct3D\csmt` DWORD `0`, retaining OpenGL, MSync and the 120 Hz fullscreen helper. The startup log explicitly confirmed multithreaded command stream 0 and OpenGL. The user reported a small improvement, but 1024×768 still felt worse than 800×600. The game closed normally with exit status 0. This experiment did not establish a satisfactory performance fix. [Wine 9 graphics configuration](https://raw.githubusercontent.com/wine-mirror/wine/wine-9.0/dlls/wined3d/wined3d_main.c)


**Vulkan candidate result: launches, but unusably slow.** An isolated APFS clone of the closed queue-test prefix used official d3d8to9 1.15.1 and the template's `DXVK-Sikarugir-async-v1.10.3` D3D9 component. The demonstrated path is D3D8 → d3d8to9 → Sikarugir D9VK → Wine Vulkan → MoltenVK → Metal on Apple M1 Pro. This is a distinct experiment from WineD3D's own Vulkan renderer, which has not been tested. No game EXE/WZ/IMG was modified. Exact hashes and state are in `evidence/vulkan-candidate.json`. d3d8to9 is BSD 2-clause; its official release is dated March 2026. [d3d8to9 release](https://github.com/crosire/d3d8to9/releases/tag/v1.15.1), [Sikarugir D9VK sources](https://github.com/Sikarugir-App/d9vk)

The initial DLL configuration was incorrect: the template's D3D9 binary contains the `Wine builtin DLL` marker, so native-only `d3d9=n` made Wine report it missing (`c0000135`). D3D8 then failed to load and the game exited 5. Wine's source explicitly rejects builtin-marked images with a native-only override; builtin lookup also prefers the engine's DLL directory. We corrected this by making a separate APFS clone of CX24, atomically replacing **only** its `lib/wine/i386-windows/d3d9.dll` with the exact template binary, and setting `WINEDLLOVERRIDES=mscoree,mshtml=;d3d8=n;d3d9=b`. The original working engine remains untouched. [Wine 9 Unix loader](https://raw.githubusercontent.com/wine-mirror/wine/wine-9.0/dlls/ntdll/unix/loader.c)

The corrected log confirms native D3D8, the replacement builtin D3D9, the DXVK version, and MoltenVK creating a device on the Apple M1 Pro. WineD3D/OpenGL is also loaded as a dependency during initialization, so module presence alone would be misleading; the D3D9 log and Metal swapchain establish the actual tested route. The game requested windowed 1024×768, while the resulting swapchain was 1024×748. MoltenVK printed three primitive-restart feature warnings. They do not alone prove the cause of the slowdown.

The user reported **approximately 0.3 FPS with mouse movement barely usable**. Activity Monitor showed about 195% CPU and very little GPU activity in the observed snapshot. The Wine log stopped growing at about 54 KB and the D3D9 log at about 4 KB, ruling out continuous diagnostic log spam during this observation. The saved CPU sample confirms the translated game process and Vulkan threads, but many Windows frames are unsymbolized or incorrectly unwound, preventing a precise bottleneck attribution. Neither successful initialization nor the GPU's presence implies acceptable performance. This combination should not be the app's default. The user's exact login/character-entry stage was not separately established in this test.

Two earlier attempts also spent several minutes in macOS dyld/Rosetta before Wine initialized; the saved startup sample documents this separately from the DLL configuration failure. The corrected attempt initialized much sooner. A causal explanation for the startup-time variation has not been established. The native launcher source now spawns processes off the main queue and logs child PIDs; that revision successfully launched the corrected graphics candidate.


## Continuing Vulkan validation with Wine 11

The 0.3 FPS result applies to the specific CX24 + d3d8to9 + Sikarugir D9VK route. It does not establish that Vulkan in general is unsuitable for an old game. A newer API can improve a compatible translation path, but is not a performance guarantee; MapleRoyals still issues its original D3D8 calls, and the Mac ultimately uses Metal underneath the Vulkan compatibility driver.

Wine 11 explicitly adds legacy Vulkan rendering features including alpha test, color keying, point sprites and fixed-function bump mapping, and improves old shader translation. Its release notes still say the Vulkan renderer has not reached OpenGL parity. This is a concrete reason to test Wine 11's **builtin D3D8 → WineD3D → Vulkan** path separately, removing d3d8to9 and D9VK. [Wine 11 release notes](https://raw.githubusercontent.com/wine-mirror/wine/wine-11.0/ANNOUNCE.md)

The pinned Sikarugir Wine 11 engine was downloaded from its official release asset and verified against `d12fa09149b9afd3be349d726eecea6b2216ac574c91f93f56d872bb6ca7b795`. Both its outer and inner loader executable report `wine-11.0 (Sikarugir)`. The first test attempted to migrate a copied CX24 prefix, then import Win7, a 1024×768 desktop, `renderer=vulkan` and `csmt=1`. It failed before the registry import. No native graphics DLL replacement was present. The existing 120 Hz fullscreen helper remained active.

Its first startup failed with `run_wineboot failed to start wineboot 1`, before any game launch. A diagnostic retry with module/process/exception tracing reproduced this after loading the new engine's own `wineboot`, `ntdll` and API-set schema. This engine also uses the Vulkan loader (`libvulkan.1.dylib`) rather than CX24's direct MoltenVK load, so the retry explicitly selected the template's MoltenVK ICD with `VK_DRIVER_FILES`. That did not resolve initialization.

An initially empty prefix with MSync and ESync both disabled reproduced the pre-game failure in log 18. This rules out the migrated game installation and enabled MSync as necessary causes of that failure. A further probe added `ROSETTA_ADVERTISE_AVX=1`, a CPU-feature option present in Sikarugir launcher strings. It remained in macOS dyld/Rosetta startup for more than four minutes; Activity Monitor captured the waiting stack, and we stopped the empty-prefix probe normally (native termination status 15). This interrupted probe is not evidence that AVX itself fails. No approval dialog was visible in the launcher or enabled-app inventory during the check.

**Precise current limit:** `WS11WineSikarugir11.0` has not initialized Windows successfully through this minimal launcher. MapleRoyals and WineD3D/Vulkan were never reached. The runtime may need additional wrapper behavior, or have an independent startup problem on this machine; these observations do not distinguish those causes. Exact configurations, logs and sample references are in `evidence/wine11-vulkan-candidate.json`. Changing the graphics renderer cannot diagnose a failure that occurs before graphics initialization.

## Vulkan synchronization comparison

Test 20 reuses the exact CX24/D9VK engine and closed game prefix from the 0.3 FPS run, with `WINEMSYNC=0` instead of `1`. ESync remains disabled; D3D8/D3D9 DLL hashes, overrides, renderer and display helper are unchanged. Diagnostic output is routed to a separate directory. This checks whether the synchronization option selected during OpenGL testing contributes to Vulkan's slowdown; no performance improvement is assumed. Configuration: `evidence/d9vk-msync-off-config.json`; local terminal replay: `repro/run-d9vk-current.sh 0`. This is an experimental local replay, not a clean-machine installer.

The MSync-off test initialized the same Apple M1 Pro Vulkan route and 1024×748 swapchain. Activity Monitor showed approximately 199% CPU and 0.1% GPU in one observation, which does not establish FPS or input latency. The user reported approximately **0.4 FPS, still unusable**. Disabling MSync did not resolve the slowdown; see `evidence/d9vk-msync-off-result.json`.


## Standalone WineHQ 11.17 follow-up

The official WineHQ macOS package `wine-devel-11.17-osx64.tar.xz`, published September 11, 2026, was downloaded from Gcenx's release and verified against SHA-256 `c2b3a8274dbc594deaa64e40469b607cbc4aa8ef5656dec4c5f6f3dac0da770c` (191,290,556 bytes). Its loader reports `wine-11.17`. This is a development release, not the stable Wine 11.0 branch. [Official Mac package](https://github.com/Gcenx/macOS_Wine_builds/releases/tag/11.17)

**The empty-prefix runtime test passed.** Using only the package's own `wine/lib` native libraries, an initially empty win64 prefix, disabled Mono/Gecko, and MSync/ESync off, `wineboot -u` and `cmd /c ver` each exited 0. The Windows command reported version 10.0.19045, and the native app visibly showed “Runtime initialization completed.” The package includes its own MoltenVK driver, Vulkan loader and ICD JSON; no Sikarugir Frameworks directory was used. This establishes a working lower-level standalone runtime on this Mac. It does not yet establish MapleRoyals compatibility or graphics performance. Exact configuration and evidence: `evidence/winehq11-runtime-probe.json`.

System Settings showed Documents Folder access already enabled for the test launcher; no privacy settings were changed. The earlier Sikarugir Wine 11 failure is therefore not evidence that all Wine 11 packages require CrossOver or cannot run on this Mac. The precise cause of that package's failure remains undetermined.

Test 22 attempted to migrate an APFS clone of the closed CX24/OpenGL prefix. It stalled before Windows initialization. An Activity Monitor sample and matching local disassembly placed the worker inside `open(".", O_RDONLY)` while opening the native current directory under Documents. This does not establish a permissions root cause. The scoped process was stopped through Activity Monitor; the launcher recorded termination by signal 15. Evidence: `evidence/winehq11-game-startup-sample.txt`; configuration: `evidence/winehq11-vulkan-config.json`.

Test 23 cloned the same runtime and old prefix to `/private/tmp/MapleRoyals-WineHQ-11.17-test`. Wine then initialized immediately, passing the earlier directory-opening stall, but the prefix migration stopped progressing before the game was launched. The scoped Wine server and parent were stopped through Activity Monitor. This was a migration/startup failure, not a game rendering result. Configuration: `evidence/winehq11-vulkan-relocated-config.json`; copied log: `work/logs/23-winehq11-vulkan-relocated.log`.

Test 24 instead cloned the successfully initialized WineHQ probe prefix and copied only the official game directory into it. Registry import and an explicit 32-bit `C:\windows\syswow64\cmd.exe /c ver` each exited 0; the latter reported Windows 6.1.7601. `MapleRoyals.exe` subsequently loaded as a native Windows PE. The requested route is builtin D3D8 → WineD3D Vulkan, using the package's own MoltenVK ICD, `d3d8,d3d9=b`, csmt=1, MSync/ESync off, and a 1024×768 virtual desktop with the native 120 Hz display helper. No d3d8to9/D9VK replacement is installed in this prefix. **Actual WineD3D Vulkan initialization, login and game performance were not reached.** Adapter enumeration in bootstrap logs alone does not confirm the game's renderer. The initial computer-use check was interrupted by a locked Mac; the resumed checks and final diagnosis are recorded below. Configuration: `evidence/winehq11-vulkan-clean-config.json`; copied log snapshot: `work/logs/24-winehq11-vulkan-clean.log`.

The test 23/24 runtime and prefixes are temporary and may be removed by macOS. This path is diagnostic, not the proposed permanent app layout. The preserved CX24/OpenGL app remains the only user-confirmed playable configuration.

After unlocking the Mac, test 24 still stalled before loading D3D8 or WineD3D. Activity Monitor showed its Wine game process near 98% CPU. A saved sample (`evidence/winehq11-clean-startup-sample.txt`) showed Rosetta exception-server activity and a Wine signal-handler stack. This is evidence of where execution was observed, not proof of a Rosetta defect or a known game exception. The process was closed through Activity Monitor and the launcher recorded exit 1 after that intervention.

Test 25 repeated startup with `+seh` exception tracing and otherwise unchanged graphics settings. It stopped progressing at the same point. The log contains a handled `RPC_S_SERVER_UNAVAILABLE` exception and `80000026` callback-unwind traces; neither alone identifies the cause. No missing game DLL, D3D8 initialization or WineD3D device creation was logged. The scoped process was again closed through Activity Monitor. Configuration: `evidence/winehq11-startup-exceptions-config.json`; log: `work/logs/25-winehq11-startup-exceptions.log`.

Test 26 launched Wine's own **32-bit** `C:\windows\syswow64\notepad.exe` in the same prefix. It created a window and edit control, repeatedly painted/flushed its native window surface and blinked its caret, with about 3.5% CPU in one Activity Monitor observation. Thus basic new-WoW64 GUI operation works; this is not a failure of every 32-bit GUI program. The computer-use app inventory timed out, and direct attachment to unbundled Wine processes was unavailable, so the window-painting result is log-confirmed rather than screenshot-confirmed. The probe and all leftover WineHQ helpers were closed through Activity Monitor; one orphaned migration helper required Force Quit after ignoring normal Quit. No active WineHQ game was left running. Configuration: `evidence/winehq11-win32-notepad-config.json`; log: `work/logs/26-winehq11-win32-notepad.log`.

**Current WineHQ blocker:** MapleRoyals loads its executable but stalls before the graphics DLLs initialize. A command-line probe and GUI control probe succeed. The precise defect remains unidentified; there is no verified registry or DLL fix for this failure. This does not prove that WineD3D Vulkan itself is incompatible with the game, because its game-rendering stage was never reached.

The WineHQ release documents system GStreamer as a requirement. This probe did not install it; the successful basic runtime test does not validate optional media playback. Any relevant game media-loading failure must be diagnosed before deciding whether to provision that dependency.
