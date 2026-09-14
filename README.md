# MapleRoyals on an Apple Silicon Mac

Run the Windows MapleRoyals client through a small native Mac launcher, without CrossOver or a Wine settings interface. The ready-built preview handles setup inside the app; players do not need Terminal, Python or developer tools.

## Choose your guide

- **[Player guide: install and play](docs/PLAYER_GUIDE.md)** — get the right ZIP, complete first-time setup, launch the game, use fullscreen, and restore your normal Mac display. Written for people who just want to play.
- **[Developer guide: build and extend the project](docs/DEVELOPER_GUIDE.md)** — prerequisites, building a shareable ZIP, source layout, runtime configuration, development checks, and the older Terminal setup route.

**Get the compiled app ZIP from the maintainer.** GitHub's **Code → Download ZIP** downloads source code, not a ready-to-run app. The player guide explains the difference.

## Fullscreen

The app ZIP includes an **Optional fullscreen** folder containing separate 60 Hz and 120 Hz display apps. [Follow the fullscreen steps in the player guide](docs/PLAYER_GUIDE.md#fullscreen-with-black-side-bars): close the game, open one helper, choose **Test 1024×768 display**, then **Keep this display**; launch the game and leave the helper open. After playing, close the game and choose **Restore normal display**, or quit the helper.

**This currently scales the whole Mac desktop while the helper is active.** It does not scale just the game. Fullscreen that leaves the desktop at its normal resolution has not been implemented.

## Tested status

This is an **experimental, unofficial project**. On an M1 Pro MacBook Pro running macOS 26.5.2, the July 2, 2026 WZ client passed fresh installation, character loading on retry, map changes, normal shutdown, and reopening with another successful character load. One initial character-loading failure remains unexplained; a second Mac and its first-open security/Rosetta setup remain untested. [Exact ZIP test results](docs/ZIP_ACCEPTANCE.md)

**800×600 was smoother and playable; 1024×768 still had noticeable visual lag.** The fullscreen helper enlarges the picture but does not resolve that performance difference.

The hobby preview uses no Apple Developer account and is not notarized, so a trusted copy may require macOS **Open Anyway** approval. It includes no game assets, account data, Windows installation or CrossOver application. Each player gets the game from its official website. See [third-party notices](THIRD_PARTY_NOTICES.md).
