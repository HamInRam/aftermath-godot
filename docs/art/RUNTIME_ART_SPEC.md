# AFTERMATH Runtime Pixel Art Specification

The generated master sheet is visual reference only. Runtime art must remain deterministic, sliceable, transparent, nearest-filtered and regression-tested.

## Scale

- Internal tile: 8x8 pixels (equivalent to a 16x16 reference tile at 2x presentation scale).
- Actor animation canvas: 32x32 pixels.
- Actor body core: 16–20 pixels; remaining canvas is reserved for weapons and attacks.
- Door leaf: 16 pixels internal length; corridors: 24–32 pixels internal clear width.
- UI glyph: 8x8 pixels; narrative portrait: 64x64 pixels.

## Palette hierarchy

- Ink `#15121B`, shadow `#2A202D`, paper `#F2E4D7`.
- Player/utility cyan `#52EADB`; enemy magenta `#FF2F82`; interactable amber `#FFD166`.
- Fresh blood `#D20A36`, dark blood `#5D061F`, tissue `#FF657D`, bone `#F1DCC7`.

## Projection and rendering

- Strict 90-degree top-down orthographic silhouettes.
- Integer coordinates, crisp edges, no anti-aliasing, no blur and nearest texture filtering.
- Fixed subtle bottom-right fake shadows; no perspective faces on collision-critical objects.
- Runtime identity colors are authored into sprites and are not created through destructive tinting.

## Readability identities

- Player: pale jacket, cyan identity, dark legs.
- Gunner: magenta/deep red.
- Knife rusher: rust/crimson with visible pale/cyan blade.
- Heavy: wide burgundy-gray armor, amber rank marks.
- Cleanup/interactions: mint/cyan; evidence and valuable interactions: amber.

The source sheet in `docs/art/reference` must never be imported as a runtime atlas until its alpha, cell boundaries, projection and palette are machine-validated.
