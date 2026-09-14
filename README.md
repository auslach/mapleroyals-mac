# MapleRoyals on an Apple Silicon Mac

Open the Windows MapleRoyals client through a small native Mac launcher, without CrossOver or a Wine settings interface. A ready-built hobby preview can now handle first-run setup inside the app. Recipients of that preview do not need Terminal, Python or Command Line Tools. The source-build instructions are also preserved below.

**Status: experimental.** Gameplay was confirmed on an M1 Pro MacBook Pro running macOS 26.5.2, using the July 2, 2026 WZ client. **800×600 was smoother and playable; 1024×768 still had noticeable visual lag.** On September 14, 2026, the ready-built ZIP also completed a fresh, direct-CX24 installation on this Mac: the user logged in, loaded a character on retry, and changed maps successfully. One initial character-loading failure remains unexplained. A second Mac and its first-open security/Rosetta setup remain untested. Another Mac may need troubleshooting.

This is an unofficial launcher project. It does not include the game, your account, a Windows installation, or the CrossOver application.

## Easier setup: use the ready-built preview

If someone gives you **MapleRoyals-preview.zip** or **MapleRoyals-hobby-preview.zip**, follow [the short app instructions](portable/START-HERE.txt). Unzip it, open **MapleRoyals.app**, select your official Windows WZ installer, and click **Install & Play**. Complete the Windows installer once; later launches open the game automatically. Optional fullscreen helpers are already compiled in the ZIP.

This hobby build uses no Apple Developer account and is not notarized. You may need Apple's **Open Anyway** approval for each trusted app on first launch. See [the app guide](docs/PORTABLE_APP.md) for exact steps, tested behavior and limitations. The new app uses its own `MapleRoyalsLauncher` folder in Application Support and does not replace an older installation.

**GitHub's Code → Download ZIP contains source code, not a ready-built app.** Get the compiled preview ZIP separately from the maintainer. To build that ZIP for a friend, the maintainer runs `python3 portable/build.py`. Only the build Mac needs Python and developer tools.

The ZIP has passed fresh runtime downloads, Windows installation, character loading on retry, map changes, and normal game shutdown on the original M1 Pro. Reopening the app started the installed game without repeating setup, and the user loaded their character again. See [the recorded ZIP test](docs/ZIP_ACCEPTANCE.md) for evidence and remaining checks; this was a fresh app installation on an existing Mac, not a clean second Mac.

## Build from source instead

The remaining instructions are the original Terminal setup path. Skip them if you have the ready-built preview ZIP.

## What you need

- An Apple Silicon Mac, such as an M1, M2, M3 or later. The supported target range is macOS 14–27; only the configuration above was tested. This is not a guarantee for every chip or macOS release.
- An internet connection and space for several gigabytes of game/runtime files, plus Apple's development tools. Allowing at least 10 GB free before starting is a practical budget, not a measured minimum.
- Your own MapleRoyals account and the official **Windows WZ installer**.
- Apple's Command Line Tools, Python 3.9 or newer, and Rosetta. The steps below explain these. You do **not** need full Xcode, Homebrew, a paid developer account, or CrossOver.

The optional fullscreen helper is for a MacBook's built-in display. Get the game working in a window first.

## One-time setup

### 1. Download this project and the game installer

On this project's GitHub page, click the green **Code** button, then **Download ZIP**. Double-click the downloaded ZIP to unpack it. Keep the resulting folder for now. You do not need to know Git.

Go to the [official MapleRoyals downloads page](https://royals.ms/downloads) and download the **Windows WZ** installer into your **Downloads** folder. You only need WZ for this setup; IMG was not tested. The tested filename was `MapleRoyalsSetupWz-02.07.26.exe`, but newer downloads may have a different date.

Leave the installer as an `.exe` file. **Do not double-click it or try to extract it on the Mac.** The launcher will run it later. This project does not independently authenticate game installers: use the official website.

### 2. Open Terminal and install Apple's tools

Press **Command + Space**, type **Terminal**, then press **Return**. Terminal is a text window where you can paste the commands in this guide. Paste one command at a time, then press Return. Do not type the surrounding code-block formatting.

Run:

```sh
xcode-select --install
```

Follow Apple's installation window and wait until it finishes. If Terminal says the tools are already installed, continue. This installs the compiler used to build the Mac launcher; it does not install the full Xcode app. [Apple's instructions](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)

Next, install Rosetta if it is not already installed:

```sh
softwareupdate --install-rosetta
```

