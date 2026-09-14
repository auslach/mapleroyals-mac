#!/usr/bin/env python3
"""Guided local build of the experimental MapleRoyals Mac launcher."""
import argparse
import os
from pathlib import Path
import platform
import shlex
import subprocess
import sys

HERE = Path(__file__).resolve().parent
DEFAULT_DATA = Path.home() / "Library/Application Support/MapleRoyals-PoC"


def prerequisites():
    if sys.version_info < (3, 9):
        raise RuntimeError("Install Python 3.9 or newer from https://www.python.org/downloads/macos/")
    if sys.platform != "darwin":
        raise RuntimeError("This setup is for macOS. See README.md for the tested Mac configuration.")
    version = platform.mac_ver()[0]
    if not version or int(version.split('.')[0]) < 14:
        raise RuntimeError("This prototype targets macOS 14 or newer; only the Mac listed in README.md was tested.")
    if platform.machine() not in ("arm64", "x86_64"):
        raise RuntimeError("Unsupported Mac architecture.")
    check = subprocess.run(["/usr/bin/xcrun", "--find", "swiftc"], capture_output=True, text=True)
    if check.returncode:
        raise RuntimeError("Install Apple's Command Line Tools: run xcode-select --install, finish installation, then retry.")
    check = subprocess.run(["/usr/bin/arch", "-x86_64", "/usr/bin/uname", "-m"], capture_output=True, text=True)
    if check.returncode:
        raise RuntimeError("Rosetta is needed on Apple Silicon. Run softwareupdate --install-rosetta and complete its prompts.")
    print("Python, the Swift compiler, and Intel execution are available.")
    print("This checks prerequisites, not game compatibility with this Mac.\n")


def installer_path(raw):
    # Accept a literal path or the quoted/backslash-escaped path Finder inserts
    # when the user drags a file into Terminal. Never evaluate shell input.
    literal = Path(os.path.expandvars(raw.strip())).expanduser()
    if literal.is_file():
        return literal.resolve()
    parts = shlex.split(raw.strip())
    if len(parts) != 1:
        raise ValueError("Choose one installer file.")
    return Path(os.path.expandvars(parts[0])).expanduser().resolve(strict=True)


def choose_installer():
    downloads = Path.home() / "Downloads"
    candidates = sorted(
        (p for p in downloads.iterdir()
         if p.is_file() and p.name.lower().startswith("mapleroyalssetupwz")
         and p.suffix.lower() == ".exe"),
        key=lambda p: p.stat().st_mtime, reverse=True,
    ) if downloads.is_dir() else []
    print("Download the official Windows WZ installer from https://royals.ms/downloads first.")
    print("Leave it as an .exe file; do not try to open or extract it in Finder.")
    print("Only select a file you downloaded from the official MapleRoyals site.")
    for index, path in enumerate(candidates, 1):
        print("  {}. {}".format(index, path.name))
    while True:
        raw = input("\nType its number above, or drag the installer into this window, then press Return: ").strip()
        try:
            if raw.isdigit() and candidates:
                index = int(raw)
                if index < 1 or index > len(candidates):
                    raise ValueError("Choose one of the listed numbers.")
                path = candidates[index - 1]
            else:
                path = installer_path(raw)
            if not path.is_file() or path.suffix.lower() != ".exe":
                raise ValueError("That is not an .exe installer file.")
            print("Selected: {}".format(path.name))
            return path
        except (OSError, ValueError) as error:
            print("Could not use that file: {}".format(error))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check prerequisites only; no downloads or changes")
    parser.add_argument("--plan", action="store_true", help="Choose an installer and preview setup without writing or downloading")
    args = parser.parse_args()
    print("MapleRoyals Mac launcher — experimental source setup\n")
    prerequisites()
    if args.check:
        return
    print("The original M1 Pro installation works at 800x600; a fresh installation still needs gameplay validation.")
    print("Setup builds a Mac launcher. You will complete the game installer when you open that app.\n")
    installer = choose_installer()
    if DEFAULT_DATA.exists() and any(DEFAULT_DATA.iterdir()) and not args.plan:
        print("\nAn installation folder already exists:", DEFAULT_DATA)
        if (DEFAULT_DATA / "MapleRoyals.app/Contents/MacOS/MapleRoyals").is_file():
            print("Open MapleRoyals.app there to finish installation or play; do not run setup again.")
        raise RuntimeError("Nothing was overwritten. See 'Setup stopped halfway' in README.md for recovery.")
    command = [sys.executable, str(HERE / "prepare.py"), "--installer", str(installer),
               "--data-dir", str(DEFAULT_DATA), "--performance"]
    if args.plan:
        command.append("--plan")
    else:
        print("\nFiles will be installed in:", DEFAULT_DATA)
        print("About 260 MB of runtime archives will be downloaded, followed by local compilation.")
        if input("Continue? [y/N]: ").strip().lower() not in ("y", "yes"):
            print("Cancelled. No installation files were created.")
            return
    sys.stdout.flush()
    subprocess.run(command, check=True)
    if args.plan:
        return
    print("\nBuild finished. The Windows game has not been installed by this Terminal command yet.")
    print("In Finder, press Shift-Command-G and paste this folder:")
    print(DEFAULT_DATA)
    print("Open MapleRoyals.app and follow README.md step 5 to complete the game installer.")
    print("Keep this Application Support folder in place. Later launches need no Terminal.")


if __name__ == "__main__":
    try:
        main()
    except (EOFError, KeyboardInterrupt):
        raise SystemExit("\nSetup cancelled.")
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        raise SystemExit("\nSetup stopped: {}".format(error))
