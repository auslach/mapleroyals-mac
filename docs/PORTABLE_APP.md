# Ready-built hobby preview

A maintainer can now build a ZIP containing `MapleRoyals.app`, an Intel compatibility helper inside it, two optional fullscreen apps, and `START-HERE.txt`. Recipients do not need Python, Command Line Tools, Xcode, Homebrew, Git, CrossOver, or the Sikarugir application. They still need an Apple silicon Mac, an internet connection, Rosetta when requested, their own account, and the official WZ installer.

This is an experimental preview. A fresh install through gameplay on a second Mac is not yet validated. Earlier gameplay was confirmed using the migrated CX24 prefix on the original M1 Pro. Smooth 1024×768 remains unresolved.

## What the recipient does

1. Unzip the supplied preview ZIP and move `MapleRoyals.app` to a folder they keep, such as Applications.
2. Download the official Windows WZ installer from [MapleRoyals](https://royals.ms/downloads).
3. Open the app. If requested, use **Enable Rosetta**, complete Apple's prompt, then **Check again**.
4. Use **Choose game installer…**, select the WZ `.exe`, then **Install & Play**.
5. Complete the official Windows installer, keeping `C:\MapleRoyals`. Turn off its launch-game checkbox before Finish. The launcher applies the configuration and starts the game.
6. On later visits, open the app to start the installed game automatically.

The GitHub **Code → Download ZIP** button supplies source code, not this compiled ZIP. The maintainer must send the built ZIP separately or upload it as a release asset. No release is uploaded by the build script.

## No Apple Developer account

The default build uses an ad-hoc signature (`codesign --sign -`). It uses no Apple account, Developer ID certificate, team identity, or notarization credentials. The generated app reports `TeamIdentifier=not set`.

The recipient may need **System Settings → Privacy & Security → Open Anyway** after first attempting to open this trusted app. Apple documents this per-app exception in [Safely open apps on your Mac](https://support.apple.com/en-us/102445). The optional apps and Intel helper can require separate approvals. Do not disable Gatekeeper, SIP or malware checks, and do not override a malware/damaged-app warning. Managed Macs may prohibit exceptions. A downloaded/quarantined copy on a second Mac has not been tested yet, so the exact number and wording of macOS prompts are unverified.

Developer ID signing and notarization remain an optional future distribution choice, not a prerequisite for this hobby build. Apple documents their role in [Developer ID guidance](https://developer.apple.com/developer-id/). No Apple account is used for this preview.

## Rosetta and supported systems

The launcher is compiled for arm64 and macOS 14. It accepts macOS 14–27; only macOS 26.5.2 on the original M1 Pro has been exercised. It checks Intel execution with the macOS-provided `arch` tool. When this fails, it opens a tiny Intel-only app built from our own `RosettaCheck.swift`, so Launch Services can offer Apple's Rosetta installer. It does not bundle Apple binaries or automatically accept Apple's terms.

Rosetta was already installed on the test Mac. The missing-Rosetta prompt path has not been exercised on a clean machine. Apple says opening an Intel app offers installation when needed, and currently describes general Rosetta availability through macOS 27. Do not assume that this Wine engine qualifies for macOS 28's limited legacy-game exception. [Apple's current Rosetta information](https://support.apple.com/en-us/102527)

## What the app manages

`PortableCore.swift` downloads the same pinned CX24 engine and template as the source recipe using Foundation URLSession. It verifies size and SHA-256 before extraction, stages extraction before activating the runtime, preserves unrecognized existing directories, and uses an exclusive installation lock. Downloads remain in a local cache. An interrupted extraction is not marked as a ready runtime. An interrupted game setup is not marked as installed.

Mutable data lives outside the app, at a location computed from the current macOS account:

```text
~/Library/Application Support/MapleRoyalsLauncher/
  downloads/
  runtimes/cx24-0.7_5-template-1.0.15/
  prefixes/cx24-0.7_5-template-1.0.15/
  logs/launcher.log
  logs/previous-launch.log
  installation.json
```

This is separate from the older source recipe's `MapleRoyals-PoC` directory. It does not import, change, or migrate that installation. The app itself can move without changing the data directory. No developer home directory or installer path is built into the distributable app.

The runtime is `WS12WineCX24.0.7_5` plus Template 1.0.15 native libraries. The environment uses a win64 WoW64 prefix, MSync on, ESync off, builtin Direct3D 8 → WineD3D → OpenGL, quiet logging, `mscoree,mshtml=` overrides, and the same Windows 7/1024×768 virtual-desktop registry configuration plus CSMT DWORD 0. No custom `iphlpapi.dll`, DXVK, D9VK or D3DMetal is activated.

The main app uses only Apple's shipped frameworks and command-line executables (`arch`, `uname`, `tar`) plus the downloaded Wine runtime. Those system executables do not require installing developer tools. Compiling the ZIP is the maintainer's job.

The launcher stays open while setup/game processes run. Close the game before quitting the launcher. Simultaneous clients are deliberately unavailable in this version. The optional fullscreen helpers are already compiled, but remain separate apps with the existing manual Test/Keep/Restore flow.

## Build the ZIP (maintainer only)

From the repository folder on the build Mac:

```sh
python3 portable/build.py
```

This creates `dist/MapleRoyals-preview/` and `dist/MapleRoyals-preview.zip`. The default build needs no Apple login. Existing outputs are not overwritten; choose `--output` with a new folder name when rebuilding. The builder also supports an explicit `--identity` for a future separately authorized Developer ID build; it never chooses an identity automatically and never notarizes or uploads anything.

To run the core regression checks without downloading or running the game:

```sh
mkdir -p build
xcrun swiftc -swift-version 5 -O -module-cache-path build/module-cache \
  portable/PortableCore.swift tests/PortableCoreTests.swift -o build/portable-core-tests
build/portable-core-tests .
```

## Validation on September 14, 2026

- Compiled the arm64 launcher and Intel helper, plus both fullscreen helpers.
- Verified all four local signatures; none has a Team Identifier. Checked the compiled minimum macOS version of every helper and launcher: 14.0. The ZIP was checked for game/runtime binaries, logs, and embedded build-user paths; none were present.
- Checked the native first-run screen visually and selected the official WZ installer using computer use.
- The app downloaded both real upstream archives, passed the integrity checks, unpacked them, and successfully completed fresh `wineboot -u` plus `wineserver -w`.
- It started the official WZ installer process. Activity Monitor inspection confirmed that the process loaded the installer and libraries from the new portable runtime. The automation could not attach to Wine's Windows UI; installation through gameplay was not completed in this test.
- Interrupted this isolated test through Activity Monitor. The launcher reported the failed process and re-enabled setup controls instead of marking the game installed. Wine child processes left by the forced interruption were stopped manually; automatic recovery from forced termination is not established.
- Core checks passed for tampered-download rejection, wrong-installer rejection before download, exclusive ownership, portable paths, renderer-environment isolation, and preserving existing runtime data.

Still unverified: a second Mac, absent-Rosetta setup, first-open prompts after internet transfer, Windows installer completion and gameplay through this new flow, sleep/wake recovery, and fullscreen helper behavior on other displays. This app reduces setup work; it does not establish new game compatibility or improve the original 1024×768 performance result.

## Contents and licensing

The ZIP contains our compiled launcher and helpers, configuration, and notices. It includes no Wine binaries, game installers, EXE/WZ/IMG game assets, used prefixes, or personal logs. The optional helper includes the DeskPad MIT notices. Runtimes are downloaded from their maintainers on each recipient's Mac. See [third-party notices](../THIRD_PARTY_NOTICES.md) for component and redistribution scope.
