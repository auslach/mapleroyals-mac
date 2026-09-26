#!/usr/bin/env python3
"""Cross-compile the project's MIT-licensed adapter shim; never bundle Wine DLLs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

SOURCE = Path(__file__).resolve().parent
WINE_SHA256 = 'cd5803a41bf6546e9685f2706b1fc8b960fc5cd9a1656037069bc299001cf8b6'
ZIG_VERSION = '0.16.0'


def build(output, zig=None):
    compiler = zig or os.environ.get('ZIG') or shutil.which('zig')
    if not compiler:
        raise SystemExit('Building requires Zig 0.16.0. See docs/DEVELOPER_GUIDE.md; players do not need Zig.')
    compiler = str(Path(compiler).expanduser().resolve())
    version = subprocess.check_output([compiler, 'version'], text=True).strip()
    if version != ZIG_VERSION:
        raise SystemExit(f'Expected Zig {ZIG_VERSION}, found {version}.')
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    # -nostdlib disables automatic header search as well as the Windows CRT.
    library = Path(os.environ.get('ZIG_LIB_DIR', str(Path(compiler).parent / 'lib')))
    headers = library / 'libc/include/any-windows-any'
    if not (headers / 'windows.h').is_file():
        raise SystemExit('Use the official Zig 0.16.0 archive, or set ZIG_LIB_DIR to its lib directory.')
    environment = os.environ.copy()
    environment['ZIG_GLOBAL_CACHE_DIR'] = str(SOURCE.parent / 'build/zig-global-cache')
    environment['ZIG_LOCAL_CACHE_DIR'] = str(SOURCE.parent / 'build/zig-local-cache')
    subprocess.run([
        compiler, 'cc', '-isystem', str(headers), '-target', 'x86-windows-gnu',
        '-shared', '-O2', '-fno-builtin', '-ffreestanding', '-fno-stack-protector',
        '-nostdlib', '-Wl,--entry,DllMain@12', str(SOURCE / 'adapter_compat.c'),
        str(SOURCE / 'iphlpapi.def'), '-lkernel32', '-o', str(output / 'iphlpapi.dll'),
    ], env=environment, check=True)
    manifest = {
        'schema': 1,
        'sourceWineSHA256': WINE_SHA256,
        'shimSHA256': hashlib.sha256((output / 'iphlpapi.dll').read_bytes()).hexdigest(),
    }
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--zig', help='Path to Zig 0.16.0')
    args = parser.parse_args()
    build(args.output, args.zig)
