# September performance pass

- Critical hit-stop: head 20ms, kill 25ms, head kill 45ms. All hit-stop requests share a rolling 100ms/second budget. Critical requests have a 220ms refractory interval. Reset/exit restores time normally.
- Siphon: maximum two 40ms slices per update; excessive accumulated stall time is discarded. Failed pressure checks above core capacity retry after 120ms. Successful pressure previews carry a pixel extraction plan, committed without scanning the sector twice.
- Occlusion rays: identical-origin/radius requests reuse the same render-frame result only; moving the source or entering a new frame invalidates the cache. No multi-frame geometry cache is used.
- World destruction: replace only the damaged static light rectangle with its remaining pieces, reusing its node. Eroded-cell light shapes reuse nodes instead of allocating/freeing every impact. Static navigation remains immediate. Partial wall chips do not refresh sound sectors. Real openings coalesce acoustic flood-fill requests over 100ms; the sound topology itself is still a full rebuild, not an incremental union system.
- Original native pixels, blood amounts, particle limits and collision erosion resolution remain unchanged. World wall-texture uploads are still full-image updates; further chunking requires separate measurement and implementation.

Validation: critical-hit-stop, siphon-sector, overload, blood-juice, settings, breach-route, floor-flow and stress regressions; new `test_performance_hotpaths` checks bounded catch-up, ray reuse, local occluder identity and acoustic request coalescing.

One local headless hotpath run: 40 pressure siphon samples, median 410us, P95 511us, max 569us. These are isolated CPU timings, not GPU frame times or a before/after FPS claim. The new test initially selected a non-nightclub map without static light occluders; its fixture was corrected to nightclub and passed.
