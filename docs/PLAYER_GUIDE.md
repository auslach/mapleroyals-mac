# Player guide: install and play

[Back to the README](../README.md) · [Developer guide](DEVELOPER_GUIDE.md)

Download the app from this repository and follow the steps below. You do **not** need Terminal, Python, Xcode, Command Line Tools, Homebrew, CrossOver, or Sikarugir.

## What you need

- An Apple Silicon Mac, such as an M1, M2, M3 or later, running macOS 14–27. Gameplay has been tested on one M1 Pro on macOS 26.5.2 and 27.0; another Mac may need troubleshooting. macOS 27 requires the updated launcher 0.6.1.
- An internet connection and about 10 GB of free space before setup. This is a practical allowance, not a measured minimum.
- Your own MapleRoyals account and the official **Windows WZ installer**.
- [MapleRoyals-Mac.zip](https://github.com/auslach/mapleroyals-mac/raw/refs/heads/main/download/MapleRoyals-Mac.zip), available directly from this repository.

## 1. Get the app and game installer

**[Click here to download MapleRoyals-Mac.zip for Apple Silicon Macs](https://github.com/auslach/mapleroyals-mac/raw/refs/heads/main/download/MapleRoyals-Mac.zip).** This is the ready-built app with both optional fullscreen helpers.

This repository is currently private. If the link asks you to sign in or shows **404 / Not Found**, sign in to a GitHub account with access to this repository.

**If you already cloned the repository:** in Finder, open your local repository folder, then **download → MapleRoyals-Mac.zip**. Use that included ZIP; you do not need to build anything or download another copy.

**If you downloaded the whole repository using Code → Download ZIP:** double-click the repository archive to unpack it, then open **download → MapleRoyals-Mac.zip** inside the unpacked repository folder.

Double-click **MapleRoyals-Mac.zip** to unpack it. Open the resulting **MapleRoyals-Mac** folder, which contains:

```text
MapleRoyals.app
Optional fullscreen/
    MapleRoyals Display 60 Hz.app
    MapleRoyals Display 120 Hz.app
START-HERE.txt
```

There may also be a build information file; you can leave it alone. Keep the **Optional fullscreen** folder if you want to use fullscreen later. Move **MapleRoyals.app** into Applications, or another folder you intend to keep. You can move the optional display apps there too.

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

If the app stopped showing a game window after a macOS 27 upgrade, get the current ZIP from [the same download link](https://github.com/auslach/mapleroyals-mac/raw/refs/heads/main/download/MapleRoyals-Mac.zip). It contains launcher **0.6.1**, which fixes the startup order.

1. Close the game normally and quit the old launcher.
2. Unpack the new ZIP. Replace the old **MapleRoyals.app** with the new one, wherever you keep it.
3. Open the new app. It finds the game already installed in your Mac account. You do not need the installer again. The first tested launch after updating took about 90 seconds; leave the launcher open while it starts.

Keep `~/Library/Application Support/MapleRoyalsLauncher` in place. Replacing the app does not replace or delete your game data. This update fixes startup; it does not claim to improve 1024×768 performance.

## Playing next time

Open the same **MapleRoyals.app**. It starts the installed game without repeating setup. If the small launcher is already open after a game session, click **Play**.

Keep the launcher open while playing. When finished, close the game normally before quitting the launcher. This preview supports one game client at a time.

Your game files stay in your Mac account even if you move the app. You can add the app to the Dock for easy access. Keep the game data folder in place; if you need to find it, use **Game files** in the launcher.

## Fullscreen with black side bars

The **display helper** is a separate small Mac app included in the ZIP. It temporarily scales the built-in screen so the game's picture fills its height, with black bars at the sides. It requires no extra download or build step.

**While it is active, the whole Mac desktop is scaled too—even when you switch to another app.** Today's preview cannot enlarge only the game while keeping the desktop at its normal resolution. Use the helper only while playing, and restore your display afterward.

1. **Close the game first.** Get the game working in a normal window before trying this.
2. Open the ZIP's **Optional fullscreen** folder, then open **MapleRoyals Display 60 Hz.app**. Start with this version if you are unsure. **MapleRoyals Display 120 Hz.app** is intended for a compatible 120 Hz ProMotion MacBook Pro, such as the tested M1 Pro. **Run only one display helper at a time.**
3. Click **Test 1024×768 display**. The Mac screen will change.
4. If the picture looks right, click **Keep this display** within **20 seconds**. If you do nothing, the helper restores the previous display automatically.
5. Leave the helper open and open **MapleRoyals.app**. Inside the game, press **Option + Return** if needed to toggle its fullscreen mode.
6. You can still set the **game** to **800×600** for smoother performance. The helper's 1024×768 setting and the game's resolution are separate. A 120 Hz helper does not mean the game runs at 120 frames per second.

### Return your Mac to its normal display

1. Close the game normally.
2. Switch to the display helper and click **Restore normal display**, or quit that helper with **Command + Q**.

Closing the game alone does **not** stop the helper. If your desktop still has side bars afterward, return to the helper and restore it. You can reopen and use the same helper on your next session. If macOS blocks a helper's first launch, use the first-open instructions below for that app too.

The helper was tested on the M1 Pro's built-in display on macOS 26.5.2; it has not been revalidated on macOS 27. Other displays, sleep/wake and unexpected crashes have not been fully tested. It does not fix the slower 1024×768 game performance.

## If macOS blocks the first open

This hobby preview uses no Apple Developer account and is not notarized. If macOS says the developer is unidentified or Apple cannot check the app, and you trust this unchanged app downloaded from this repository:

1. Attempt to open the app once.
2. Open **System Settings → Privacy & Security**.
3. Find the notice for that app, click **Open Anyway**, then confirm **Open**.

The game launcher, Rosetta helper and display helper may need separate first-open approvals. Apple documents this in [Safely open apps on your Mac](https://support.apple.com/en-us/102445).

Do not disable system security or override a malware/damaged-app warning. Work or school Macs may prohibit these exceptions. The exact prompts after downloading this ZIP onto another Mac remain untested. If a different warning appears, send its wording to the maintainer.

## If something goes wrong

| What you see | What to do |
|---|---|
| Download link shows 404 / Not Found | This repository is private. Sign in to GitHub with an account that has access. |
| Source files but no app | Open **download → MapleRoyals-Mac.zip** in the repository folder and unpack that ZIP. You do not need to run `setup.py`. |
| Setup stopped partway through | Close the game and installer, quit the launcher, then reopen it and choose the official installer again if asked. Keep the installer until setup finishes. If the problem repeats, use **Show log** and contact the maintainer. |
| No game window after upgrading to macOS 27 | Follow **Updating an existing installation** above. Use launcher 0.6.1; do not delete or reinstall your game data. |
| The game fails when selecting a character | One initial failure occurred during testing, followed by a successful retry. Its cause is unknown. If it repeats, report whether the entire game closed or it returned to login. |
| 1024×768 feels laggy | Use **800×600**. Fullscreen scaling does not fix this rendering-performance difference. |
| The game stays small in the top-left corner | Follow the fullscreen helper steps above. The game's fullscreen toggle alone did not scale correctly on the tested Mac. |
| The desktop is still scaled after playing | Click **Restore normal display** in the helper, or quit the helper. |
| The app or download shows an error | Use **Show log** and send the maintainer the error, your Mac model/chip, macOS version and installer filename. |

Logs can contain your local username and file paths. Review them before sharing, and never send your password, PIC or the whole game folder.

Fresh setup, character loading on retry, map changes, normal shutdown and reopening were confirmed on the original M1 Pro. Another Mac and long-session reliability remain unverified. For the full record, see [the test results](ZIP_ACCEPTANCE.md).
