# IPv4 adapter compatibility component

This project-owned, MIT-licensed DLL replaces only `GetAdaptersInfo` for the 32-bit game. It calls Wine with a correctly sized buffer, keeps adapters with an assigned IPv4 address, and copies their real identities and address lists into the caller's buffer. All other exports forward to the pinned Wine library. It does not change host interfaces, game files, packets, or adapter identities.

The character-loading fault was traced to `MapleRoyals.exe` at `0x005FCE38`, immediately after `GetAdaptersInfo` returned `ERROR_BUFFER_OVERFLOW` (`111`). On the affected M1 Pro, Wine enumerated 25 adapters requiring 16,120 bytes; the game continued reading its unfilled buffer. Filtering left one IPv4 adapter requiring 640 bytes. The user confirmed gameplay with the system-directory workaround on September 22, 2026. That isolated test does not establish clean-install, long-session, or multiclient reliability for the combined launcher.

## Build

Use the official [Zig 0.16.0 archive](https://ziglang.org/download/), extracted with its `lib` directory beside the `zig` executable. Run from the repository root:

```sh
python3 compat/build.py --zig /path/to/zig --output build/adapter-compat
```

This produces the project's `iphlpapi.dll` and a checksum manifest. The portable app builder runs this step automatically; pass `--zig` there, put Zig on `PATH`, or set `ZIG`. Players need none of these tools. `ZIG_LIB_DIR` can identify the `lib` directory for nonstandard layouts. No Wine DLL or game asset is committed or included by this builder.

`iphlpapi.def` lists the names and ordinals from `WS12WineCX24.0.7_5`'s 32-bit library. Updating Wine requires reviewing those exports and rerunning the ABI tests; do not only change the checksum. The compiler checks the 32-bit `IP_ADAPTER_INFO` layout (640 bytes; `Type` offset 416).

## Provisioning and launch

Before Play, `AdapterCompatibility.swift` verifies the bundled shim and this exact downloaded Wine component:

```text
engine/wswine.bundle/lib/wine/i386-windows/iphlpapi.dll
SHA-256 cd5803a41bf6546e9685f2706b1fc8b960fc5cd9a1656037069bc299001cf8b6
```

It creates these files inside the user's Wine prefix:

```text
drive_c/windows/syswow64/iphlpapi.dll                  project shim
drive_c/windows/syswow64/royals_iphlpapi_wine.dll      local Wine copy
mapleroyals-adapter-compat.json                      installed-version receipt
```

The renamed Wine copy clears the first byte of the `Wine builtin DLL` DOS-stub marker at offset `0x40`, allowing Wine to load it under a different name. Every other byte, including executable code, is unchanged. Its SHA-256 is `02514488baf0f567f8cbab371c14162a9633e23bff6ae1c3241fbd47cd8a8bf0`. This file is generated locally from the verified download; Wine's LGPL and source notices still apply. The shared engine remains unchanged.

The game receives:

```text
WINEDLLOVERRIDES=mscoree,mshtml=;iphlpapi=n,b;royals_iphlpapi_wine=n
```

The `b` fallback is necessary for 64-bit Wine services, which still use the stock builtin DLL. Setup retains its original environment. The renderer stays WineD3D/OpenGL, with MSync enabled, ESync disabled, and a separate 1024×768 Wine desktop for each client.

Never put these DLLs in `C:\MapleRoyals`: the client rejected that layout with a garbled Korean error asking to remove a hacking program from the game folder. The [community instructions](https://royals.ms/forum/threads/play-on-mac-apple-silicon-crossover-tutorial-2025.244814/) likewise modify Wine's library location. This implementation is built from the source here, rather than using their externally hosted DLL.

Provisioning writes the dependency before replacing the system DLL and uses atomic file writes. Repeated launches do not rewrite matching files. A recorded older shim can be upgraded only while no clients are tracked; unknown DLLs are preserved with an error. Installer updates copy the system directory into the staged prefix while replacing only the game folder. A subsequent Play verifies the compatibility files again.

## Tests

`python3 tests/run.py` checks provisioning, upgrades, corruption rejection, interrupted installation, concurrent-client guards, and update preservation without executing Windows code.

`tests/AdapterCompatTests.cs` is the Windows ABI test, compiled as x86 using the Wine engine's bundled Mono `mcs.exe`. Run it under the test prefix with `mshtml=;iphlpapi=n,b;royals_iphlpapi_wine=n` as the DLL overrides (leave `mscoree` enabled for Mono). It accepts two Windows paths: the renamed stock library and the shim. Use a disposable prefix, never a live game session.

It tests short/exact buffers, memory canaries, linked-list pointers, retained adapter identities, and a forwarded API. It also requires distinct stock/shim function addresses so a silent Wine fallback cannot produce a false pass. The API test and isolated gameplay test passed before launcher integration. Account credentials, prefixes and diagnostic logs stay outside Git.
