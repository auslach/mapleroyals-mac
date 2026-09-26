#!/usr/bin/env python3
"""Run launcher regression checks without launching Wine or the game."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / 'build'
BUILD.mkdir(exist_ok=True)
common = ['portable/PortableCore.swift', 'portable/AdapterCompatibility.swift', 'portable/GameUpdate.swift']
for name, extra, arguments in [
    ('PortableCoreTests', [], [str(ROOT)]),
    ('GameClientsTests', ['portable/GameClients.swift'], []),
    ('GameUpdateTests', [], [str(ROOT)]),
    ('AdapterCompatibilityTests', [], []),
]:
    executable = BUILD / name
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-O', '-target', 'arm64-apple-macos14.0',
                    '-module-cache-path', str(BUILD / 'module-cache'),
                    *[str(ROOT / source) for source in common + extra + [f'tests/{name}.swift']],
                    '-o', str(executable)], check=True)
    subprocess.run([str(executable), *arguments], check=True)
