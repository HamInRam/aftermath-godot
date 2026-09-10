# Connected manor map presentation

All venues and the 100 existing encounter formations use the shared world
material generator. This pass changes their art, not room geometry, enemy counts,
weapon balance or floor progression. It references the supplied screenshot's
visual hierarchy rather than reproducing its assets.

- Stone paving now uses staggered 16/20/24-world-pixel slabs instead of large
  32/48/64-pixel fields. One-pixel mortar, slab-specific scars, mineral pits and
  restrained value variation are generated deterministically at level load.
- Carpet has a small woven diamond motif and retains its perimeter borders.
  Timber has grain and fastening details.
- Connected walls retain a dark core, with white coping, a gray bevel and dark
  inner edge. No extra border is drawn between adjacent navigation cells.
- Furniture has material-specific grain, seams or fasteners; counters and
  tabletops carry small readable objects. Plants use radial top-view foliage.
- All new furniture marks use the existing masked pixel painter, so erosion
  removes details along with the object. Walls retain masked destruction and
  local occluder updates. No new per-frame floor generation or physics nodes.

Validation includes grayscale/native-resolution checks, 12 venues and 576 seed
layouts covering all 100 formations, door apertures, breach routing, partial and
complete prop destruction, and the real-renderer shotgun capture. This is not
a claim that each of the 100 rooms has been manually replayed or rebuilt.
