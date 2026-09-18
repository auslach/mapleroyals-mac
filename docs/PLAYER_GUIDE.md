# Player guide: install and play

[Back to the README](../README.md) · [Developer guide](DEVELOPER_GUIDE.md)

Download the app from this repository and follow the steps below. You do **not** need Terminal, Python, Xcode, Command Line Tools, Homebrew, CrossOver, or Sikarugir.

## What you need

- An Apple Silicon Mac, such as an M1, M2, M3 or later, running macOS 14–27. Gameplay has been tested on one M1 Pro on macOS 26.5.2 and 27.0; another Mac may need troubleshooting. Use the current launcher 0.7.0, which includes the macOS 27 startup fix and fullscreen controls.
- An internet connection and about 10 GB of free space before setup. This is a practical allowance, not a measured minimum.
- Your own MapleRoyals account and the official **Windows WZ installer**.
- [MapleRoyals-Mac.zip](https://github.com/auslach/mapleroyals-mac/raw/refs/heads/main/download/MapleRoyals-Mac.zip), available directly from this repository.

## 1. Get the app and game installer

**[Click here to download MapleRoyals-Mac.zip for Apple Silicon Macs](https://github.com/auslach/mapleroyals-mac/raw/refs/heads/main/download/MapleRoyals-Mac.zip).** This is the ready-built app with fullscreen controls included.

This repository is currently private. If the link asks you to sign in or shows **404 / Not Found**, sign in to a GitHub account with access to this repository.

**If you already cloned the repository:** in Finder, open your local repository folder, then **download → MapleRoyals-Mac.zip**. Use that included ZIP; you do not need to build anything or download another copy.

**If you downloaded the whole repository using Code → Download ZIP:** double-click the repository archive to unpack it, then open **download → MapleRoyals-Mac.zip** inside the unpacked repository folder.

Double-click **MapleRoyals-Mac.zip** to unpack it. Open the resulting **MapleRoyals-Mac** folder, which contains:

```text
MapleRoyals.app
START-HERE.txt
```

There may also be a build information file; you can leave it alone. Move **MapleRoyals.app** into Applications, or another folder you intend to keep. No separate fullscreen apps are needed.

Go to the [official MapleRoyals downloads page](https://royals.ms/downloads) and download the **Windows WZ** installer into Downloads. Leave it as an `.exe` file; do not try to open or extract it in Finder. You only need WZ for this setup. IMG was not tested. The tested file was `MapleRoyalsSetupWz-02.07.26.exe`; newer releases may behave differently.

## 2. Open the app

Double-click **MapleRoyals.app**. If macOS blocks it on first opening, follow [the first-open instructions below](#if-macos-blocks-the-first-open).

If the launcher says Rosetta is needed, click **Enable Rosetta**. Complete Apple's installation prompt yourself, then return to the launcher and click **Check again**. Rosetta lets this Mac run the Intel support software used by the game. If no Rosetta prompt appears, continue.

## 3. Install the game once

1. Click **Choose game installer…** and select the official WZ `.exe` you downloaded.
2. Click **Install & Play**. The app downloads about 260 MB of support files and prepares the game environment. Leave the app open; this can take several minutes.
3. When the Windows installer appears, follow its prompts and review any terms yourself. Keep the destination as **`C:\MapleRoyals`**. This is a folder managed by the app, not a new disk on your Mac.
4. Complete any included **Visual C++** installation prompts.
5. At the end, turn **off** the installer's **Launch MapleRoyals** checkbox if it is offered, then click **Finish**. Our launcher applies the settings and starts the game.
6. Sign in inside the game. Choose **800×600** in the game options for the smoother tested result.

If macOS asks for access to Downloads so the app can read the installer you selected, allow that access if it matches what you are doing. Keep passwords and your PIC inside the game; never send them in chat, logs, or GitHub issues.

## Updating an existing installation

If the app stopped showing a game window after a macOS 27 upgrade, get the current ZIP from [the same download link](https://github.com/auslach/mapleroyals-mac/raw/refs/heads/main/download/MapleRoyals-Mac.zip). It contains launcher **0.7.0**, which includes the startup fix and fullscreen controls.

1. Close the game normally and quit the old launcher. If you used an old fullscreen helper, restore your display and quit that helper too.
2. Unpack the new ZIP. Replace the old **MapleRoyals.app** with the new one, wherever you keep it.
3. Open the new app. It finds the game already installed in your Mac account. Choose your display option and click **Play**. You do not need the installer again. Game startup after the macOS upgrade has sometimes taken about 90 seconds; leave the launcher open while it starts.

Keep `~/Library/Application Support/MapleRoyalsLauncher` in place. Replacing the app does not replace or delete your game data. This update fixes startup; it does not claim to improve 1024×768 performance.

## Playing next time

On the first opening of version 0.7.0, choose a **Display** option and click **Play**. Start with **Normal Mac display** if you want to keep the Mac desktop unchanged.

Leave **Start automatically next time** checked to have later double-click launches reuse your saved choice. Turn it off if you prefer to see the options before each session. When the launcher is already open after a game session, change the options if needed and click **Play**.

Keep the launcher open while playing. Close the game normally before quitting the launcher. The app waits for its game processes to finish, then restores any fullscreen display it created. This preview supports one game client at a time.

Your game files stay in your Mac account even if you move the app. You can add the app to the Dock. Use **Game files** to find the data folder; keep that folder in place.

## Fullscreen with black side bars

Fullscreen is part of **MapleRoyals.app**. You do not need to open a separate resizer. If an old display helper is running, restore and quit it first.

**While fullscreen scaling is active, the whole Mac desktop is scaled too—even when you switch to another app.** The app restores the desktop when the game closes. Scaling only the game while keeping the desktop unchanged is not implemented.

1. Close the game if it is already running. In the launcher, choose **Fullscreen scaling — 800×600** or **Fullscreen scaling — 1024×768** from **Display**.
2. Choose **60 Hz**, or **120 Hz** for a compatible ProMotion MacBook Pro such as the tested M1 Pro.
3. Click **Play**. The app prepares the display before starting the game.
4. The first time you use that size/rate on this display and macOS version, click **Keep & Play** within **20 seconds** if the picture looks right. If you do nothing or click **Cancel test**, your normal display returns and the game does not start. Previously confirmed modes start the game without repeating this test.
5. Set the game's resolution separately to match the selected display size. Use **800×600** in the game with the 800×600 display so the picture fits. Press **Option + Return** inside the game if it still shows window borders.
6. Close the game normally when finished. The launcher restores the normal Mac display automatically after the game processes exit.

The **Restore normal display** button is available while fullscreen scaling is active if you need to restore it sooner. To change size or refresh rate, close the game first, change the launcher options, and click Play again. Keep the launcher open while the game is running.

An 800×600 display mode is not a confirmed graphics-performance improvement; the game itself was smoother at 800×600. A 120 Hz display does not mean the game renders at 120 frames per second. Other displays, forced app termination, sleep/wake and unexpected crashes have not been fully tested.

## If macOS blocks the first open

This hobby preview uses no Apple Developer account and is not notarized. If macOS says the developer is unidentified or Apple cannot check the app, and you trust this unchanged app downloaded from this repository:

1. Attempt to open the app once.
2. Open **System Settings → Privacy & Security**.
3. Find the notice for that app, click **Open Anyway**, then confirm **Open**.

The game launcher and its Rosetta helper may need separate first-open approvals. Apple documents this in [Safely open apps on your Mac](https://support.apple.com/en-us/102445).

Do not disable system security or override a malware/damaged-app warning. Work or school Macs may prohibit these exceptions. The exact prompts after downloading this ZIP onto another Mac remain untested. If a different warning appears, send its wording to the maintainer.

## If something goes wrong

| What you see | What to do |
|---|---|
| Download link shows 404 / Not Found | This repository is private. Sign in to GitHub with an account that has access. |
| Source files but no app | Open **download → MapleRoyals-Mac.zip** in the repository folder and unpack that ZIP. You do not need to run `setup.py`. |
| Setup stopped partway through | Close the game and installer, quit the launcher, then reopen it and choose the official installer again if asked. Keep the installer until setup finishes. If the problem repeats, use **Show log** and contact the maintainer. |
| No game window after upgrading to macOS 27 | Follow **Updating an existing installation** above. Use launcher 0.7.0; do not delete or reinstall your game data. |
| The game fails when selecting a character | One initial failure occurred during testing, followed by a successful retry. Its cause is unknown. If it repeats, report whether the entire game closed or it returned to login. |
| 1024×768 feels laggy | Use **800×600**. Fullscreen scaling does not fix this rendering-performance difference. |
| The game stays small in the top-left corner | Follow the fullscreen steps above. The game's fullscreen toggle alone did not scale correctly on the tested Mac. |
| The desktop is still scaled after playing | Click **Restore normal display** in the launcher. If you used an older separate helper, restore and quit that helper. |
| The app or download shows an error | Use **Show log** and send the maintainer the error, your Mac model/chip, macOS version and installer filename. |

Logs can contain your local username and file paths. Review them before sharing, and never send your password, PIC or the whole game folder.

Fresh setup, character loading on retry, map changes, normal shutdown and reopening were confirmed on the original M1 Pro. Another Mac and long-session reliability remain unverified. For the full record, see [the test results](ZIP_ACCEPTANCE.md).
