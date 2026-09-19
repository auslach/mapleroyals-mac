#!/usr/bin/env python3
"""Maintainer-only build. Recipients of the ZIP do not need Python or developer tools."""
import argparse
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile

SOURCE = Path(__file__).resolve().parent
REPO = SOURCE.parent


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def bundle(path, executable, identifier, name, **extra):
    (path / 'Contents/MacOS').mkdir(parents=True)
    (path / 'Contents/Resources').mkdir()
    info = dict(CFBundleExecutable=executable, CFBundleIdentifier=identifier,
                CFBundleName=name, CFBundlePackageType='APPL', CFBundleVersion='0.7.2',
                CFBundleShortVersionString='0.7.2', LSMinimumSystemVersion='14.0',
                NSHighResolutionCapable=True, **extra)
    (path / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=REPO / 'dist/MapleRoyals-preview')
    parser.add_argument('--identity', help='Exact Developer ID Application identity; omit for local ad-hoc preview')
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    archive = output.with_suffix('.zip')
    if output.exists() or archive.exists():
        parser.error('Output or ZIP already exists. Choose a new path; existing builds are not overwritten.')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='mapleroyals-portable-build-', dir=output.parent) as temporary:
        temporary = Path(temporary)
        stage = temporary / output.name
        stage.mkdir()
        app = stage / 'MapleRoyals.app'
        bundle(app, 'MapleRoyals', 'local.mapleroyals.portable', 'MapleRoyals')
        cache = temporary / 'module-cache'
        run('xcrun', 'swiftc', '-swift-version', '5', '-O', '-target', 'arm64-apple-macos14.0',
            '-module-cache-path', cache, '-import-objc-header', REPO / 'display/CGVirtualDisplayPrivate.h',
            SOURCE / 'PortableCore.swift', SOURCE / 'GameDisplay.swift', SOURCE / 'PortableLauncher.swift',
            '-o', app / 'Contents/MacOS/MapleRoyals')
        helper = app / 'Contents/Helpers/Intel Compatibility.app'
        bundle(helper, 'IntelCompatibility', 'local.mapleroyals.intel-compatibility', 'Intel Compatibility', LSUIElement=True)
        run('xcrun', 'swiftc', '-O', '-target', 'x86_64-apple-macos14.0', '-module-cache-path', cache,
            SOURCE / 'RosettaCheck.swift', '-o', helper / 'Contents/MacOS/IntelCompatibility')
        for filename in ['assets.json', 'settings.reg', 'THIRD_PARTY_NOTICES.md']:
            shutil.copy2(REPO / filename, app / 'Contents/Resources' / filename)
        for filename in ['DeskPad-LICENSE.md', 'NOTICE.md']:
            shutil.copy2(REPO / 'display' / filename, app / 'Contents/Resources' / filename)
        shutil.copy2(SOURCE / 'START-HERE.txt', stage / 'START-HERE.txt')
        signing = ['--force', '--sign', args.identity or '-']
        if args.identity:
            signing += ['--options', 'runtime', '--timestamp']
        for target in [helper, app]:
            run('codesign', *signing, target)
            run('codesign', '--verify', '--strict', target)
        (stage / 'BUILD-INFO.json').write_text(json.dumps({
            'version': '0.7.2', 'integrated_fullscreen': True, 'architecture': 'arm64', 'minimum_macos': '14.0',
            'signature': 'Developer ID' if args.identity else 'ad-hoc',
            'notarized': False, 'contains_game_or_wine_binaries': False,
            'recipient_needs_python_or_command_line_tools': False,
        }, indent=2) + '\n')
        stage.rename(output)
    run('/usr/bin/ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', output, archive)
    print('App folder:', output)
    print('ZIP:', archive)
    print('Private hobby preview: no Apple account used by the default build. First-open approval may be needed.')
    print('A clean-Mac gameplay check remains unvalidated.')


if __name__ == '__main__':
    main()