Complete Apple's prompts, including reviewing and accepting its terms if you agree. Rosetta lets this Intel Wine runtime run on Apple Silicon. [Apple's Rosetta information](https://support.apple.com/en-us/102527)

### 3. Check Python

Run:

```sh
python3 --version
```

If the result is Python **3.9 or newer**, continue. For example, 3.10, 3.11, 3.12 and later satisfy that requirement.

If the command is unavailable or the version is older, install a current Python 3 release using the **macOS installer** from [Python.org](https://www.python.org/downloads/macos/). Close Terminal, open it again, and repeat the version check after installation. No extra Python packages are required.

### 4. Run the guided setup

Tell Terminal which folder contains this project:

1. Type `cd` followed by **one space**. Do not press Return yet.
2. Drag the unpacked project folder from Finder into the Terminal window.
3. Press **Return**.

The folder you drag should contain this README and `setup.py`, not the ZIP file or its parent Downloads folder.

Now run:

```sh
python3 setup.py
```

The script checks the tools, then lists matching WZ installers found in Downloads. Type the number of the installer you just downloaded and press Return. If it is not listed, drag the `.exe` file from Finder into Terminal and press Return instead.

Review the selected filename and installation folder. Type **y** and press Return to continue. The script downloads about 260 MB of pinned Wine/runtime archives, checks their SHA-256 hashes, and builds the Mac launcher. Leave Terminal open until it prints **Build finished**. This can take several minutes.

The files are kept in your own account at:

```text
~/Library/Application Support/MapleRoyals-PoC
```

The `~` means your home folder. You do not need to replace it when using Finder's Go to Folder command below. Existing installations are not overwritten.

### 5. Open the app and finish the game installation

1. In Finder, press **Shift + Command + G** to open **Go to Folder**.
2. Paste `~/Library/Application Support/MapleRoyals-PoC` and press Return.
3. Double-click **MapleRoyals.app**.
4. Wait while its first-run setup prepares the Windows environment. The official game's Windows installer should then appear.
5. Follow the installer, review any terms yourself, and keep the install location as **`C:\MapleRoyals`**. That is a folder inside this app's private environment, not a new Mac disk.
6. Complete any included Visual C++ runtime installation prompts. At the end, turn off **Launch MapleRoyals** in the installer if that option is offered; our launcher will start it after applying the settings. Click **Finish**.
7. Wait for the launcher to apply the settings and start the game. Sign in normally and select **800×600** in the game's options for the smoother tested result.

If macOS asks this locally built app to access Downloads to read the installer you selected, allow that access if the request matches what you are doing. No step requires disabling System Integrity Protection, Gatekeeper, antivirus protection or certificate checks. If a different security warning blocks startup, stop and share the exact wording with the project maintainer.

Keep account passwords and your PIC inside the game. Do not put them in a GitHub issue or send them with logs.

## Playing next time

Open the same **MapleRoyals.app**. It should skip completed installation and launch the game. You no longer need Terminal for normal play.

You can drag the app into the Dock for a shortcut. **Keep the `MapleRoyals-PoC` folder in Application Support in place:** it contains the game and its runtime. You can remove the downloaded project folder after setup, although keeping it is useful for rebuilding or troubleshooting.

If the launcher is already open after you close a game session, its **Launch another client** button also starts a new session. Despite that button's name, two simultaneous clients have not yet been gameplay-tested. Close the first game before using it for a replacement session.

Quit the game using its own menu. Quitting the small launcher window alone does not necessarily close the game.

## Optional: fullscreen with black side bars

The game's fullscreen toggle alone did not stretch the picture correctly on the tested Mac. This separate helper temporarily changes how macOS displays the picture. It does not fix the 1024×768 performance problem.

Close the game before changing the display setup. In Terminal, return to the project folder as in step 4. Build the helper once:

```sh
python3 display/build.py --output "$HOME/Applications/MapleRoyals Display.app"
```

This uses 60 Hz. If you have a MacBook Pro with a 120 Hz ProMotion display and want the configuration last used on the test Mac, use this command **instead**:

```sh
python3 display/build.py --output "$HOME/Applications/MapleRoyals Display.app" --refresh-hz 120
```

Choose one command. The builder refuses to overwrite an existing helper. A 120 Hz display setting does not mean the game renders at 120 frames per second.

In Finder, use **Shift + Command + G**, enter `~/Applications`, and open **MapleRoyals Display.app**. Click **Test**, then **Keep this display** within 20 seconds. If you do nothing, the test restores your display automatically. Keep the helper open while playing, then launch the game and use **Option + Return** to toggle its fullscreen mode if needed.

When finished, close the game and click **Restore normal display** in the helper, or quit the helper. This returns the Mac's normal display presentation. The helper affects the whole Mac screen while active, not just the game window.

Its virtual display is 1024×768, but the game can still be set to **800×600**. These are separate settings. The main launcher does not start or stop this helper automatically. The helper uses private macOS display APIs; other macOS versions, external displays, sleep/wake and unexpected crashes have not been fully tested.

## If something goes wrong

| What you see | What to do |
|---|---|
| `can't open file ... setup.py` | Terminal is in the wrong folder. Repeat the `cd` and drag-folder instructions in step 4. |
| Compiler or developer-tools error | Finish `xcode-select --install`, then retry. Full Xcode is not required. |
| No installer listed | Download the official Windows WZ installer, then drag its `.exe` into the setup prompt. |
| Download or certificate error | Check your connection and Python installation. Keep checksum and certificate checks enabled; record the error for the maintainer. |
| Existing installation folder | Open the existing app if setup previously finished. See the recovery instructions below if it stopped halfway. |
| Character-selection crash or game never appears | One initial character-loading failure occurred in the fresh ZIP test; retrying then worked, but the cause is unknown. If it happens again, use **Show log** and record whether the whole game closed or returned to login, plus your Mac chip, macOS version and installer filename. |
| 1024×768 is laggy | Use 800×600. Smooth 1024×768 has not been achieved on the tested M1 Pro. |
| Picture is stuck in the top-left corner | Use the optional fullscreen helper; removing the game window border does not perform screen scaling. |
| Mac screen is still scaled after playing | Use **Restore normal display** in the helper or quit that helper. |

### Setup stopped halfway

If the app was built successfully but the Windows game installation stopped, close the game/installer and reopen **MapleRoyals.app** to retry its first-run setup. Keep the downloaded installer in place until installation finishes. The setup marker is written only after setup succeeds.

If the Terminal build failed and you have **never successfully installed or played the game in this folder**, preserve the incomplete folder rather than deleting it. In Finder, go to `~/Library/Application Support` and rename `MapleRoyals-PoC` to a unique name such as `MapleRoyals-PoC-incomplete`. Then run `python3 setup.py` again to create a new folder. This redownloads dependencies. Do not rename a working installation: its app still points to the original location. Ask for help before moving any folder that contains a game you have used.

Logs are stored in `~/Library/Application Support/MapleRoyals-PoC/logs`. They can contain local paths and user-specific details. Review and redact them before sharing; do not upload the whole installation folder.

## What this project does

The native Swift/AppKit launcher starts the standalone **WS12WineCX24.0.7_5** engine under Rosetta. Wine's new WoW64 runs the 32-bit Windows client in a 64-bit environment. The guided setup selects Windows 7, builtin Direct3D 8 → WineD3D → OpenGL, MSync on, ESync off, CSMT off, and quiet Wine logging.

The game executable is unchanged. No community `iphlpapi.dll` patch is installed. DXVK, D9VK and D3DMetal are not enabled in the playing configuration. The CX-derived engine is separate from the proprietary CrossOver application; CrossOver is not installed or required.

For technical details, see [configuration and advanced commands](docs/CONFIGURATION.md), [research and test history](docs/RESEARCH.md), [source-export validation](docs/VALIDATION.md), [packaging notes](docs/PACKAGING.md), and [third-party notices](THIRD_PARTY_NOTICES.md).

## Repository contents and sharing

- `setup.py`: guided setup for this README.
- `prepare.py`: downloader and builder used by the guided setup.
- `Launcher.swift`: native launcher source.
- `settings.reg`: Windows compatibility and display settings.
- `assets.json`: exact upstream archive URLs, sizes and hashes.
- `display/`: optional fullscreen helper and its notices.
- `docs/`: configuration, research results and future packaging work.

The repository intentionally excludes game files, downloaded runtimes, Wine prefixes, personal logs and compiled apps. `.gitignore` helps keep those out of commits. Do not force-add them. Each person obtains the official game separately. They can use a compiled preview ZIP from the maintainer or build a local launcher from source.

The apps built here are locally ad-hoc signed, without an Apple Developer account. The compiled preview now provides portable first-run setup; testing on a second Mac and first-open security prompts remain outstanding. Bundling Wine instead of downloading it would also require a component/source-license audit. Developer ID signing and notarization are optional future distribution choices. See [packaging notes](docs/PACKAGING.md).
