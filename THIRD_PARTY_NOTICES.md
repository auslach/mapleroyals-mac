# Third-party components and scope

This repository contains the native launcher, local provisioning scripts, documentation, optional display-helper sources, and a ready-built native launcher/helper ZIP at `download/MapleRoyals-Mac.zip`. It does not contain Wine binaries, game files, installed Microsoft redistributables, or the Sikarugir application bundle.

## Included material

The private CoreGraphics declarations in `display/CGVirtualDisplayPrivate.h` were taken from the MIT-licensed DeskPad project at inspected commit `c3349f0e237e000cb4826fb3ea1cdd1c44949461`. Keep [its full license](display/DeskPad-LICENSE.md) and [provenance notice](display/NOTICE.md) with this material. The display-helper build copies those notices into its generated app.

## Downloaded on the user's Mac

`assets.json` records upstream archive URLs and hashes. The setup downloads the chosen Wine engine and template from the Sikarugir maintainers' GitHub releases. It uses the template's native dependency libraries; it does not run Sikarugir Creator or its Launcher.

Wine is distributed under LGPL terms. Other runtime libraries and Sikarugir components have their own licenses. These downloads are not relicensed by this repository. No blanket permission to repackage the entire template is asserted here. Bundling or mirroring those binaries requires a separate review of notices, corresponding source and other applicable obligations. [Wine license](https://raw.githubusercontent.com/wine-mirror/wine/master/COPYING.LIB), [Sikarugir component statements](https://github.com/Sikarugir-App/Sikarugir)

The game and its Windows redistributables come from the installer selected by the user. No ownership or redistribution rights in MapleRoyals/Nexon assets are claimed. Obtain the game from [the official download page](https://royals.ms/downloads). Do not upload installed game folders or user prefixes to this repository.

Rosetta and Apple's Command Line Tools are installed separately through Apple. They are not bundled here. The default build locally ad-hoc signs generated apps. The tracked hobby app ZIP is not notarized and uses no Apple Developer account. The build script does not publish a GitHub Release.
