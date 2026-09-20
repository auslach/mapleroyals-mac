# MapleRoyals on an Apple Silicon Mac

Run the Windows MapleRoyals client through a small native Mac launcher, without CrossOver or a Wine settings interface. The ready-built preview handles setup inside the app; players do not need Terminal, Python or developer tools.

## Download and play

**[Download MapleRoyals-Mac.zip for Apple Silicon Macs](https://github.com/auslach/mapleroyals-mac/releases/download/v0.1.0/MapleRoyals-Mac.zip)** · [Version 0.1.0 release notes](https://github.com/auslach/mapleroyals-mac/releases/tag/v0.1.0)

1. Download the app ZIP above, then double-click it to unpack it.
2. Open **MapleRoyals.app** in the unpacked folder.
3. Follow the **[player setup instructions](docs/PLAYER_GUIDE.md)** to download the official Windows WZ game installer and complete first-time setup.

**Already cloned this repository?** Open **[download/MapleRoyals-Mac.zip](download/MapleRoyals-Mac.zip)** in your local repository folder. It is the same ready-built app; no build commands are needed. If you used GitHub's **Code → Download ZIP**, unpack that repository archive first, then open the app ZIP inside its **download** folder.

## Choose your guide

- **[Player guide: install and play](docs/PLAYER_GUIDE.md)** — get the right ZIP, complete first-time setup, launch the game, use fullscreen, and restore your normal Mac display. Written for people who just want to play.
- **[Developer guide: build and extend the project](docs/DEVELOPER_GUIDE.md)** — prerequisites, building a shareable ZIP, source layout, runtime configuration, development checks, and the older Terminal setup route.

## Fullscreen

Fullscreen controls are inside **MapleRoyals.app** (version **0.1.0**). The usual flow is:

1. Open the app. **800×600** is selected; the display and game stay unchanged.
2. Click **Change screen resolution** to apply it. You can select **1024×768** instead, and choose **60 Hz** or **120 Hz**. A new mode asks you to **Keep resolution** within 20 seconds.
3. Click **Play** to start the game.

Opening the launcher never starts the game or applies a resolution, even after upgrading from a version with auto-launch enabled. Play uses the current display; you can skip the resolution button to keep the normal Mac desktop. You can change size or refresh rate with the same controls while the game is running. The app restores any display it created when the game closes. [Player instructions](docs/PLAYER_GUIDE.md#fullscreen-with-black-side-bars)

**Fullscreen scaling still changes the whole Mac desktop while playing.** It does not scale just the game. No separate display app is needed. Close and quit any old display helper before using the combined app.

## Updating after a macOS upgrade

If no game window appears after upgrading to macOS 27, download the current ZIP (launcher **0.1.0**) above. Close the old game and launcher, unpack the new ZIP, and replace your old **MapleRoyals.app**. Open the new app and click **Play** when ready; it reuses your installed game. **Do not delete the game data folder or reinstall the game.** The launcher initializes Wine's desktop before starting MapleRoyals. [Investigation and validation](docs/MACOS_27.md)

If setup previously failed before the Windows installer appeared, version 0.1.0 applies the same desktop-first startup to the installer. Restart once, replace the app, select the same WZ installer, and retry setup. This resolved the reported installer startup failure on a second M1 Pro Mac. Detailed setup logs are available through **Show log**.

## Tested status

This is an **experimental, unofficial project**. On an M1 Pro MacBook Pro running macOS 26.5.2, the July 2, 2026 WZ client passed fresh installation, character loading on retry, map changes, normal shutdown, and reopening with another successful character load. One initial character-loading failure remains unexplained. The 0.1.0 installer startup fix was confirmed on a second M1 Pro running macOS 27.0; missing-Rosetta setup and long sessions remain unverified. [Earlier ZIP test results](docs/ZIP_ACCEPTANCE.md)

**800×600 was smoother and playable; 1024×768 still had noticeable visual lag.** Fullscreen scaling enlarges the picture but does not resolve that performance difference.

The hobby preview uses no Apple Developer account and is not notarized, so a trusted copy may require macOS **Open Anyway** approval. It includes no game assets, account data, Windows installation or CrossOver application. Each player gets the game from its official website. See [third-party notices](THIRD_PARTY_NOTICES.md).
