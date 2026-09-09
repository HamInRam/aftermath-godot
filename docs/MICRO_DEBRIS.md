# Brass and material fragments

Brass (`ffc800`, `d99a00`) is an explicit exception to the grayscale/crimson
palette. The final fragment shader protects a narrow warm-yellow range; this is
color-key classification, not object-ID masking. Unrelated assets using that
same range would also pass. Casings use four native pixels, sharp metallic
highlights rather than blur/bloom, their existing speed-sensitive landing audio,
wall ray collision and a global 45ms clink throttle. The existing 128-shell
runtime cap remains.

One room-owned MicroDebrisField stores at most 512 cosmetic fragments, replacing
oldest fragments at capacity. Props, doors, glass tiles and solid wall impacts
feed this layer. Wood chips are gray, paper/cloth white with slower initial drag,
concrete chips gray, electronics white sparks and dark cosmetic flecks. Existing
short-lived dust/bursts and up to 48 rigid larger fragments remain. This is not
GPU rigid-body physics, destructible arbitrary wall geometry, or persistent oil.

Held RMB applies the same 224px/90-degree sector and 48px proximity reach to
scrap. Microfragments stop in a 10px foot zone; casings and rigid fragments are
woken and dragged, with wall checks. No scrap produces reserve or damage.
At most 64 microfragment movement rays/frame and 16 existing scraps per 50ms
magnet sweep are processed; overloaded fragments wait, rather than move through
walls. Settled batches stop processing when not magnetized. Releasing RMB stops
attraction, not residual momentum. Room exit discards the batch.

`test_micro_debris` covers capacity, profiles, foot-zone settling, release,
brass and disabled impact damage. Its optional graphics run checks actual
postprocessed gold pixels. This is not a worst-case FPS guarantee or a complete
manual audio/visual acceptance test.
