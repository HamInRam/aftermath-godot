# Point-blank shotgun burst batching

Each mist emission previously rebuilt and resubmitted every active mist particle.
Nine pellets producing entry and exit sprays therefore repeatedly traversed the
growing room-wide particle array within a single physics tick. Emissions now
queue a coalesced deferred render rebuild; simulation, particle count, palette,
deposits, and collision queries retain their existing behavior.

Ground splats also reuse the result of their wall ray instead of querying it
again when blocked. Saturated pixels with unchanged water, age, and pollution
no longer enqueue an unnecessary texture update. Changed pixels still update
the resource ledger immediately and use the existing upload budget.

## Verification

`test_shotgun_burst_performance` uses seed 5901, eighteen sprays and exactly
1395 particles. Twelve local headless trials on Apple M1 measured emission CPU
median 22,214 us before and 2,708 us after. This excludes the deferred render
rebuild and is **not** a full-frame/GPU FPS benchmark. Across the burst and the
following two process-frame boundaries, observed rebuilds fell from 20 to 3.
The regression checks retained particles, deferred rendering and no-op uploads;
timings are diagnostic rather than hardware-dependent assertions.

Passed: new burst regression, shotgun blood feedback, shotgun combat (including
17px contact), performance hotpaths, siphon sector, blood overload, blood juice,
and performance stress. Real-renderer `render_shotgun_review` passed with impact
and aftermath captures. These checks do not establish zero stutter in every
full-combat workload. Existing intentional critical hit-stop is unchanged.
