# AFTERMATH Release Checklist

## Automated gates

- Godot 4.7.1 parses the project without script, resource or import errors.
- Every regression scene exits successfully, including the high-density performance stress scene.
- Peak stress-scene nodes stay below 1,800 and every runtime-budget category remains at or below its hard limit.
- Windows Desktop and Linux release exports complete from clean official export templates.
- Each uploaded executable has a matching SHA-256 checksum.

## Manual candidate checks

- Complete Nightclub → Sandwich Shop → After Hours from a fresh progress file.
- Verify death/retry, early extraction, S–D reports, mission unlocking and best-score preservation.
- Verify mouse/keyboard controls, all weapon types, every enemy archetype, camera alarms and cleanup tools.
- Listen to calm, pursuit, alarm and cleanup mixes on speakers and headphones.
- Check 0% shake, 0% flash, disabled CRT and disabled ambient camera motion.
- Test window focus loss, Alt+F4, Esc navigation and clean relaunch with existing saves.
- Scan packaged files for test saves, `.godot`, source-control metadata and credentials.

## Release record

- Record commit SHA, Godot version, target OS, artifact SHA-256 and test-run URL in the release notes.
- Tag only the reviewed integration commit; the tag triggers `.github/workflows/release-builds.yml`.
- Download and launch both artifacts before publishing the GitHub release.
