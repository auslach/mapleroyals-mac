# Configuration and advanced setup

Use the [main README](../README.md) for normal installation. The following describes the generated performance profile and the measured local result.

## Runtime configuration

`DATA` below is the permanent data directory chosen at setup. The guided setup uses `~/Library/Application Support/MapleRoyals-PoC`.

| Setting | Value |
|---|---|
| Engine | `WS12WineCX24.0.7_5`; reports `wine-9.0 (KegworksCX 24.0.7)` |
| Wine executable | `DATA/runtime/wswine.bundle/bin/wine` |
| Prefix | `DATA/prefix`; `WINEARCH=win64`; new WoW64 runs the PE32 game |
| Windows version | Windows 7 |
| Native library path | `DATA/template/Template-1.0.15.app/Contents/Frameworks:/usr/lib` |
| Wineserver | Same engine's `bin/wineserver` |
| Working directory | `DATA/prefix/drive_c/MapleRoyals` after installation |
| `WINEDLLOVERRIDES` | `mscoree,mshtml=`; disables Wine Mono/HTML components |
| `WINEMSYNC` / `WINEESYNC` | `1` / `0` with `--performance` |
| `WINEDEBUG` | `-all` with `--performance`; launcher still records setup and process results |
| Direct3D registry | `renderer=gl`; `csmt` DWORD `0` with `--performance` |
| Wine desktop | `Explorer\Desktop=Default`; `Explorer\Desktops\Default=1024x768` |
| Initial game window flag | `HKCU\Software\MapleRoyals\soFullScreen=0` |
| Recommended internal resolution | User selects 800×600; 1024×768 remains laggy |
| Render path | Game `Gr2D_DX8.dll` → builtin D3D8 → WineD3D → OpenGL |
| Graphics replacements | None; D9VK/DXVK/D3DMetal not activated |

The native launcher supplies the environment and executes this argument directly:

```text
wine C:\MapleRoyals\MapleRoyals.exe
```

The app's generated `Contents/Resources/configuration.json` records the actual paths. Wine state and game assets remain outside the app in the permanent data folder. The app reuses that data; copying the app to another Mac does not transfer or recreate it.

## Noninteractive build command

From the repository root, using the actual downloaded installer filename:

```sh
python3 prepare.py \
  --installer "$HOME/Downloads/MapleRoyalsSetupWz-02.07.26.exe" \
  --data-dir "$HOME/Library/Application Support/MapleRoyals-PoC" \
  --performance
```

This builds the app. Wine initialization and the Windows game installer run later when the user opens the native app. It does not silently accept installer agreements.

Add `--plan` to validate arguments, hash the installer and print the plan without downloading or writing. `python3 setup.py --check` checks local prerequisites only. `python3 setup.py --plan` offers guided installer selection followed by the same dry run.

`--cache-dir /path/to/cache` reuses archives only after checking their hashes. The builder refuses to overwrite a populated data directory. Omit `--performance` for the original diagnostic profile (MSync off, verbose logging, no explicit CSMT override). `--engine sikarugir10` is a diagnostic alternative that failed character entry in the original investigation; it is not the recommended setup.

The full template is downloaded for its native dependency libraries. Its launcher/Creator are not executed. The downloaded template contains unused renderer components; this is not yet a pruned runtime distribution.

## Validation limits

The actual working game was installed under Sikarugir Wine 10, cloned, and migrated to CX24. Engine, Windows version and desktop activation changes were not isolated as separate causes of the character-entry fix. The direct-CX24 clean installation recipe remains unvalidated through gameplay.

On the test Mac, the user confirmed game entry and movement and compared both resolutions repeatedly. PIC was not prompted. Map changes and two concurrent clients were not independently completed as acceptance checks. The final OpenGL app was user-confirmed playable at 800×600; 1024×768 remained laggy.

## Optional display helper

The 60/120 Hz helper changes macOS display presentation, not the game's internal resolution or frame rate. It is separate from the main launcher, changes the whole built-in display for the session and restores on normal helper exit. Its private API and crash/sleep/multiple-monitor behavior need further validation. See [the helper's source and notes](../display/README.md).
