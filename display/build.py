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
    if a.refresh_hz == 120:
        swift = swift.replace('refreshRate: 60)', 'refreshRate: 120)')
        swift = swift.replace('A temporary 4:3 display can scale the game', 'A temporary 4:3 display at 120 Hz can scale the game')
        swift = swift.replace('Test 1024×768 display', 'Test 1024×768 at 120 Hz')
        swift = swift.replace('MapleRoyals Display Test', 'MapleRoyals 120 Hz Display Test')
        swift = swift.replace('descriptor.name = "MapleRoyals 4:3"', 'descriptor.name = "MapleRoyals 4:3 120 Hz"')
        swift = swift.replace('fullscreen-display.log', 'fullscreen-display-120.log')
    swift_path = temp / 'FullscreenDisplay.swift'
    swift_path.write_text(swift)
    subprocess.run(['xcrun', 'swiftc', '-O', '-module-cache-path', str(temp / 'module-cache'),
        '-import-objc-header', str(source / 'CGVirtualDisplayPrivate.h'),
        str(swift_path), '-o', str(app / 'Contents/MacOS/MapleRoyalsDisplay')], check=True)
    info = dict(CFBundleExecutable='MapleRoyalsDisplay', CFBundleIdentifier='local.mapleroyals.displaytest',
        CFBundleName='MapleRoyals Display Test', CFBundleVersion='0.1', CFBundlePackageType='APPL',
        LSMinimumSystemVersion='14.0', NSHighResolutionCapable=True)
    if a.refresh_hz == 120:
        info.update(CFBundleIdentifier='local.mapleroyals.display120', CFBundleName='MapleRoyals 120 Hz Display Test')
    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
    shutil.copy2(source / 'DeskPad-LICENSE.md', app / 'Contents/Resources/DeskPad-LICENSE.md')
    shutil.copy2(source / 'NOTICE.md', app / 'Contents/Resources/NOTICE.md')
    subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
    subprocess.run(['codesign', '--verify', '--strict', str(app)], check=True)
    app.rename(output)
print(output)
