# Developer guide: build and extend the project

[Back to the README](../README.md) · [Player guide](PLAYER_GUIDE.md)

Use this guide to build the shareable app ZIP, work on the native launcher, or reproduce the earlier local proof of concept. Recipients of the compiled ZIP use the player guide and do not need this toolchain.

## Build prerequisites

Use an Apple Silicon Mac with macOS 14 or newer, Python 3.9 or newer, and Apple's Command Line Tools with Swift. Builds and gameplay have been exercised on an M1 Pro running macOS 26.5.2. The app targets macOS 14–27; other supported-target combinations remain unvalidated.

Install/check the build tools as needed:

```sh
xcode-select --install
python3 --version
xcrun --find swiftc
```

Complete Apple's installer if the tools are missing. Full Xcode and Homebrew are not required. Install Python from [Python.org](https://www.python.org/downloads/macos/) if your available version is too old. No third-party Python packages are required.

Rosetta is required to **run Wine and test the game** on Apple Silicon, not to compile the native arm64 launcher. If it is absent, test the app's Rosetta flow or install it through Apple's prompt:

```sh
softwareupdate --install-rosetta
```

Review and accept Apple's terms yourself. Do not automate agreement acceptance. Missing-Rosetta first-run setup has not yet been tested on a second Mac. [Apple's Rosetta information](https://support.apple.com/en-us/102527)

Clone this repository (with access to it), or unpack its source ZIP. Run the commands below from the repository root, which contains `portable/`, `assets.json` and `settings.reg`.

## Build the shareable app ZIP

```sh
python3 portable/build.py
```

The default outputs are `dist/MapleRoyals-preview/` and `dist/MapleRoyals-preview.zip`. Existing outputs are never overwritten. For another build, choose a new output folder, for example:

```sh
python3 portable/build.py --output dist/MapleRoyals-preview-next
```

The ZIP includes the native arm64 `MapleRoyals.app`, its embedded Intel compatibility helper, both compiled fullscreen display helpers, `START-HERE.txt`, configuration, notices and build information. The recipient downloads the official game separately; on first run the app downloads about 260 MB of pinned runtime archives and initializes its own Wine prefix.

**Share the compiled ZIP with players.** GitHub's **Code → Download ZIP** is source code. The build script does not upload a GitHub release. For now the maintainer supplies the compiled ZIP separately; attaching a tested build to a release is a separate publishing action.

The default build uses ad-hoc signatures and no Apple Developer account, Team Identifier or notarization credentials. `--identity` exists for a future explicitly chosen Developer ID build; it never selects an identity automatically or notarizes/uploads anything. The current hobby workflow deliberately does not require a business Apple identity. See [packaging and licensing notes](PACKAGING.md) before changing distribution strategy.

## Source map and architecture

| File | Responsibility |
|---|---|
| [`portable/PortableLauncher.swift`](../portable/PortableLauncher.swift) | Native AppKit UI, installer selection, Rosetta flow, status and Play controls. |
| [`portable/PortableCore.swift`](../portable/PortableCore.swift) | Verified downloads, staged runtime extraction, exclusive installation lock, prefix setup, process launch, install marker and logs. |
| [`portable/RosettaCheck.swift`](../portable/RosettaCheck.swift) | Tiny Intel-only helper that can trigger Apple's Rosetta installation prompt. |
| [`portable/build.py`](../portable/build.py) | Compile, sign and package the portable app and helpers. |
| [`portable/START-HERE.txt`](../portable/START-HERE.txt) | Short player instructions included in generated ZIPs. Keep these consistent with the player guide. |
| [`assets.json`](../assets.json) | Pinned upstream runtime/template URLs, sizes and SHA-256 hashes. |
| [`settings.reg`](../settings.reg) | Windows version, graphics, desktop and initial game window settings. |
| [`display/FullscreenDisplay.swift`](../display/FullscreenDisplay.swift) | Separate native virtual-display/mirroring helper with Test, Keep and Restore controls. |
| [`setup.py`](../setup.py), [`prepare.py`](../prepare.py), [`Launcher.swift`](../Launcher.swift) | Earlier local source-build route and its launcher; distinct from `portable/`. |
| [`tests/PortableCoreTests.swift`](../tests/PortableCoreTests.swift) | Core checks that run without downloading or executing the game. |

The portable launcher calculates paths from the current user's Application Support directory. Mutable data is outside the app:

```text
~/Library/Application Support/MapleRoyalsLauncher/
  downloads/
  runtimes/cx24-0.7_5-template-1.0.15/
  prefixes/cx24-0.7_5-template-1.0.15/
  logs/launcher.log
  logs/previous-launch.log
  installation.json
```

The portable app can move without relocating its data. It does not import the older `MapleRoyals-PoC` installation. On first run it verifies and provisions the runtime, runs the user's official installer, applies settings, and writes the installed marker only after success. Later launches execute the installed game directly. The launcher stays open while the game runs and currently permits one client at a time. See [portable implementation details](PORTABLE_APP.md) for lifecycle and failure behavior.

### Working runtime configuration

The tested configuration is `WS12WineCX24.0.7_5` plus Template 1.0.15 native libraries under Rosetta, using a `win64` WoW64 prefix for the 32-bit Windows client. It keeps the game executable unchanged.

- Windows 7; builtin Direct3D 8 → WineD3D → OpenGL; Direct3D `renderer=gl` and `csmt` DWORD 0.
- `WINEARCH=win64`, `WINEMSYNC=1`, `WINEESYNC=0`, `WINEDEBUG=-all`, `WINEDLLOVERRIDES=mscoree,mshtml=`.
- Explicit per-user `WINEPREFIX`, matching `WINESERVER`, runtime `PATH`, and template Frameworks plus `/usr/lib` in `DYLD_FALLBACK_LIBRARY_PATH`.
- Wine desktop registry set to 1024×768; this does not establish the game's actual viewport or the physical display resolution.
- No custom `iphlpapi.dll`, DXVK, D9VK or D3DMetal activated.

The launch command is passed as a process argument array, with the installed game directory as the working directory:

```text
wine C:\MapleRoyals\MapleRoyals.exe
```

The original [configuration reference](CONFIGURATION.md) documents the older route's generated paths and advanced commands. The portable path construction and environment are in `PortableCore.swift`; do not copy workspace-specific paths into a distributable app.

## Development checks

Run the core regression checks without downloading or executing the game:

```sh
mkdir -p build
xcrun swiftc -swift-version 5 -O -module-cache-path build/module-cache \
  portable/PortableCore.swift tests/PortableCoreTests.swift -o build/portable-core-tests
build/portable-core-tests .
```

The checks cover tampered downloads, wrong installer input before download, exclusive ownership, portable paths, environment isolation, and preservation of existing runtime data. The ZIP builder also verifies its generated app signatures. These checks do not establish game compatibility.

For runtime or launch changes, test progressively: executable start, login, world/channel, character/PIC if prompted, game entry, map changes, keyboard/mouse, windowed resolution, normal exit and cold relaunch. Inspect logs at the failing stage. Verify the actual loaded runtime and graphics path instead of inferring it from setup-time GPU enumeration. Only add concurrent-client support after explicit gameplay testing.

Preserve a working installation before a runtime/prefix migration. Do not silently reuse it as evidence of a clean setup. The current [ZIP acceptance record](ZIP_ACCEPTANCE.md) identifies the exact tested artifact and separates user-observed gameplay from process/log verification. [Source-export validation](VALIDATION.md) and [research history](RESEARCH.md) preserve the earlier checks and failed renderer experiments.

Known limits include one unexplained initial character-loading failure, poorer 1024×768 performance, and untested second-Mac/Rosetta/Gatekeeper flows. Missing-Rosetta, external displays, sleep/wake and long-session reliability need further testing. No production notarization is claimed.

## Fullscreen helper development

The portable builder already includes both display apps. Their [player instructions](PLAYER_GUIDE.md#fullscreen-with-black-side-bars) cover normal use. To build just one helper, choose one of these commands and an unused output path:

```sh
python3 display/build.py --output "$HOME/Applications/MapleRoyals Display.app"
```

For a compatible 120 Hz ProMotion panel, use this instead:

```sh
python3 display/build.py --output "$HOME/Applications/MapleRoyals Display.app" --refresh-hz 120
```

The helper creates a non-HiDPI 1024×768 virtual display and mirrors it to the built-in screen. It changes the whole desktop while active, and restores on its normal exit or Restore action. The launcher does not start or stop it automatically. The 20-second rollback applies only until the user chooses Keep.

Fullscreen scaling of only the game while macOS stays at its normal resolution is **not implemented**. A future window-capture/presentation approach needs independent latency, input-coordinate and focus testing; it is not a proven performance fix. See [display implementation notes](../display/README.md) and the included DeskPad MIT notices for the current private CoreGraphics API dependency.

## Older local source setup

This route builds the original launcher in `~/Library/Application Support/MapleRoyals-PoC`. Use `portable/build.py` when making a ZIP for someone else; the original app contains paths specific to its installation and is not independently portable.

Download the official Windows WZ installer from [MapleRoyals](https://royals.ms/downloads), leaving it as an `.exe`. With the prerequisites above installed, run:

```sh
python3 setup.py --check
python3 setup.py --plan
python3 setup.py
```

`--check` only checks prerequisites. `--plan` asks for the installer and previews setup without downloads or writes. The final command prompts for an installer in Downloads (or a typed/dragged path), confirms the destination, downloads verified runtime archives and builds the app. Leave Terminal open until **Build finished**. The game installer runs later from the native launcher, not from this build command.

### Finish the local game installation

In Finder, use **Shift + Command + G** to open `~/Library/Application Support/MapleRoyals-PoC`, then open its `MapleRoyals.app`. Complete the official Windows installer at `C:\MapleRoyals`, including its Visual C++ prompts. Review terms yourself, disable the installer's Launch MapleRoyals checkbox if offered, and click Finish. The launcher applies settings and launches the game. Start with 800×600.

Keep that Application Support folder and its app at their original location. Later launches need no Terminal. After closing a game, the original launcher's **Launch another client** button can start a replacement session; two simultaneous clients remain untested. The portable app instead has a **Play** button and enforces one client.

For a scripted build and diagnostic options, see [configuration and advanced setup](CONFIGURATION.md). The Terminal recipe itself has not separately completed a fresh-install gameplay test; the later successful fresh installation used the portable ZIP.

### Setup stopped halfway

If the app was built but game installation stopped, close the game/installer and reopen that app to retry setup. Keep the official installer until installation succeeds.

If the Terminal build failed in a folder that has **never held a successfully installed or played game**, preserve it by renaming `MapleRoyals-PoC` to a unique name such as `MapleRoyals-PoC-incomplete`, then rerun setup. This redownloads dependencies. Do not rename a working installation: its app still points to the original location. Do not overwrite or delete used prefixes to repair a build error.

An error about missing `setup.py` means the command was run outside the repository root. Compiler errors require checking the Command Line Tools installation. Keep checksum and certificate checks enabled when diagnosing download failures. Logs are in `MapleRoyals-PoC/logs` for this route and `MapleRoyalsLauncher/logs` for the portable app; review/redact them before sharing.

## Distribution boundaries

Keep game assets, used prefixes, personal logs, downloaded runtime archives and compiled apps out of Git. `.gitignore` excludes them; do not force-add them. Each player obtains the official game separately. No permission to redistribute MapleRoyals/Nexon assets was established.

The current ZIP provisions runtime archives from upstream instead of bundling them. Before redistributing Wine or template components, audit each component's license and exact corresponding source; the entire Sikarugir template must not be assumed to have one license. See [third-party notices](../THIRD_PARTY_NOTICES.md) and [packaging notes](PACKAGING.md).

Documentation changes alone do not rebuild an already distributed ZIP. Changes to `portable/START-HERE.txt` appear in the next build. Preserve the artifact/hash distinction when updating the acceptance record, and test newly built software before presenting it as validated.
