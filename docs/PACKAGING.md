# Source sharing and app packaging

A native downloadable preview is now implemented in `portable/`; see [the app guide](PORTABLE_APP.md) for its build, user flow and validation. Its default hobby build uses no Apple Developer account and accepts the possibility of per-app first-open approvals. The remaining notes describe the original source recipe and optional future distribution work.

This repository also shares source and a local build recipe. Each person downloads runtime archives from their maintainers and obtains the official Windows game installer. It is not a prebuilt app release, and no GitHub repository or release is created by these scripts.

The native preview now provides a first-run setup flow that checks the supported OS/Rosetta combination, provisions verified runtime artifacts, accepts the user's official game installer, and initializes a fresh prefix. Keep subsequent launches as a simple Play action. Integrate the fullscreen helper and restore the display when the game exits, including a tested recovery path for interrupted sessions.

Suggested layout:

```text
MapleRoyals.app/
  Contents/MacOS/MapleRoyals
  Contents/Resources/runtime-manifest.json
  Contents/Resources/licenses/

~/Library/Application Support/MapleRoyals/
  runtimes/<version>/
  prefixes/<runtime-version>/
  logs/
```

Keep mutable Windows/game state outside the signed app. Remove absolute references to the developer's workspace. Pin versions, preserve rollback when migrating prefixes, and validate a clean installation and gameplay on a second Mac before describing it as supported.

The original native launcher is under 200 KB, while the runtime and full template libraries together occupy roughly 900 MB uncompressed, excluding the multi-gigabyte game/prefix. Removing unused libraries needs a dependency and gameplay audit; do not assume a small launcher means a small complete installation.

For an optional future prebuilt download intended to open without unidentified-developer exceptions, use Developer ID signing and Apple's notarization process, including nested runtime code. Local ad-hoc signatures do not establish distribution readiness. [Apple Developer ID guidance](https://developer.apple.com/developer-id/)

Before bundling binaries, establish the applicable licenses and exact corresponding source for the pinned Wine build and each native dependency. Do not treat the whole Sikarugir template as LGPL: its own component statements distinguish Configure from Launcher/Creator, and its D3DMetal payload has separate restrictions. [Sikarugir component statements](https://github.com/Sikarugir-App/Sikarugir), [Wine LGPL text](https://raw.githubusercontent.com/wine-mirror/wine/master/COPYING.LIB)

No permission to redistribute MapleRoyals/Nexon game assets was established. Do not publish a used prefix or bundle EXE/WZ/IMG files from an installation. Have users obtain the official game. [MapleRoyals downloads](https://royals.ms/downloads), [game terms](https://royals.ms/forum/threads/mapleroyals-game-terms-conditions.86769/)

The app is a launcher using an existing compatibility runtime; it is not a new Windows compatibility layer. A CX-derived Wine engine is not the proprietary CrossOver product. CodeWeavers' FOSS source publication is relevant, but exact source correspondence for the Sikarugir prebuilt artifact still needs verification before repackaging. [CodeWeavers FOSS sources](https://www.codeweavers.com/crossover/source)
