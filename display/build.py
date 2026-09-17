#!/usr/bin/env python3
"""Build the experimental native 4:3 display helper; does not launch it."""
from pathlib import Path
import argparse, plistlib, shutil, subprocess, tempfile
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--output', type=Path, default=Path.cwd() / 'MapleRoyals Display Test.app')
p.add_argument('--refresh-hz', type=int, choices=[60, 120], default=60)
a = p.parse_args()
output = a.output.expanduser().resolve()
if output.exists():
    p.error('Output already exists; choose a new path.')
source = Path(__file__).resolve().parent
output.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='mapleroyals-display-build-', dir=output.parent) as temp:
    temp = Path(temp)
    app = temp / output.name
    (app / 'Contents/MacOS').mkdir(parents=True)
    (app / 'Contents/Resources').mkdir()
    swift = (source / 'FullscreenDisplay.swift').read_text()
    swift_path = temp / 'FullscreenDisplay.swift'
    swift_path.write_text(swift)
    subprocess.run(['xcrun', 'swiftc', '-O', '-target', 'arm64-apple-macos14.0', '-module-cache-path', str(temp / 'module-cache'),
        '-import-objc-header', str(source / 'CGVirtualDisplayPrivate.h'),
        str(swift_path), '-o', str(app / 'Contents/MacOS/MapleRoyalsDisplay')], check=True)
    info = dict(CFBundleExecutable='MapleRoyalsDisplay', CFBundleIdentifier='local.mapleroyals.displaytest',
        CFBundleName='MapleRoyals Display Test', CFBundleVersion='0.2', CFBundleShortVersionString='0.2', CFBundlePackageType='APPL',
        LSMinimumSystemVersion='14.0', NSHighResolutionCapable=True, MapleRoyalsRefreshRate=a.refresh_hz)
    if a.refresh_hz == 120:
        info.update(CFBundleIdentifier='local.mapleroyals.display120', CFBundleName='MapleRoyals 120 Hz Display Test')
    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
    shutil.copy2(source / 'DeskPad-LICENSE.md', app / 'Contents/Resources/DeskPad-LICENSE.md')
    shutil.copy2(source / 'NOTICE.md', app / 'Contents/Resources/NOTICE.md')
    subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
    subprocess.run(['codesign', '--verify', '--strict', str(app)], check=True)
    app.rename(output)
print(output)
