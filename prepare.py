#!/usr/bin/env python3
"""Provision a private MapleRoyals proof of concept; never distributes game files."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import urllib.request

HERE = Path(__file__).resolve().parent
ENGINES = {
    "cx24": "WS12WineCX24.0.7_5.tar.xz",
    "sikarugir10": "WS12WineSikarugir10.0_6.tar.xz",
}


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def fetch(asset, cache):
    target = cache / asset["name"]
    expected = asset["digest"].removeprefix("sha256:")
    if target.exists() and digest(target) == expected:
        return target
    if target.exists():
        raise RuntimeError(f"Checksum mismatch in existing cache file: {target}")
    temporary = target.with_suffix(target.suffix + ".partial")
    request = urllib.request.Request(asset["browser_download_url"], headers={"User-Agent": "MapleRoyals-PoC/0.1"})
    print(f"Downloading {asset['name']} ({asset['size']:,} bytes)", flush=True)
    with urllib.request.urlopen(request, timeout=60) as response, temporary.open("wb") as output:
        shutil.copyfileobj(response, output)
    if digest(temporary) != expected:
        raise RuntimeError(f"Downloaded checksum mismatch: {temporary}")
    temporary.replace(target)
    return target


def unpack(archive, destination, expected_member):
    destination.mkdir(parents=True, exist_ok=True)
    if (destination / expected_member).exists():
        raise RuntimeError(f"Refusing to overwrite a runtime: {destination / expected_member}")
    subprocess.run(["/usr/bin/tar", "-xf", str(archive), "-C", str(destination)], check=True)
    if not (destination / expected_member).is_dir():
        raise RuntimeError("Unexpected upstream archive structure")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--installer", required=True, type=Path, help="Current WZ installer downloaded by you from royals.ms/downloads")
    parser.add_argument("--data-dir", required=True, type=Path, help="New permanent directory for runtime, prefix, logs and generated app")
    parser.add_argument("--engine", choices=ENGINES, default="cx24")
    parser.add_argument("--performance", action="store_true", help="Use the locally preferred OpenGL settings: MSync on, CSMT off, quiet logging; 1024x768 lag remains unresolved")
    parser.add_argument("--cache-dir", type=Path, help="Optional directory containing the pinned upstream tar.xz files")
    parser.add_argument("--plan", action="store_true", help="Validate arguments and print the plan without modifying anything")
    args = parser.parse_args()
    installer = args.installer.expanduser().resolve(strict=True)
    root = args.data_dir.expanduser().resolve()
    if installer.suffix.lower() != ".exe" or not installer.is_file():
        parser.error("--installer must be the Windows WZ setup executable")
    assets = {a["name"]: a for a in json.loads((HERE / "assets.json").read_text())}
    selected = [assets[ENGINES[args.engine]], assets["Template-1.0.15.tar.xz"]]
    print(json.dumps({"data_dir": str(root), "app": str(root / "MapleRoyals.app"),
                      "engine": args.engine, "performance": args.performance, "downloads": [a["name"] for a in selected],
                      "installer_sha256": digest(installer), "gameplay_validation": "See docs/RESEARCH.md; clean-machine recipe has not been retested in game."}, indent=2))
    if args.plan:
        return
    if sys.platform != "darwin":
        raise RuntimeError("This recipe requires macOS, Rosetta on Apple Silicon, and Xcode command line tools")
    if root.exists() and any(root.iterdir()):
        raise RuntimeError("Choose an empty data directory. Existing prefixes are never overwritten.")
    subprocess.run(["/usr/bin/xcrun", "--find", "swiftc"], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(["/usr/bin/arch", "-x86_64", "/usr/bin/uname", "-m"], check=True, stdout=subprocess.DEVNULL)
    root.mkdir(parents=True, exist_ok=True)
    cache = args.cache_dir.expanduser().resolve() if args.cache_dir else root / "downloads"
    cache.mkdir(parents=True, exist_ok=True)
    engine_archive, template_archive = [fetch(a, cache) for a in selected]
    unpack(engine_archive, root / "runtime", "wswine.bundle")
    unpack(template_archive, root / "template", "Template-1.0.15.app")
    # The template supplies native libraries only; its launcher/Creator are never executed.
    (root / "prefix").mkdir()
    (root / "logs").mkdir()
    shutil.copyfile(HERE / "settings.reg", root / "settings.reg")
    app = root / "MapleRoyals.app"
    (app / "Contents/MacOS").mkdir(parents=True)
    resources = app / "Contents/Resources"
    resources.mkdir()
    config = {
        "root": str(root), "engine": "runtime/wswine.bundle", "prefix": "prefix",
        "libraries": "template/Template-1.0.15.app/Contents/Frameworks",
        "log": "mapleroyals.log", "debug": "+timestamp,+pid,warn+seh,+loaddll,+msgbox,warn+d3d",
        "overrides": "mscoree,mshtml=",
        "setup": [["wineboot", "-u"], [str(installer), "/DIR=C:\\MapleRoyals", "/NOICONS"],
                  ["reg", "import", "${ROOT}/settings.reg"]],
        "arguments": ["C:\\MapleRoyals\\MapleRoyals.exe"],
    }
    if args.performance:
        config["msync"] = True
        config["debug"] = "-all"
        config["setup"].append(["reg", "add", "HKCU\\Software\\Wine\\Direct3D",
                                "/v", "csmt", "/t", "REG_DWORD", "/d", "0", "/f"])
    (resources / "configuration.json").write_text(json.dumps(config, indent=2))
    info = {"CFBundleExecutable": "MapleRoyals", "CFBundleIdentifier": "local.mapleroyals.launcher",
            "CFBundleName": "MapleRoyals", "CFBundlePackageType": "APPL", "CFBundleVersion": "0.5",
            "LSMinimumSystemVersion": "14.0", "NSHighResolutionCapable": True}
    (app / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
    subprocess.run(["/usr/bin/xcrun", "swiftc", str(HERE / "Launcher.swift"), "-O",
                    "-module-cache-path", str(root / "swift-cache"), "-o", str(app / "Contents/MacOS/MapleRoyals")], check=True)
    subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", str(app)], check=True)
    (root / "provisioned-assets.json").write_text(json.dumps(selected, indent=2))
    print(f"Ready: {app}\nDouble-click it in Finder. Complete the official installer once; the game then starts automatically.\nKeep the data directory in place. This is a private PoC, not a redistributable release.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error))
