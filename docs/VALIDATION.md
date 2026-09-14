# Source export validation

The source folder was assembled and checked on September 14, 2026, on the original M1 Pro Mac. These checks validate the exported build recipe, not a fresh Windows game installation.

Passed:

- Python syntax for every included Python script.
- Guided prerequisite check for Python, Swift compilation and Intel execution.
- Guided `--plan` from a directory outside the repository, using a dummy installer filename containing spaces and an apostrophe. The dummy file was hashed, not executed.
- Literal, quoted and Finder-style escaped installer-path selection.
- A full `prepare.py --performance` native app build using the cached upstream archives after their SHA-256 checks. The generated configuration preserved the selected installer path and enabled MSync, disabled CSMT, and selected quiet logging.
- Strict verification of the generated app's local signature. The test prefix remained empty: no Wine process, game installer or game was launched by this build check.
- Native display-helper builds and signature verification for 60 Hz and 120 Hz, including the copied DeskPad MIT notices.
- Local Markdown links.
- Exclusion of game/runtime binaries, private logs and original username paths from the source folder.
- Git ignore behavior for representative app bundles, runtimes, prefixes, downloads, logs and game assets; intended source/configuration files remain unignored.

All build/ignore fixtures lived in temporary directories and were removed afterward. The user's working game installation was not modified. These checks were completed before the source directory was initialized as a Git repository or published.

Still unvalidated: clean installation through gameplay, a second Mac, PIC interaction, deliberate map-change acceptance checks, simultaneous clients, smooth 1024×768 performance, and production signing/notarization. See [research](RESEARCH.md) for the original gameplay evidence and known failures.
